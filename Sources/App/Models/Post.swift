import Vapor

/// A post in the timeline.
/// - Important: `createdAt` is encoded/decoded as ISO8601(Z).
struct Post: Content, Identifiable {
    var id: String
    var author: User
    var text: String
    var imageUrl: String?
    var likeCount: Int
    var likedByMe: Bool
    var createdAt: Date
}

/// Paged response for posts.
struct PostsPage: Content {
    var items: [Post]
    var nextPage: Int?
}
