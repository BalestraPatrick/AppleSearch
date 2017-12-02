import Vapor

final class Routes: RouteCollection {

    let searchController: SearchController

    init(droplet: Droplet, view: ViewRenderer) {
        self.searchController = SearchController(droplet: droplet, view: view)
    }

    func build(_ builder: RouteBuilder) throws {
        // GET /
        builder.get { try self.searchController.index($0) }

        // GET /search
        builder.get("search") { try self.searchController.search($0) }
    }
}
