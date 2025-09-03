import Vapor

/// A simple user model.
/// - Note: IDs like "u_1" or special "me" are used.
struct User: Content, Equatable, Identifiable {
    var id: String
    var displayName: String
    var avatarUrl: String?
}
