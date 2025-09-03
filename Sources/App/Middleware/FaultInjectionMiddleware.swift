import NIO
import Vapor

/// Mutable fault injection state.
struct FaultState: Content {
    var latencyMs: Int
    var rateLimit: Bool
    var errorRate: Int // 0..100 percent
}

/// Middleware that injects latency, 429, and 500 for `/api/*` routes.
final class FaultInjectionMiddleware: Middleware {
    static let shared = FaultInjectionMiddleware()

    private let lock = NIOLock()
    private var state = FaultState(latencyMs: 0, rateLimit: false, errorRate: 0)

    /// Replace the current fault state.
    func update(_ new: FaultState, logger: Logger?) {
        lock.withLockVoid {
            state = new
        }
        logger?.info("[Faults] latency=\(new.latencyMs)ms rateLimit=\(new.rateLimit) errorRate=\(new.errorRate)%")
    }

    func current() -> FaultState { lock.withLock { state } }

    /// Apply faults for `/api/*`; otherwise pass through.
    func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        let path = req.url.path
        let start = Date()

        if path.hasPrefix("/api/") {
            let s = current()

            // Rate limit: reject immediately
            if s.rateLimit {
                let res = Self.errorResponse(req: req, status: .tooManyRequests, code: "RATE_LIMIT", message: "Too many requests")
                log(req: req, status: res.status, start: start)
                return req.eventLoop.makeSucceededFuture(res)
            }

            // Error rate: random fail
            if s.errorRate > 0 {
                let r = Int.random(in: 0..<100)
                if r < s.errorRate {
                    let res = Self.errorResponse(req: req, status: .internalServerError, code: "SERVER_ERROR", message: "Injected server error")
                    log(req: req, status: res.status, start: start)
                    return req.eventLoop.makeSucceededFuture(res)
                }
            }

            // Latency: schedule delay if needed
            if s.latencyMs > 0 {
                return req.eventLoop.scheduleTask(in: .milliseconds(Int64(s.latencyMs))) {}
                    .futureResult.flatMap { next.respond(to: req) }
                    .map { res in
                        self.log(req: req, status: res.status, start: start)
                        return res
                    }
            }
        }

        return next.respond(to: req).map { res in
            if path.hasPrefix("/api/") {
                self.log(req: req, status: res.status, start: start)
            }
            return res
        }
    }

    private func log(req: Request, status: HTTPResponseStatus, start: Date) {
        let ms = Int(Date().timeIntervalSince(start) * 1_000)
        req.logger.info("[API] \(req.method.string) \(req.url.path) -> \(status.code) (\(ms)ms)")
    }

    /// Build a uniform API error JSON response.
    static func errorResponse(req _: Request, status: HTTPResponseStatus, code: String, message: String) -> Response {
        struct APIError: Content { let code: String; let message: String }
        let payload = APIError(code: code, message: message)
        let res = Response(status: status)
        do {
            res.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
            let data = try JSONEncoder().encode(payload)
            res.body = .init(data: data)
        } catch {
            res.body = .init(string: "{\"code\":\"SERVER_ERROR\",\"message\":\"encoding failed\"}")
        }
        return res
    }
}
