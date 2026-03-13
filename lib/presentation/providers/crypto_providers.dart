import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/connectivity.dart';
import '../../data/models/market_price.dart';
import '../../core/constants.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

final latestCryptoProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(cryptoRepositoryProvider);

  List<MarketPrice> loadCached() {
    final raw = prefs.getString(AppConstants.prefCacheLatestCrypto);
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
    throw StateError('No internet connection and no cached crypto data.');
  }

  try {
    final response =
        await repo.getLatestCrypto().timeout(const Duration(seconds: 8));
    if (response.prices.isNotEmpty) {
      prefs.setString(
        AppConstants.prefCacheLatestCrypto,
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

final cryptoHistoryProvider = FutureProvider.autoDispose
    .family<List<MarketPrice>, String>((ref, asset) async {
  final repo = ref.watch(cryptoRepositoryProvider);
  final response = await repo.getCrypto(
    asset: asset,
    limit: AppConstants.chartDataLimit,
  );
  return response.prices;
});
