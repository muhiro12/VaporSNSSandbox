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

    /// Load `Resources/seed.json` into `db.json`.
    private func seed(req: Request) throws -> EventLoopFuture<Response> {
        do {
            try FileDB.shared.seed(fromSeedPath: "Resources/seed.json")
            req.logger.info("[Admin] Seed applied")
            return req.eventLoop.makeSucceededFuture(Response(status: .ok))
        } catch {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .internalServerError, code: "SERVER_ERROR", message: "seed failed"))
        }
    }

    /// Reset database state (keeps the default "me" user).
    private func reset(req: Request) throws -> EventLoopFuture<Response> {
        FileDB.shared.reset()
        req.logger.info("[Admin] DB reset")
        return req.eventLoop.makeSucceededFuture(Response(status: .ok))
    }

    struct FaultsReq: Content { let latencyMs: Int; let rateLimit: Bool; let errorRate: Int }
    /// Update fault injection configuration.
    private func faults(req: Request) throws -> EventLoopFuture<Response> {
        guard let b = try? req.content.decode(FaultsReq.self) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "Invalid JSON"))
        }
        guard b.latencyMs >= 0 && b.latencyMs <= 2_000 && b.errorRate >= 0 && b.errorRate <= 100 else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "invalid fault values"))
        }
        let state = FaultState(latencyMs: b.latencyMs, rateLimit: b.rateLimit, errorRate: b.errorRate)
        FaultInjectionMiddleware.shared.update(state, logger: req.logger)
        return req.eventLoop.makeSucceededFuture(Response(status: .ok))
    }

    struct SpawnReq: Content { let authorId: String; let text: String; let imageUrl: String? }
    /// Create a post on behalf of another existing user.
    private func spawn(req: Request) throws -> EventLoopFuture<Response> {
        guard let b = try? req.content.decode(SpawnReq.self) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "Invalid JSON"))
        }
        guard (1...140).contains(b.text.trimmingCharacters(in: .whitespacesAndNewlines).count) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "text must be 1..140 chars"))
        }
        guard let author = FileDB.shared.findUser(id: b.authorId) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "author not found"))
        }
        let post = FileDB.shared.addPost(author: author, text: b.text, imageUrl: b.imageUrl)
        req.logger.info("[Admin] Spawn post id=\(post.id) by \(author.id)")
        return req.eventLoop.makeSucceededFuture(Response(status: .created))
    }
}
