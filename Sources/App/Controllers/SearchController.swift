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
        return try view.make("home", for: req)
    }

    /// GET /search
    func search(_ req: Request) throws -> ResponseRepresentable {
        guard let query = req.query else { throw Abort(.badRequest, reason: "Missing query parameter") }
        guard let queryText = query["query"]?.string else { throw Abort(.badRequest, reason: "`query` parameter is in the wrong format or absent") }
        guard let language = query["lang"]?.string else { throw Abort(.badRequest, reason: "`lang` parameter is in the wrong format or absent") }
        let start = query["start"]?.int ?? 0

        // Load results.
        let results = try loadResults(term: queryText, language: language, start: start)

        // Load disambiguations.
        let disambiguations = try loadDisambiguations(term: queryText)

        // Load pages number.
        let pages = try loadPages(term: queryText, language: language, count: results.count)

        return try view.make("search", [
            "query": queryText,
            "language": language,
            "disambiguation": (disambiguations.array?.count ?? 0) != 0,
            "disambiguations": disambiguations,
            "resultsCount": results.count,
            "resultsPage": start + 1,
            "results": results.items,
            "pages": pages,
        ] as [String: NodeRepresentable], for: req)
    }
}

extension SearchController {

    private func loadResults(term: String, language: String, start: Int = 0) throws -> SearchResults {
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
                "urlEncoded": url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!,
                "lang": lang
            ]
        }

        let printableResults = try formattedResults.makeNode(in: nil)
        return SearchResults(count: totalCount, items: printableResults)
    }

    private func loadDisambiguations(term: String) throws -> Node {
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
            let disambiguation = DisambiguationResult(title: String(resultTitle), description: String(resultDescription))
            disambiguations.append(try! disambiguation.makeNode(in: nil))
        }
        return try disambiguations.makeNode(in: nil)
    }

    private func loadPages(term: String, language: String, count: Int) throws -> Node {
        var nodes = [Node]()
        for i in stride(from: 0, to: count, by: 10) {
            let pageUrl = "http://0.0.0.0:8080/search?query=\(term.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)&lang=\(language.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)&start=\(i / 10)"
            nodes.append(["link": pageUrl.makeNode(in: nil), "number": String(describing: (i / 10) + 1).makeNode(in: nil)])
        }
        return try nodes.makeNode(in: nil)
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
