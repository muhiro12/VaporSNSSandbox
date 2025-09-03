import Vapor

/// `/api/users` endpoints for the fixed local user "me".
final class UsersController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api", "users")
        api.get("me", use: getMe)
        api.patch("me", use: patchMe)
    }

    /// Returns the current user (creates default if missing).
    private func getMe(req: Request) throws -> EventLoopFuture<User> {
        let me = FileDB.shared.findUser(id: "me") ?? User(id: "me", displayName: "Trainee", avatarUrl: nil)
        FileDB.shared.upsertUser(me)
        return req.eventLoop.makeSucceededFuture(me)
    }

    struct PatchMeRequest: Content {
        var displayName: String
        var avatarUrl: String?
    }

    /// Updates displayName (1..40) and optional avatarUrl.
    private func patchMe(req: Request) throws -> EventLoopFuture<Response> {
        guard let body = try? req.content.decode(PatchMeRequest.self) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "Invalid JSON"))
        }
        guard (1...40).contains(body.displayName.count) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "displayName must be 1..40 chars"))
        }
        var me = FileDB.shared.findUser(id: "me") ?? User(id: "me", displayName: "Trainee", avatarUrl: nil)
        me.displayName = body.displayName
        me.avatarUrl = body.avatarUrl
        FileDB.shared.upsertUser(me)
        let res = Response(status: .ok)
        do {
            res.headers.contentType = .json
            let data = try JSONEncoder().encode(me)
            res.body = .init(data: data)
        } catch {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .internalServerError, code: "SERVER_ERROR", message: "encoding failed"))
        }
        return req.eventLoop.makeSucceededFuture(res)
    }
}
