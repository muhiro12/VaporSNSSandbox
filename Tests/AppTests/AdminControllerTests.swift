@testable import App
import XCTVapor

final class AdminControllerTests: XCTestCase {
    private func makeApp() throws -> Application {
        FileDB.shared = FileDB(inMemory: true)
        let app = Application(.testing)
        try configure(app)
        return app
    }

    func testFaultsEndpointUpdatesStateAndReturnsOk() throws {
        let app = try makeApp()
        defer { app.shutdown() }

        struct Body: Content { let latencyMs: Int; let rateLimit: Bool; let errorRate: Int }
        try app.test(.POST, "/admin/faults", beforeRequest: { req in
            try req.content.encode(Body(latencyMs: 100, rateLimit: true, errorRate: 25))
        }) { response in
            XCTAssertEqual(response.status, .ok)
            struct Ok: Content { let ok: Bool }
            let ok = try response.content.decode(Ok.self)
            XCTAssertTrue(ok.ok)
        }
    }

    func testSpawnCreatesPostAndReturnsJSON() throws {
        let app = try makeApp()
        defer { app.shutdown() }
        // Prepare author
        FileDB.shared.upsertUser(.init(id: "u_1", displayName: "Alice", avatarUrl: nil))

        struct Body: Content { let authorId: String; let text: String; let imageUrl: String? }
        try app.test(.POST, "/admin/spawn", beforeRequest: { req in
            try req.content.encode(Body(authorId: "u_1", text: "Hello", imageUrl: nil))
        }) { response in
            XCTAssertEqual(response.status, .created)
            let post = try response.content.decode(Post.self)
            XCTAssertEqual(post.author.id, "u_1")
            XCTAssertEqual(post.text, "Hello")
        }
    }
}

