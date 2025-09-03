import Vapor

/// Centralized application configuration and file path helpers.
enum AppConfig {
    /// Database file name at repository root.
    static let databaseFileName = "db.json"

    /// Relative path to seed JSON file.
    static let seedRelativePath = "Resources/seed.json"

    /// Compute the absolute URL for the database file.
    /// - Parameter inMemory: If true, returns a sink URL to avoid writes.
    static func databaseFileURL(inMemory: Bool) -> URL {
        let workingDirectory = DirectoryConfiguration.detect().workingDirectory
        if inMemory {
            return URL(fileURLWithPath: workingDirectory).appendingPathComponent("/dev/null")
        }
        return URL(fileURLWithPath: workingDirectory).appendingPathComponent(databaseFileName)
    }

    /// Compute absolute URL for the seed file.
    static func seedFileURL() -> URL {
        let workingDirectory = DirectoryConfiguration.detect().workingDirectory
        return URL(fileURLWithPath: workingDirectory).appendingPathComponent(seedRelativePath)
    }
}

