import Vapor

/// `/admin` endpoints used by the static admin UI.
final class AdminController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let admin = routes.grouped("admin")
        admin.post("seed", use: seed)
        admin.post("reset", use: reset)
        admin.post("faults", use: faults)
        admin.post("spawn", use: spawn)
    }

    /// Load seed into the database and respond with JSON.
    private func seed(req: Request) throws -> EventLoopFuture<Response> {
        do {
            try FileDB.shared.seed(fromSeedPath: AppConfig.seedRelativePath)
            req.logger.info("[Admin] Seed applied")
            struct Ok: Content { let ok: Bool }
            let response = Response(status: .ok)
            try response.content.encode(Ok(ok: true))
            return req.eventLoop.makeSucceededFuture(response)
        } catch {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .internalServerError, code: "SERVER_ERROR", message: "seed failed"))
        }
    }

    /// Reset database state (keeps the default "me" user).
    private func reset(req: Request) throws -> EventLoopFuture<Response> {
        FileDB.shared.reset()
        req.logger.info("[Admin] DB reset")
        struct Ok: Content { let ok: Bool }
        let response = Response(status: .ok)
        try response.content.encode(Ok(ok: true))
        return req.eventLoop.makeSucceededFuture(response)
    }

    struct FaultsReq: Content {
        let latencyMs: Int
        let rateLimit: Bool
        let errorRate: Int
    }
    /// Update fault injection configuration.
    private func faults(req: Request) throws -> EventLoopFuture<Response> {
        guard let body = try? req.content.decode(FaultsReq.self) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "Invalid JSON"))
        }
        guard body.latencyMs >= 0 && body.latencyMs <= 2_000 && body.errorRate >= 0 && body.errorRate <= 100 else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "invalid fault values"))
        }
        let state = FaultState(latencyMs: body.latencyMs, rateLimit: body.rateLimit, errorRate: body.errorRate)
        FaultInjectionMiddleware.shared.update(state, logger: req.logger)
        struct Ok: Content { let ok: Bool }
        let response = Response(status: .ok)
        try response.content.encode(Ok(ok: true))
        return req.eventLoop.makeSucceededFuture(response)
    }

    struct SpawnReq: Content {
        let authorId: String
        let text: String
        let imageUrl: String?
    }
    /// Create a post on behalf of another existing user.
    private func spawn(req: Request) throws -> EventLoopFuture<Response> {
        guard let body = try? req.content.decode(SpawnReq.self) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "Invalid JSON"))
        }
        guard (1...140).contains(body.text.trimmingCharacters(in: .whitespacesAndNewlines).count) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "text must be 1..140 chars"))
        }
        guard let author = FileDB.shared.findUser(id: body.authorId) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "author not found"))
        }
        let post = FileDB.shared.addPost(author: author, text: body.text, imageUrl: body.imageUrl)
        req.logger.info("[Admin] Spawn post id=\(post.id) by \(author.id)")
        let response = Response(status: .created)
        try response.content.encode(post)
        return req.eventLoop.makeSucceededFuture(response)
    }
}
