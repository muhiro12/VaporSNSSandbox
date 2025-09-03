import App
import Vapor

/// Entry point. Boots the application using the configured environment
/// and runs the HTTP server until termination.
var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()
