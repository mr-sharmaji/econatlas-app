import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/connectivity.dart';
import '../../data/models/market_price.dart';
import '../../core/constants.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

/// Force a fresh network fetch for [latestCryptoProvider], bypassing
/// the cached-return-then-background-refresh path.
///
/// Pull-to-refresh handlers should `await` this rather than just
/// invalidating the provider, because the provider returns cached data
/// instantly and only fires the network refresh in a non-awaited
/// `Future.microtask` — so a plain invalidate + await would dismiss
/// the indicator before any new data arrived.
///
/// The trick: clear the SharedPreferences cache key first. With the
/// cache empty, the provider's `loadCached()` returns empty and the
/// "No cache — fetch from server" path runs, which actually awaits.
Future<void> forceRefreshLatestCrypto(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.remove(AppConstants.prefCacheLatestCrypto);
  await prefs.remove(AppConstants.prefCacheLatestCryptoTs);
  ref.invalidate(latestCryptoProvider);
  try {
    await ref.read(latestCryptoProvider.future);
  } catch (_) {}
}

final latestCryptoProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(cryptoRepositoryProvider);
  const cacheKey = AppConstants.prefCacheLatestCrypto;
  const tsKey = AppConstants.prefCacheLatestCryptoTs;

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
    throw StateError('No internet connection and no cached crypto data.');
  }

  // Return cached data immediately, then refresh from server in background.
  final cached = loadCached();
  if (cached.isNotEmpty) {
    Future.microtask(() async {
      try {
        final response = await repo
            .getLatestCrypto()
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
        await repo.getLatestCrypto().timeout(const Duration(seconds: 8));
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

final cryptoHistoryProvider = FutureProvider.autoDispose
    .family<List<MarketPrice>, String>((ref, asset) async {
  final repo = ref.watch(cryptoRepositoryProvider);
  final response = await repo.getCrypto(
    asset: asset,
    limit: AppConstants.chartDataLimit,
  );
  return response.prices;
});

final cryptoHistoryRangeProvider = FutureProvider.autoDispose
    .family<List<MarketPrice>, ({String asset, int days})>((ref, key) async {
  final repo = ref.watch(cryptoRepositoryProvider);
  final limit = (key.days * 1.15).ceil();
  final response = await repo.getCrypto(
    asset: key.asset,
    limit: limit,
  );
  return response.prices;
});
