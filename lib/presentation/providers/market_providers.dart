import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/connectivity.dart';
import '../../data/models/models.dart';
import '../../core/constants.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

final marketStatusProvider =
    FutureProvider.autoDispose<MarketStatus>((ref) async {
  final repo = ref.watch(marketRepositoryProvider);
  return repo.getMarketStatus();
});

final latestMarketPricesProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) async {
  return _loadLatestMarketWithCache(
    ref,
    cacheKey: AppConstants.prefCacheLatestMarketAll,
  );
});

final latestIndicesProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) async {
  return _loadLatestMarketWithCache(
    ref,
    instrumentType: 'index',
    cacheKey: AppConstants.prefCacheLatestIndices,
  );
});

final latestCurrenciesProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) async {
  return _loadLatestMarketWithCache(
    ref,
    instrumentType: 'currency',
    cacheKey: AppConstants.prefCacheLatestCurrencies,
  );
});

final latestBondsProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) async {
  return _loadLatestMarketWithCache(
    ref,
    instrumentType: 'bond_yield',
    cacheKey: AppConstants.prefCacheLatestBonds,
  );
});

final marketHistoryProvider = FutureProvider.autoDispose
    .family<List<MarketPrice>, String>((ref, asset) async {
  final repo = ref.watch(marketRepositoryProvider);
  final response = await repo.getMarketPrices(
    asset: asset,
    limit: AppConstants.chartDataLimit,
  );
  return response.prices;
});

/// Range-aware market history — fetches only the rows needed for the selected period.
final marketHistoryRangeProvider = FutureProvider.autoDispose
    .family<List<MarketPrice>, ({String asset, int days})>((ref, key) async {
  final repo = ref.watch(marketRepositoryProvider);
  // Add 10% buffer for weekends/holidays
  final limit = (key.days * 1.15).ceil();
  final response = await repo.getMarketPrices(
    asset: key.asset,
    limit: limit,
  );
  return response.prices;
});

final marketIntradayProvider = FutureProvider.autoDispose
    .family<IntradayResponse, ({String asset, String instrumentType})>(
        (ref, key) async {
  final repo = ref.watch(marketRepositoryProvider);
  return repo.getMarketIntraday(
    asset: key.asset,
    instrumentType: key.instrumentType,
  );
});

final commodityIntradayProvider = FutureProvider.autoDispose
    .family<IntradayResponse, String>((ref, asset) async {
  final repo = ref.watch(marketRepositoryProvider);
  return repo.getCommodityIntraday(asset: asset);
});

final cryptoIntradayProvider = FutureProvider.autoDispose
    .family<IntradayResponse, String>((ref, asset) async {
  final repo = ref.watch(marketRepositoryProvider);
  return repo.getCryptoIntraday(asset: asset);
});

final marketByTypeProvider = FutureProvider.autoDispose
    .family<List<MarketPrice>, String>((ref, instrumentType) async {
  final repo = ref.watch(marketRepositoryProvider);
  final response = await repo.getMarketPrices(
    instrumentType: instrumentType,
    limit: 100,
  );
  return response.prices;
});

final assetCatalogProvider =
    FutureProvider.autoDispose<AssetCatalogResponse>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  // Try to load from local cache (24hr TTL).
  AssetCatalogResponse? loadCached() {
    final raw = prefs.getString(AppConstants.prefCacheAssetCatalog);
    final tsStr = prefs.getString(AppConstants.prefCacheAssetCatalogTs);
    if (raw == null || raw.isEmpty) return null;
    // Check TTL — 24 hours.
    if (tsStr != null) {
      final ts = int.tryParse(tsStr) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > 24 * 60 * 60 * 1000) return null; // Expired
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AssetCatalogResponse.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  final cached = loadCached();
  if (cached != null) {
    // Return cached immediately, refresh in background.
    Future.microtask(() async {
      try {
        final fresh = await ds.getAssetCatalog();
        prefs.setString(
          AppConstants.prefCacheAssetCatalog,
          jsonEncode(fresh.toJson()),
        );
        prefs.setString(
          AppConstants.prefCacheAssetCatalogTs,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      } catch (_) {
        // Background refresh failed — cached data still valid.
      }
    });
    return cached;
  }

  // No cache — fetch from server.
  final fresh = await ds.getAssetCatalog();
  prefs.setString(
    AppConstants.prefCacheAssetCatalog,
    jsonEncode(fresh.toJson()),
  );
  prefs.setString(
    AppConstants.prefCacheAssetCatalogTs,
    DateTime.now().millisecondsSinceEpoch.toString(),
  );
  return fresh;
});

final dataHealthProvider =
    FutureProvider.autoDispose<DataHealthResponse>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return ds.getDataHealth();
});

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, AsyncValue<List<String>>>((ref) {
  final notifier = WatchlistNotifier(ref);
  return notifier;
});

class WatchlistNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final Ref _ref;

  /// Exposed so the UI can show a snackbar / retry indicator on sync errors.
  Object? lastSyncError;

  WatchlistNotifier(this._ref) : super(const AsyncValue.loading()) {
    Future.microtask(_loadLocalThenSync);
  }

  String get _deviceId => _ref.read(deviceIdProvider);

  /// Load from SharedPreferences first (instant), then sync from server in background.
  Future<void> _loadLocalThenSync() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(AppConstants.prefCacheWatchlist);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = (jsonDecode(raw) as List<dynamic>).cast<String>();
        state = AsyncValue.data(decoded);
      } catch (_) {
        // Corrupted cache — fall through to server load.
      }
    }
    // Sync from server in background.
    await load(silent: true);
  }

  Future<void> load({bool silent = false}) async {
    final previous = state.valueOrNull;
    if (!silent || previous == null) {
      state = const AsyncValue.loading();
    }
    lastSyncError = null;
    final next = await AsyncValue.guard(() async {
      final ds = _ref.read(remoteDataSourceProvider);
      final response = await ds.getWatchlist(deviceId: _deviceId);
      return response.assets;
    });
    if (next.hasError) {
      lastSyncError = next.error;
    }
    if (silent && next.hasError && previous != null) {
      state = AsyncValue.data(previous);
      return;
    }
    if (next.hasValue) {
      _persistLocal(next.value!);
    }
    state = next;
  }

  void _persistLocal(List<String> assets) {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      prefs.setString(AppConstants.prefCacheWatchlist, jsonEncode(assets));
    } catch (_) {
      // Best-effort local persistence.
    }
  }

  Future<void> save(List<String> assets) async {
    lastSyncError = null;
    final result = await AsyncValue.guard(() async {
      final ds = _ref.read(remoteDataSourceProvider);
      final response = await ds.putWatchlist(
        deviceId: _deviceId,
        assets: assets,
      );
      return response.assets;
    });
    if (result.hasError) {
      lastSyncError = result.error;
    }
    if (result.hasValue) {
      _persistLocal(result.value!);
    }
    state = result;
  }

  Future<void> toggle(String asset) async {
    final current = state.valueOrNull ?? const <String>[];
    if (current.contains(asset)) {
      final next = current.where((a) => a != asset).toList();
      await save(next);
      return;
    }
    final next = [...current, asset];
    await save(next);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = [...(state.valueOrNull ?? const <String>[])];
    if (oldIndex < 0 || oldIndex >= current.length) return;
    if (newIndex < 0 || newIndex > current.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    await save(current);
  }

  Future<void> resetToDefaults() async {
    final ds = _ref.read(remoteDataSourceProvider);
    final catalog = await ds.getAssetCatalog();
    final defaults = catalog.assets
        .where((a) => a.defaultWatchlist)
        .map((a) => a.asset)
        .toList();
    await save(defaults.isNotEmpty ? defaults : Entities.dashboardAssets);
  }
}

final ipoTabProvider = StateProvider<String>((ref) => 'open');

final ipoListProvider = FutureProvider.autoDispose
    .family<IpoListResponse, String>((ref, status) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return ds.getIpos(status: status, limit: 30);
});

final ipoAlertsProvider =
    StateNotifierProvider<IpoAlertsNotifier, AsyncValue<Set<String>>>((ref) {
  final notifier = IpoAlertsNotifier(ref);
  return notifier;
});

class IpoAlertsNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  final Ref _ref;

  IpoAlertsNotifier(this._ref) : super(const AsyncValue.loading()) {
    Future.microtask(load);
  }

  String get _deviceId => _ref.read(deviceIdProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = _ref.read(remoteDataSourceProvider);
      final response = await ds.getIpoAlerts(deviceId: _deviceId);
      return response.symbols.toSet();
    });
  }

  Future<void> save(Set<String> symbols) async {
    state = await AsyncValue.guard(() async {
      final ds = _ref.read(remoteDataSourceProvider);
      final response = await ds.putIpoAlerts(
        deviceId: _deviceId,
        symbols: symbols.toList(),
      );
      return response.symbols.toSet();
    });
  }

  Future<void> toggle(String symbol) async {
    final current = state.valueOrNull ?? <String>{};
    final next = {...current};
    if (next.contains(symbol)) {
      next.remove(symbol);
    } else {
      next.add(symbol);
    }
    await save(next);
  }
}

final marketStoryProvider = FutureProvider.family<MarketStory,
    ({String asset, String instrumentType})>(
  (ref, params) async {
    final repo = ref.watch(marketRepositoryProvider);
    return repo.getMarketStory(
      asset: params.asset,
      instrumentType: params.instrumentType,
    );
  },
);

/// Bulk action tags for all scored market instruments — keyed by asset name.
final marketScoresProvider = FutureProvider<Map<String, String>>((ref) async {
  final remote = ref.watch(remoteDataSourceProvider);
  return remote.getMarketScores();
});

Future<List<MarketPrice>> _loadLatestMarketWithCache(
  Ref ref, {
  required String cacheKey,
  String? instrumentType,
}) async {
  final repo = ref.watch(marketRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  List<MarketPrice> loadCached() {
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.trim().isEmpty) return const <MarketPrice>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => MarketPrice.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const <MarketPrice>[];
    }
  }

  if (await isOffline()) {
    final cached = loadCached();
    if (cached.isNotEmpty) return cached;
    throw StateError('No internet connection and no cached market data.');
  }

  try {
    final response = await repo
        .getLatestMarketPrices(instrumentType: instrumentType)
        .timeout(const Duration(seconds: 8));
    if (response.prices.isNotEmpty) {
      prefs.setString(
        cacheKey,
        jsonEncode(response.prices.map((e) => e.toJson()).toList()),
      );
    }
    return response.prices;
  } catch (_) {
    final cached = loadCached();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
}
