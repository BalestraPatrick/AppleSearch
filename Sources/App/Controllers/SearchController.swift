import Vapor
import HTTP

final class SearchController {

    let droplet: Droplet
    let view: ViewRenderer

    init(droplet: Droplet, view: ViewRenderer) {
        self.droplet = droplet
        self.view = view
    }

    /// GET /
    func index(_ req: Request) throws -> ResponseRepresentable {
        return try view.make("home", [
            "name": "World"
        ], for: req)
    }

    /// GET /search
    func search(_ req: Request) throws -> ResponseRepresentable {
        guard let query = req.query else { throw Abort(.badRequest, reason: "Missing query parameter") }
        guard let queryText = query["query"]?.string else { throw Abort(.badRequest, reason: "`query` parameter is in the wrong format or absent") }
        guard let language = query["lang"]?.string else { throw Abort(.badRequest, reason: "`lang` parameter is in the wrong format or absent") }

        print(language)
        // Load results.
        let results = try loadResults(term: queryText, language: language)

        // Load disambiguations.
        let disambiguations = try loadDisambiguations(term: queryText)

        return try view.make("search", [
            "disambiguation": disambiguations != nil,
            "disambiguations": disambiguations,
            "resultsCount": results.count,
            "results": results.items
        ], for: req)
    }

    private func loadResults(term: String, language: String, start: Int = 0) throws -> SearchResults {
        // TODO: migrate to URLComponents
        let url = buildQuery(term: term, start: start, language: language)
        let response = try droplet.client.get(url)
        guard let json = try? JSON(bytes: response.body.bytes!) else { throw Abort(.internalServerError, reason: "Could not convert response from Solr to JSON") }
        guard let totalCount = json["response"]?["numFound"]?.int else { throw Abort(.internalServerError, reason: "Could not find `numFound` int in JSON response")}
        guard let results = json["response"]?["docs"]?.array else { throw Abort(.internalServerError, reason: "Could not find `docs` array in JSON response") }

        let formattedResults = results.flatMap { result -> [String: String]? in
            guard let title = result["title"]?.string else { return nil }
            guard let url = result["url"]?.string else { return nil }
            let lang = self.language(for: url).string
            guard language == "🌍 All" || lang == language else { return nil }
            return [
                "title": title,
                "url": url,
                "lang": lang
            ]
        }

        let printableResults = try formattedResults.makeNode(in: nil)
        return SearchResults(count: totalCount, items: printableResults)
    }

    private func loadDisambiguations(term: String) throws -> Node? {
        // TODO: migrate to URLComponents
        let response = try droplet.client.get("https://api.duckduckgo.com/?q=\(term)&format=json&pretty=1")
        guard let json = try? JSON(bytes: response.body.bytes!) else { return nil }
        guard let relatedTopics = json["RelatedTopics"]?.array else { return nil }
        let topics = Array(relatedTopics.prefix(4))
        var disambiguations = [Node]()
        for topic in topics {
            guard let result = topic["Result"]?.string, let startTitle = result.index(of: ">"), let endTitle = result[startTitle...].index(of: "<") else { continue }
            guard let startDescription = result[endTitle...].index(of: ">") else { continue }
            let resultTitle = result[result.index(after: startTitle)..<endTitle]
            let resultDescription = result[result.index(after: startDescription)...]
            let disambiguation = Disambiguation(title: String(resultTitle), description: String(resultDescription))
            disambiguations.append(try! disambiguation.makeNode(in: nil))
        }
        return try disambiguations.makeNode(in: nil)
    }

    private func language(for url: String) -> String {
        let lang = String(url[url.index(url.startIndex, offsetBy: 8)..<url.index(url.startIndex, offsetBy: 10)])
        return Language(id: lang).name
    }

    private func buildQuery(term: String, start: Int, language: String) -> String {
        let encodedQuery = term.replacingOccurrences(of: " ", with: "+")
        let language = Language(name: language)
        let url: String
        if case .all = language {
            url = "http://localhost:8983/solr/nutch/select?q=\(encodedQuery)&start=\(start)&wt=json&indent=true"
        } else {
            url = "http://localhost:8983/solr/nutch/select?q=\(encodedQuery)&fq=fq%3D(url%3A%22%5Ehttps%3A%2F%2F\(language.id)%22)&start=\(start)&wt=json&indent=true"
        }
        return url
    }
}

enum Language {
    case english
    case italian
    case german
    case french
    case all

    init(id: String) {
        switch id {
        case "en": self = .english
        case "it": self = .italian
        case "de": self = .german
        case "fr": self = .french
        case "all": self = .all
        default: fatalError()
        }
    }

    init(name: String) {
        switch name {
        case "🇺🇸 English": self = .english
        case "🇮🇹 Italian": self = .italian
        case "🇩🇪 German": self = .german
        case "🇫🇷 French": self = .french
        case "🌍 All": self = .all
        default: fatalError()
        }
    }

    var id: String {
        switch self {
        case .english: return "en"
        case .italian: return "it"
        case .german: return "de"
        case .french: return "fr"
        case .all: return "all"
        }
    }

    var name: String {
        switch self {
        case .english: return "🇺🇸 English"
        case .italian: return "🇮🇹 Italian"
        case .german: return "🇩🇪 German"
        case .french: return "🇫🇷 French"
        case .all: return "🌍 All"
        }
    }
}

struct SearchResults {
    let count: Int
    let items: Node
}

struct Disambiguation: NodeRepresentable {

    let title: String
    let description: String
    let imageLink: String?

    init(title: String, description: String, imageLink: String? = nil) {
        self.title = title
        self.description = description
        self.imageLink = imageLink
    }

    func makeNode(in context: Context?) throws -> Node {
        var node = try Node(node: [
            "title": title,
            "description": description,
        ])

        if let image = imageLink {
            node["imageLink"] = image.makeNode(in: nil)
        }
        return node
    }
}
