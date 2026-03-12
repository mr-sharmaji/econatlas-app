# EconAtlas App

Flutter mobile app for **EconAtlas** — a Personal Economic Intelligence System. The app is **production-ready**: it talks to the EconAtlas FastAPI backend for live and historical data, supports dark/light theme, configurable backend URL, and optional INR/USD commodity units.

## Features

- **Dashboard** — Summary cards for key indices, commodities, and latest news; relative timestamps (“20 hours ago”).
- **Markets** — Indices (US & India), currencies (FX vs INR), bond yields; latest prices, daily charts, relative time per asset.
- **Commodities** — Gold, silver, crude oil, natural gas, copper; latest prices, charts, optional INR units (e.g. per 10g gold, per kg silver).
- **Macro** — Inflation, interest rates, GDP growth for US and India; relative time per indicator.
- **News** — Financial news with impact and entity tags; open links in browser.
- **Events** — Unified feed of economic events with confidence.
- **Discover** — India-focused Stock + Mutual Fund screener with presets, advanced filters, source health badges, and compare mode.
- **Settings** — Backend URL (default `https://api.velqon.xyz`), theme (light/dark), commodity price units (USD or INR).

## Architecture

- **Data** — Models, remote API (Dio), repository implementations.
- **Domain** — Repository interfaces.
- **Presentation** — Screens, shared widgets (e.g. PriceCard, ChartWidget, Shimmer), Riverpod providers.

## Tech Stack

- **Flutter** 3.x
- **State** — Riverpod
- **HTTP** — Dio with retry
- **Routing** — go_router, StatefulShellRoute (bottom nav)
- **Charts** — fl_chart
- **Theme** — Material 3, dark mode default

## Setup

```bash
# Install Flutter: https://docs.flutter.dev/get-started/install

cd econatlas-app
flutter pub get
flutter run
```

For a specific device:

```bash
flutter run -d android
flutter run -d ios
```

## Configuration

- **Backend URL**: Default is `https://api.velqon.xyz`. Change in **Settings → Backend URL** for a self-hosted or local backend.
- **Commodity units**: In Settings, choose **Price display → Commodity price units**: USD or INR (default INR).
- **Theme**: Settings → Appearance → Light / Dark.

## Build Release APK

```bash
cd econatlas-app
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. Install with `adb install build/app/outputs/flutter-apk/app-release.apk` or copy to device.

## Project Structure

```
lib/
├── core/              # Theme, constants, Dio client, formatters (e.g. relative time)
├── data/
│   ├── models/        # Immutable data classes, JSON serialization
│   ├── datasources/   # Remote API
│   └── repositories/  # Repository implementations
├── domain/
│   └── repositories/  # Abstract repository interfaces
├── presentation/
│   ├── screens/       # Dashboard, Market, Commodities, News, Macro, Events, Settings
│   ├── widgets/       # PriceCard, ImpactBadge, ChartWidget, Shimmer, etc.
│   └── providers/     # Riverpod providers
├── router.dart        # go_router config
└── main.dart
```

## Backend API Used

The app uses the EconAtlas backend (see `econatlas-backend`):

| Endpoint            | Purpose                          |
| ------------------- | --------------------------------- |
| GET /health         | Connectivity check                |
| GET /market/latest  | Latest indices, FX, bonds         |
| GET /market         | History for charts                |
| GET /commodities/latest | Latest commodity prices     |
| GET /commodities    | Commodity history for charts      |
| GET /macro          | Macro indicators                  |
| GET /news           | News articles                     |
| GET /events         | Economic events                   |
| GET /screener/overview | Discover segment summary      |
| GET /screener/stocks | Discover stock screener          |
| GET /screener/mutual-funds | Discover mutual fund screener |
| GET /screener/compare | Compare selected discover items |

Ensure the backend is running and reachable at the URL configured in the app (default `https://api.velqon.xyz`).
