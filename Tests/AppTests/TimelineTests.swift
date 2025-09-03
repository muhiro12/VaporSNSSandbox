import XCTVapor
@testable import App

/// Basic tests for timeline paging and fault injection behavior.
final class TimelineTests: XCTestCase {
    func makeAppWithDB(posts: Int = 35) throws -> Application {
        // Use in-memory DB to avoid filesystem writes
        FileDB.shared = FileDB(inMemory: true)
        // Seed minimal users
        let users = (1...3).map { i in User(id: "u_\(i)", displayName: "U\(i)", avatarUrl: nil) }
        users.forEach { FileDB.shared.upsertUser($0) }
        // Add posts (author cycling)
        for i in 0..<posts {
            let author = users[i % users.count]
            _ = FileDB.shared.addPost(author: author, text: "T\(i)", imageUrl: nil)
        }

        let app = Application(.testing)
        try configure(app)
        return app
    }

    /// Ensures the first page returns 20 items and a next page; last page has no next.
    func testGetPostsPaging() throws {
        let app = try makeAppWithDB(posts: 35)
        defer { app.shutdown() }

        try app.test(.GET, "/api/posts?page=1") { res in
            XCTAssertEqual(res.status, .ok)
            let page = try res.content.decode(PostsPage.self)
            XCTAssertEqual(page.items.count, 20)
            XCTAssertEqual(page.nextPage, 2)
        }
        try app.test(.GET, "/api/posts?page=2") { res in
            XCTAssertEqual(res.status, .ok)
            let page = try res.content.decode(PostsPage.self)
            XCTAssertEqual(page.items.count, 15)
            XCTAssertNil(page.nextPage)
        }
    }

    /// When rate limiting is enabled, `/api/posts` responds with 429 and error JSON.
    func testRateLimit429() throws {
        let app = try makeAppWithDB()
        defer { app.shutdown() }
        FaultInjectionMiddleware.shared.update(.init(latencyMs: 0, rateLimit: true, errorRate: 0), logger: app.logger)

        try app.test(.GET, "/api/posts?page=1") { res in
            XCTAssertEqual(res.status, .tooManyRequests)
            struct Err: Content { let code: String; let message: String }
            let err = try res.content.decode(Err.self)
            XCTAssertEqual(err.code, "RATE_LIMIT")
        }
    }

    /// With 100% error rate, `/api/posts` responds with 500 and error JSON.
    func testInjected500() throws {
        let app = try makeAppWithDB()
        defer { app.shutdown() }
        FaultInjectionMiddleware.shared.update(.init(latencyMs: 0, rateLimit: false, errorRate: 100), logger: app.logger)

        try app.test(.GET, "/api/posts?page=1") { res in
            XCTAssertEqual(res.status, .internalServerError)
            struct Err: Content { let code: String; let message: String }
            let err = try res.content.decode(Err.self)
            XCTAssertEqual(err.code, "SERVER_ERROR")
        }
    }
}
