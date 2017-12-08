import XCTest
import Foundation
import Testing
import HTTP
@testable import Vapor
@testable import App

class RouteTests: TestCase {

    let drop = try! Droplet.testable()

    func testIndexOk() throws {
        try drop
            .testResponse(to: .get, at: "/")
            .assertStatus(is: .ok)
            .assertBody(contains: "Tech Search")
    }

    func testSearchBadRequestWhenMissingQuery() throws {
        try drop
            .testResponse(to: .get, at: "/search")
            .assertStatus(is: .badRequest)
    }

    func testSearchBadRequestWhenMissingLanguage() throws {
        try drop
            .testResponse(to: Request.makeTest(method: .get, path: "/search", query: "query=iPad"))
            .assertStatus(is: .badRequest)
    }

    func testSearchOk() throws {
        try drop
            .testResponse(to: Request.makeTest(method: .get, path: "/search", query: "query=ipad&lang=🌍+All"))
            .assertStatus(is: .ok)
            .assertBody(contains: "ipad")
    }
}

// MARK: Manifest

extension RouteTests {
    /// This is a requirement for XCTest on Linux
    /// to function properly.
    /// See ./Tests/LinuxMain.swift for examples
    static let allTests = [
        ("testIndexOk", testIndexOk),
        ("testSearchBadRequestWhenMissingQuery", testSearchBadRequestWhenMissingQuery),
        ("testSearchBadRequestWhenMissingLanguage", testSearchBadRequestWhenMissingLanguage),
        ("testSearchOk", testSearchOk),
    ]
}
