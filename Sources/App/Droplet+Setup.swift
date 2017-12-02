@_exported import Vapor

extension Droplet {
    public func setup() throws {
        let routes = Routes(droplet: self, view: view)
        try collection(routes)
    }
}
