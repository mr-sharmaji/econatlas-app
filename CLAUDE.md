# econatlas-app

Flutter app. Backend API: https://api.velqon.xyz (OpenAPI docs at `/docs`).

## Layout (`lib/`)
- `main.dart`, `router.dart` — entrypoint + go_router config
- `core/` — theme, constants, utils, error handling (shared across features)
- `data/` — API clients, repositories, DTOs
- `domain/` — models, business logic
- `presentation/` — screens + widgets (Riverpod `ConsumerWidget`s)

## Stack
- State: **flutter_riverpod** (providers in `presentation/providers/`)
- Routing: **go_router**
- Networking: hits `api.velqon.xyz` — see `data/` for client

## Central primitives (god nodes — import-heavy hubs)
- `core/theme.dart`, `core/constants.dart`, `core/utils.dart` — shared foundations
- `core/error_utils.dart` — error handling
- `presentation/providers/providers.dart` — Riverpod provider barrel
- `presentation/widgets/widgets.dart` — widget barrel

## Working efficiently (reduce tokens)
Before opening files, query the pre-built knowledge graph:

```bash
graphify query "<question>"            # BFS over graph.json, ~2k tokens
graphify explain "<node>"              # explain a widget/provider and its neighbors
graphify path "<A>" "<B>"              # shortest connection between two symbols
```

Graph lives at `graphify-out/graph.json` (not committed — regenerate with `graphify update .`).

Prefer `graphify query` over wide `grep` / reading many screens. Fall back to Read only for the specific files the graph points to.

## Backend API (EconAtlas v0.2.2, 84 endpoints)
Base: `https://api.velqon.xyz` · Full spec: `/openapi.json` · Swagger: `/docs`

Route groups:
- `/assets` — asset catalog
- `/brief` — post-market, movers, most-active, sectors
- `/broker-charges`
- `/chat` — streaming chat, sessions, feedback, greeting, suggestions, autocomplete
- `/commodities`, `/crypto`, `/market` — ingest + list + intraday + latest
- `/events`, `/feedback`, `/news`
- `/ipos` — list, alerts, device registration
- `/macro` — indicators, flows, forecasts, calendar, regime, linkages, summary
- `/market/scores`, `/market/story`, `/market/status`
- `/ops` — admin: job trigger/abort/rescore, tables CRUD, logs, metrics
- `/screener` — overview, search, stocks/mutual-funds list + detail + history + intraday + sparklines + peers + story + score-history
- `/health`

For unfamiliar endpoints, curl `https://api.velqon.xyz/openapi.json` and `jq '.paths["/path"]'` rather than reading backend source.

## Conventions
- Riverpod: `ref.watch` in build, `ref.read` in callbacks.
- INR conversion for commodity/crypto: use `usdInrRateProvider` + `assetDisplayValue` in `core/utils.dart`.
- Never edit `graphify-out/` — it's a generated artifact.

## Planning gate (cuts rework)
Before any edit, state the approach as 3–5 bullets and wait for "go" before editing. Applies to every change, no matter how small. Saves the "wrong logic, redo" loop.

## Comment discipline
Keep comments minimal. Default to none. Only add one when the *why* is non-obvious — a hidden constraint, subtle invariant, or workaround for a known bug. Never comment what the code does (good names suffice). Never reference the current task, fix, or PR.

## Backend debugging from this repo
If a bug looks backend-originated, don't grep Flutter files — query the backend directly:
- Logs: `curl 'https://api.velqon.xyz/ops/logs?level=error&since=1h&limit=200'`
- DB: `curl -X POST https://api.velqon.xyz/ops/sql -d '{"query":"SELECT ... LIMIT 50"}' -H 'Content-Type: application/json'`
- Schema snapshot: `../econatlas-backend/docs/db_schema.md`

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
