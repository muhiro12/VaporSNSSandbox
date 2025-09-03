# AGENTS.md

## Coding Guidelines for Codex Agents

This document defines the minimum coding standards for implementing code in the **VaporSNSSandbox** project.  
It is intended to ensure that Codex Agents and human developers produce consistent, maintainable, and testable code.

---

## Swift Code Guidelines

### Follow SwiftLint rules

All Swift code **must** comply with the SwiftLint rules defined in the project.  
If you are generating code with Codex, ensure that the output passes lint checks before committing.

### Avoid abbreviated variable names

Do not use unclear abbreviations such as `res`, `img`, or `btn`.  
Use descriptive and explicit names like `result`, `image`, or `button`.

### Use `.init(...)` when the return type is explicitly known

In contexts where the return type is clear (e.g., function return values, computed properties), use `.init(...)` for initialization.  
This keeps code concise and avoids redundancy.

#### Examples

```swift
var user: User {
    .init(name: "Alice") // ✅ OK: return type is explicitly User
}

func makeUser() -> User {
    .init(name: "Bob") // ✅ OK
}

let user = User(name: "Carol") // ❌ Less preferred when type is not obvious
```

### Multiline control-flow and trailing-closure formatting

Avoid single-line bodies for **any** control-flow statement (`if`, `guard`, `while`, `switch`, etc.) or trailing closures.  
Always place the body on its own indented line between braces to improve readability and make diffs cleaner.

#### Preferred

```swift
guard let currentUser = optionalUser else {
    return
}

if isDebugMode {
    logger.debug("Entering debug state")
}

tasks.filter {
    $0.isCompleted
}
```

#### Not preferred

```swift
guard let currentUser = optionalUser else { return }
if isDebugMode { logger.debug("Entering debug state") }
tasks.filter { $0.isCompleted }
```

---

## Vapor / Server-Side Conventions

### Folder structure

The project must maintain the following top-level folder structure:

```
VaporSNSSandbox/
  Package.swift
  Public/         # Static files for /admin
  Resources/      # seed.json and other data
  Sources/
    App/          # Main Vapor application
    Run/          # Entry point
  Tests/          # Unit tests
```

This ensures clear separation of responsibilities and a predictable layout for Codex Agents to generate code into.

### HTTP APIs

- All `/api/*` endpoints must return JSON responses using camelCase keys.
- Error responses must use the common format:
  ```json
  {
    "code": "RATE_LIMIT",
    "message": "Too many requests"
  }
  ```
- Admin endpoints under `/admin` are for controlling faults, seeding data, and managing the sandbox.  
  These must also use JSON request/response bodies.

### Data persistence

- The system uses a simple JSON file database (`db.json`) for persistence.
- At startup, data is loaded into memory; at shutdown, data is flushed back to disk.
- Codex-generated code must **never** hardcode file paths; always use configuration constants or helper methods.

### Fault injection

All request faults (latency, random errors, rate limiting) are applied via a single middleware:  
`FaultInjectionMiddleware`.  
When updating or extending fault behavior, always modify this middleware to keep fault logic centralized.

---

## Markdown Guidelines

### Follow markdownlint rules for Markdown files

All Markdown documents must conform to the rules defined at:  
https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md

This includes `README.md`, `AGENTS.md`, and any documentation in the repository.

---

## Project-wide Conventions

### Use English for naming and comments

Use English for:

- Branch names (e.g., `feature/add-fault-injection`, `bugfix/reset-seed-error`)
- Code comments
- Documentation and identifiers (variables, methods, etc.)

Avoid using Japanese or other non-English languages in code unless strictly necessary (e.g., UI text for sample data).

### Commit messages

- Use short, descriptive English sentences.  
  Example:  
  ```
  Add POST /api/posts like toggle endpoint
  Fix rate limit fault injection timing issue
  ```

---

## Test Commands

The test suite is based on **SwiftPM** and can be run on macOS or Linux.

### Build and test the project
```sh
swift build
swift test
```

### Run the development server
```sh
swift run Run serve --port 8080
```

### Makefile shortcuts
For convenience, the following `make` targets are available:

- `make dev` – Run server in development mode (port 8080)
- `make seed` – Load `seed.json` into `db.json`
- `make reset` – Reset `db.json` to empty state

---

## Linux compatibility

The project must remain fully buildable and runnable on Linux environments such as **Ubuntu 22.04**.  
Ensure that all Swift code and dependencies avoid macOS-only APIs.

Test periodically with:

```sh
swift build --configuration release
swift test
```

If targeting Linux servers, bind to all interfaces:

```sh
swift run Run serve --hostname 0.0.0.0 --port 8080
```

---

## Acceptance Criteria for Codex Output

Codex-generated code must meet these criteria before being merged:

- Passes `swift build` and `swift test` with no warnings or errors.
- Adheres to SwiftLint rules.
- Matches the folder structure and naming conventions in this document.
- Provides clear, maintainable code with descriptive names and comments.
- Fully implements the API contract defined in the `README.md` and OpenAPI spec.
- Includes at least one unit test for each controller (e.g., PostsController, UsersController).

---

By following these guidelines, Codex and human contributors can collaborate seamlessly to evolve **VaporSNSSandbox** into a reliable, educational backend for iOS app training.
