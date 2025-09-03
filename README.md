# VaporSNSSandbox

An all-local sandbox server for iOS training, acting as a simple SNS backend. Built with Vapor 4 and Swift 5.9+, no Docker or Node required. The API and a minimal admin web UI are served from the same origin.

## Requirements
- macOS 13+
- Xcode 15 / Swift 5.9+
- Vapor 4 (resolved via SwiftPM)

## Getting Started
- Run server: `make dev` (binds to 127.0.0.1:8080)
- Apply seed: `make seed` (copies `Resources/seed.json` to `db.json`)
- Reset DB: `make reset` (empties posts and keeps user "me")

Admin UI: http://127.0.0.1:8080/admin

Health check: `GET /health` → `{"ok":true}`

Note for iOS simulator/device: always use `127.0.0.1:8080` as the base URL. Depending on environment, `localhost` may not resolve to the host interface seen by the simulator.

## API Summary (Base URL: http://127.0.0.1:8080)
Common error payload:
```
{ "code": "RATE_LIMIT" | "SERVER_ERROR" | "NOT_FOUND" | "BAD_REQUEST", "message": "human readable message" }
```

- `GET /health` → 200 `{ "ok": true }`
- `GET /api/posts?page={n}` → timeline in descending order, 20 items per page
  - 200 `{ "items": [...Post], "nextPage": 2 | null }`
- `POST /api/posts` → create a new post as user "me"
  - Body `{ text: string[1..140], imageUrl: string|null }`
  - 201: created Post
- `POST /api/posts/{id}/like` → toggle like
  - 200: updated Post, 404: NOT_FOUND
- `GET /api/users/me` → current user
- `PATCH /api/users/me` → update displayName and avatarUrl

Examples (curl):
```
curl -s http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080/api/posts?page=1
curl -s -X POST http://127.0.0.1:8080/api/posts \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello","imageUrl":null}'
curl -s -X POST http://127.0.0.1:8080/api/posts/p_1/like
```

## Admin Web (/admin)
- Seed apply: `POST /admin/seed`
- DB reset: `POST /admin/reset`
- Fault injection: `POST /admin/faults` → `{ latencyMs:0..2000, rateLimit:bool, errorRate:0..100 }`
- Spawn post as other user: `POST /admin/spawn` → `{ authorId, text, imageUrl }`

Fault injection applies to all `/api/*` requests.

## Implementation Notes
- JSON uses camelCase; dates use ISO8601 (Z).
- Pagination: descending by `createdAt`, 20 items per page.
- `likedByMe` assumes a fixed local user "me".
- Storage persists to `db.json` at repo root; loads on boot and saves on shutdown.
- Logging: one-line method/path/status/latency for `/api/*`; admin setting changes are also logged.

## Known Limitations
- Authentication, notifications, following are out of scope.
- CORS is disabled; same-origin only.

## Tests
Run `swift test` to verify timeline paging and fault injection basics.
