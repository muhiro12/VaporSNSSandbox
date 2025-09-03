import Vapor

/// Main application configuration: server settings, content config,
/// middlewares, storage loading, routes, and graceful shutdown.
public func configure(_ app: Application) throws {
    app.logger.info("Starting VaporSNSSandbox...")

    // HTTP server binding
    app.http.server.configuration.hostname = "127.0.0.1"
    app.http.server.configuration.port = 8_080

    // JSON encoding/decoding strategy
    ContentConfiguration.global.use(encoder: {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }(), for: .json)
    ContentConfiguration.global.use(decoder: {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }(), for: .json)

    // Middlewares
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(FaultInjectionMiddleware.shared)

    // Load DB
    FileDB.shared.load(app: app)

    try routes(app)

    app.lifecycle.use(
        .init(
            willBoot: { _ in },
            didBoot: { _ in },
            shutdown: { _ in
                FileDB.shared.save()
                app.logger.info("VaporSNSSandbox shutting down.")
            }
        )
    )
}
