import Vapor

/// `/api/posts` timeline endpoints.
final class PostsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api", "posts")
        api.get(use: getPosts)
        api.post(use: createPost)
        api.post(":id", "like", use: toggleLike)
    }

    private let pageSize = 20

    /// Returns a page of posts (descending by createdAt).
    private func getPosts(req: Request) throws -> EventLoopFuture<PostsPage> {
        let page = (try? req.query.get(Int.self, at: "page")) ?? 1
        let postsPage = FileDB.shared.getPage(page: max(1, page), pageSize: pageSize)
        return req.eventLoop.makeSucceededFuture(postsPage)
    }

    struct CreatePostRequest: Content {
        let text: String
        let imageUrl: String?
    }

    /// Creates a post as "me". Validates text length 1..140.
    private func createPost(req: Request) throws -> EventLoopFuture<Response> {
        guard let body = try? req.content.decode(CreatePostRequest.self) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "Invalid JSON"))
        }
        let count = body.text.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard (1...140).contains(count) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "text must be 1..140 chars"))
        }
        let me = FileDB.shared.findUser(id: "me") ?? User(id: "me", displayName: "Trainee", avatarUrl: nil)
        let post = FileDB.shared.addPost(author: me, text: body.text, imageUrl: body.imageUrl)
        let response = Response(status: .created)
        do {
            response.headers.contentType = .json
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            response.body = .init(data: try encoder.encode(post))
        } catch {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .internalServerError, code: "SERVER_ERROR", message: "encoding failed"))
        }
        return req.eventLoop.makeSucceededFuture(response)
    }

    /// Toggles like for a post by ID. Returns 404 if not found.
    private func toggleLike(req: Request) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id") else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .badRequest, code: "BAD_REQUEST", message: "missing id"))
        }
        guard let updated = FileDB.shared.toggleLike(postID: id) else {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .notFound, code: "NOT_FOUND", message: "post not found"))
        }
        let response = Response(status: .ok)
        do {
            response.headers.contentType = .json
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            response.body = .init(data: try encoder.encode(updated))
        } catch {
            return req.eventLoop.makeSucceededFuture(FaultInjectionMiddleware.errorResponse(req: req, status: .internalServerError, code: "SERVER_ERROR", message: "encoding failed"))
        }
        return req.eventLoop.makeSucceededFuture(response)
    }
}
