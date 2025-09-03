@testable import App
import XCTVapor

final class UsersControllerTests: XCTestCase {
    private func makeApp() throws -> Application {
        FileDB.shared = FileDB(inMemory: true)
        let app = Application(.testing)
        try configure(app)
        return app
    }

    func testGetMeReturnsUser() throws {
        let app = try makeApp()
        defer { app.shutdown() }

        try app.test(.GET, "/api/users/me") { response in
            XCTAssertEqual(response.status, .ok)
            let user = try response.content.decode(User.self)
            XCTAssertEqual(user.id, "me")
            XCTAssertEqual(user.displayName, "Trainee")
        }
    }

    func testPatchMeUpdatesFields() throws {
        let app = try makeApp()
        defer { app.shutdown() }

        struct Body: Content { let displayName: String; let avatarUrl: String? }
        try app.test(.PATCH, "/api/users/me", beforeRequest: { req in
            try req.content.encode(Body(displayName: "New Name", avatarUrl: "https://example.com/a.png"))
        }) { response in
            XCTAssertEqual(response.status, .ok)
            let user = try response.content.decode(User.self)
            XCTAssertEqual(user.displayName, "New Name")
            XCTAssertEqual(user.avatarUrl, "https://example.com/a.png")
        }
    }
}

