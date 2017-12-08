import Foundation

struct DisambiguationResult: NodeRepresentable {

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
            "link": "http://0.0.0.0:8080/search?query=\(title)&lang=🌍+All"
        ])

        if let image = imageLink {
            node["imageLink"] = image.makeNode(in: nil)
        }
        return node
    }
}
