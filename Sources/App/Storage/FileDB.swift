import Foundation
import Vapor

/// Very small file-backed store for users and posts.
/// Holds in-memory arrays and flushes to `db.json`.
final class FileDB {
    struct Snapshot: Codable {
        var users: [User]
        var posts: [Post]
    }

    static var shared = FileDB()

    private let queue = DispatchQueue(label: "FileDB.queue")
    private let fileURL: URL
    private(set) var users: [User]
    private(set) var posts: [Post]

    /// - Parameters:
    ///   - path: Optional custom path for the backing JSON file.
    ///   - inMemory: If true, avoid persistent writes (for tests).
    init(path: String? = nil, inMemory: Bool = false) {
        if let path, inMemory == false {
            self.fileURL = URL(fileURLWithPath: path)
        } else {
            self.fileURL = AppConfig.databaseFileURL(inMemory: inMemory)
        }
        self.users = []
        self.posts = []
    }

    /// Load snapshot from disk if present; otherwise initialize and save.
    func load(app: Application? = nil) {
        queue.sync {
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: fileURL.path) {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let snapshot = try decoder.decode(Snapshot.self, from: data)
                    self.users = snapshot.users
                    self.posts = snapshot.posts
                } else {
                    if !self.users.contains(where: { $0.id == "me" }) {
                        self.users.append(User(id: "me", displayName: "Trainee", avatarUrl: nil))
                    }
                    saveLocked()
                }
            } catch {
                app?.logger.report(error: error)
            }
        }
    }

    /// Save the current snapshot to disk.
    func save() {
        queue.sync { saveLocked() }
    }

    private func saveLocked() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Snapshot(users: users, posts: posts))
            if fileURL.path.contains("/dev/null") == false {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            print("[FileDB] Save error: \(error)")
        }
    }

    /// Reset to empty posts and a default "me" user.
    func reset() {
        queue.sync {
            self.users = [User(id: "me", displayName: "Trainee", avatarUrl: nil)]
            self.posts = []
            saveLocked()
        }
    }

    /// Load seed JSON from a relative path and persist it.
    func seed(fromSeedPath path: String) throws {
        try queue.sync {
            let workingDirectory = DirectoryConfiguration.detect().workingDirectory
            let url = URL(fileURLWithPath: workingDirectory + path)
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(Snapshot.self, from: data)
            self.users = snapshot.users
            if !self.users.contains(where: { $0.id == "me" }) {
                self.users.insert(User(id: "me", displayName: "Trainee", avatarUrl: nil), at: 0)
            }
            self.posts = snapshot.posts.sorted { left, right in
                left.createdAt > right.createdAt
            }
            saveLocked()
        }
    }

    /// Return all users (snapshot).
    func allUsers() -> [User] { queue.sync { users } }

    /// Find a user by ID.
    func findUser(id: String) -> User? { queue.sync { users.first { $0.id == id } } }

    /// Insert or replace a user, then save.
    func upsertUser(_ user: User) {
        queue.sync {
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = user
            } else {
                users.append(user)
            }
            saveLocked()
        }
    }

    /// Compute the next post ID as `p_<n+1>`.
    func nextPostID() -> String {
        queue.sync {
            let maxNumber: Int = posts.compactMap { post in
                if post.id.hasPrefix("p_") {
                    return Int(post.id.dropFirst(2))
                }
                return nil
            }.max() ?? 0
            return "p_\(maxNumber + 1)"
        }
    }

    /// Create a new post at the head of the timeline.
    func addPost(author: User, text: String, imageUrl: String?) -> Post {
        queue.sync {
            let id = nextPostID()
            let post = Post(id: id, author: author, text: text, imageUrl: imageUrl, likeCount: 0, likedByMe: false, createdAt: Date())
            posts.insert(post, at: 0)
            saveLocked()
            return post
        }
    }

    /// Toggle like from local user "me" and save.
    func toggleLike(postID: String) -> Post? {
        queue.sync {
            guard let index = posts.firstIndex(where: { $0.id == postID }) else {
                return nil
            }
            var post = posts[index]
            if post.likedByMe {
                post.likedByMe = false
                post.likeCount = max(0, post.likeCount - 1)
            } else {
                post.likedByMe = true
                post.likeCount += 1
            }
            posts[index] = post
            saveLocked()
            return post
        }
    }

    /// Return a page of posts sorted by `createdAt` desc.
    func getPage(page: Int, pageSize: Int) -> PostsPage {
        queue.sync {
            let sorted = posts.sorted { left, right in
                left.createdAt > right.createdAt
            }
            let startIndex = max(0, (page - 1) * pageSize)
            let endIndex = min(sorted.count, startIndex + pageSize)
            let items = startIndex < endIndex ? Array(sorted[startIndex..<endIndex]) : []
            let nextPage = endIndex < sorted.count ? page + 1 : nil
            return PostsPage(items: items, nextPage: nextPage)
        }
    }
}
