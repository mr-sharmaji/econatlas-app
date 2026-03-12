import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/connectivity.dart';
import '../../data/models/market_price.dart';
import '../../core/constants.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

final latestCommoditiesProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(commodityRepositoryProvider);

  List<MarketPrice> loadCached() {
    final raw = prefs.getString(AppConstants.prefCacheLatestCommodities);
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
    throw StateError('No internet connection and no cached commodity data.');
  }

  try {
    final response =
        await repo.getLatestCommodities().timeout(const Duration(seconds: 8));
    if (response.prices.isNotEmpty) {
      prefs.setString(
        AppConstants.prefCacheLatestCommodities,
        jsonEncode(response.prices.map((e) => e.toJson()).toList()),
      );
    }
    return response.prices;
  } catch (_) {
    final cached = loadCached();
    if (cached.isNotEmpty) return cached;
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
