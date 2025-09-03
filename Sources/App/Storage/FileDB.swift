import Vapor
import Foundation

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
        let wd = DirectoryConfiguration.detect().workingDirectory
        if inMemory {
            self.fileURL = URL(fileURLWithPath: wd).appendingPathComponent("/dev/null")
        } else {
            let p = path ?? (wd + "db.json")
            self.fileURL = URL(fileURLWithPath: p)
        }
        self.users = []
        self.posts = []
    }

    /// Load snapshot from disk if present; otherwise initialize and save.
    func load(app: Application? = nil) {
        queue.sync {
            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: fileURL.path) {
                    let data = try Data(contentsOf: fileURL)
                    let dec = JSONDecoder()
                    dec.dateDecodingStrategy = .iso8601
                    let snap = try dec.decode(Snapshot.self, from: data)
                    self.users = snap.users
                    self.posts = snap.posts
                } else {
                    // Initialize with default "me" user
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
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(Snapshot(users: users, posts: posts))
            // If in-memory path looks invalid, skip write (useful in tests)
            if fileURL.path.contains("/dev/null") == false {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            // Best-effort; log to stdout if app not available
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
            let wd = DirectoryConfiguration.detect().workingDirectory
            let url = URL(fileURLWithPath: wd + path)
            let data = try Data(contentsOf: url)
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            let snap = try dec.decode(Snapshot.self, from: data)
            self.users = snap.users
            // Ensure "me" exists
            if !self.users.contains(where: { $0.id == "me" }) {
                self.users.insert(User(id: "me", displayName: "Trainee", avatarUrl: nil), at: 0)
            }
            self.posts = snap.posts.sorted(by: { $0.createdAt > $1.createdAt })
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
            if let idx = users.firstIndex(where: { $0.id == user.id }) {
                users[idx] = user
            } else {
                users.append(user)
            }
            saveLocked()
        }
    }

    /// Compute the next post ID as `p_<n+1>`.
    func nextPostID() -> String {
        queue.sync {
            let maxNum: Int = posts.compactMap { p in
                if p.id.hasPrefix("p_") { return Int(p.id.dropFirst(2)) } else { return nil }
            }.max() ?? 0
            return "p_\(maxNum + 1)"
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
            guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return nil }
            var p = posts[idx]
            if p.likedByMe {
                p.likedByMe = false
                p.likeCount = max(0, p.likeCount - 1)
            } else {
                p.likedByMe = true
                p.likeCount += 1
            }
            posts[idx] = p
            saveLocked()
            return p
        }
    }

    /// Return a page of posts sorted by `createdAt` desc.
    func getPage(page: Int, pageSize: Int) -> PostsPage {
        queue.sync {
            let sorted = posts.sorted { $0.createdAt > $1.createdAt }
            let start = max(0, (page - 1) * pageSize)
            let end = min(sorted.count, start + pageSize)
            let slice = start < end ? Array(sorted[start..<end]) : []
            let next = end < sorted.count ? page + 1 : nil
            return PostsPage(items: slice, nextPage: next)
        }
    }
}
