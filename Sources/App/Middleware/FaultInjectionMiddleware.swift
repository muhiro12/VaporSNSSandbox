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
    func update(_ newState: FaultState, logger: Logger?) {
        lock.withLockVoid {
            state = newState
        }
        logger?.info("[Faults] latency=\(newState.latencyMs)ms rateLimit=\(newState.rateLimit) errorRate=\(newState.errorRate)%")
    }

    func current() -> FaultState { lock.withLock { state } }

    /// Apply faults for `/api/*`; otherwise pass through.
    func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        let path = req.url.path
        let start = Date()

        if path.hasPrefix("/api/") {
            let faultState = current()

            // Rate limit: reject immediately
            if faultState.rateLimit {
                let response = Self.errorResponse(req: req, status: .tooManyRequests, code: "RATE_LIMIT", message: "Too many requests")
                log(req: req, status: response.status, start: start)
                return req.eventLoop.makeSucceededFuture(response)
            }

            // Error rate: random fail
            if faultState.errorRate > 0 {
                let random = Int.random(in: 0..<100)
                if random < faultState.errorRate {
                    let response = Self.errorResponse(req: req, status: .internalServerError, code: "SERVER_ERROR", message: "Injected server error")
                    log(req: req, status: response.status, start: start)
                    return req.eventLoop.makeSucceededFuture(response)
                }
            }

            // Latency: schedule delay if needed
            if faultState.latencyMs > 0 {
                return req.eventLoop.scheduleTask(in: .milliseconds(Int64(faultState.latencyMs))) {
                }
                .futureResult
                .flatMap {
                    next.respond(to: req)
                }
                .map { response in
                    self.log(req: req, status: response.status, start: start)
                    return response
                }
            }
        }

        return next.respond(to: req).map { response in
            if path.hasPrefix("/api/") {
                self.log(req: req, status: response.status, start: start)
            }
            return response
        }
    }

    private func log(req: Request, status: HTTPResponseStatus, start: Date) {
        let milliseconds = Int(Date().timeIntervalSince(start) * 1_000)
        req.logger.info("[API] \(req.method.string) \(req.url.path) -> \(status.code) (\(milliseconds)ms)")
    }

    /// Build a uniform API error JSON response.
    static func errorResponse(req _: Request, status: HTTPResponseStatus, code: String, message: String) -> Response {
        struct APIError: Content {
            let code: String
            let message: String
        }
        let payload = APIError(code: code, message: message)
        let response = Response(status: status)
        do {
            response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
            let data = try JSONEncoder().encode(payload)
            response.body = .init(data: data)
        } catch {
            response.body = .init(string: "{\"code\":\"SERVER_ERROR\",\"message\":\"encoding failed\"}")
        }
        return response
    }
}
