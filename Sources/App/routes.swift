import Vapor

/// Register all application routes.
func routes(_ app: Application) throws {
    app.get("health") { req -> [String: Bool] in ["ok": true] }

    try app.register(collection: PostsController())
    try app.register(collection: UsersController())
    try app.register(collection: AdminController())

    // Redirect /admin -> /admin/index.html for convenience
    app.get("admin") { req -> Response in
        let res = Response(status: .seeOther)
        res.headers.replaceOrAdd(name: .location, value: "/admin/index.html")
        return res
    }
}
