import Vapor
import HTTP

final class SearchController {

    let view: ViewRenderer
    init(_ view: ViewRenderer) {
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
        return try view.make("search", [
            "name": "World"
        ], for: req)
    }
}

