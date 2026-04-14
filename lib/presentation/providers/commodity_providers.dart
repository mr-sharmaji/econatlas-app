import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/connectivity.dart';
import '../../core/refresh_helper.dart';
import '../../data/models/market_price.dart';
import '../../core/constants.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

/// Force a fresh network fetch for [latestCommoditiesProvider],
/// bypassing the cached-return-then-background-refresh path.
///
/// See `forceRefreshLatestCrypto` for the rationale — same pattern.
Future<void> forceRefreshLatestCommodities(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.remove(AppConstants.prefCacheLatestCommodities);
  await prefs.remove(AppConstants.prefCacheLatestCommoditiesTs);
  try {
    await refreshFuture(ref, latestCommoditiesProvider.future);
  } catch (_) {}
}

final latestCommoditiesProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(commodityRepositoryProvider);
  const cacheKey = AppConstants.prefCacheLatestCommodities;
  const tsKey = AppConstants.prefCacheLatestCommoditiesTs;

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

  void saveCacheTimestamp() {
    prefs.setString(
      tsKey,
      DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
    );
  }

  if (await isOffline()) {
    final cached = loadCached();
    if (cached.isNotEmpty) return cached;
    throw StateError('No internet connection and no cached commodity data.');
  }

  // Return cached data immediately, then refresh from server in background.
  final cached = loadCached();
  if (cached.isNotEmpty) {
    Future.microtask(() async {
      try {
        final response = await repo
            .getLatestCommodities()
            .timeout(const Duration(seconds: 8));
        if (response.prices.isNotEmpty) {
          prefs.setString(
            cacheKey,
            jsonEncode(response.prices.map((e) => e.toJson()).toList()),
          );
          saveCacheTimestamp();
        }
      } catch (_) {
        // Background refresh failed — cached data still valid.
      }
    });
    return cached;
  }

  // No cache — fetch from server.
  try {
    final response =
        await repo.getLatestCommodities().timeout(const Duration(seconds: 8));
    if (response.prices.isNotEmpty) {
      prefs.setString(
        cacheKey,
        jsonEncode(response.prices.map((e) => e.toJson()).toList()),
      );
      saveCacheTimestamp();
    }
    return response.prices;
  } catch (_) {
    final fallback = loadCached();
    if (fallback.isNotEmpty) return fallback;
    rethrow;
  }
});

final commodityHistoryProvider = FutureProvider.autoDispose
    .family<List<MarketPrice>, String>((ref, asset) async {
  final repo = ref.watch(commodityRepositoryProvider);
  final response = await repo.getCommodities(
    asset: asset,
    limit: AppConstants.chartDataLimit,
  );
  return response.prices;
});

final commodityHistoryRangeProvider = FutureProvider.autoDispose
    .family<List<MarketPrice>, ({String asset, int days})>((ref, key) async {
  final repo = ref.watch(commodityRepositoryProvider);
  final limit = (key.days * 1.15).ceil();
  final response = await repo.getCommodities(
    asset: key.asset,
    limit: limit,
  );
  return response.prices;
});
