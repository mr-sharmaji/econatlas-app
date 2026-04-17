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

## Conventions
- Riverpod: `ref.watch` in build, `ref.read` in callbacks.
- INR conversion for commodity/crypto: use `usdInrRateProvider` + `assetDisplayValue` in `core/utils.dart`.
- Never edit `graphify-out/` — it's a generated artifact.
