import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

enum ConverterDataMode {
  onlineFresh,
  offlineCached,
  offlineNoData,
}

class ConverterDataState {
  final ConverterDataMode mode;
  final Map<String, double> ratesInrByCode;
  final DateTime? fetchedAt;
  final int sourceCount;

  const ConverterDataState({
    required this.mode,
    required this.ratesInrByCode,
    this.fetchedAt,
    this.sourceCount = 0,
  });

  bool get hasRates => ratesInrByCode.isNotEmpty;
}

const _converterSnapshotVersion = 1;

final converterDataProvider =
    FutureProvider.autoDispose<ConverterDataState>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(marketRepositoryProvider);
  Future<ConverterDataState> loadCachedOrEmpty() async {
    final raw = prefs.getString(AppConstants.prefConverterFxSnapshot);
    if (raw == null || raw.trim().isEmpty) {
      return const ConverterDataState(
        mode: ConverterDataMode.offlineNoData,
        ratesInrByCode: {},
      );
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = ConverterFxSnapshot.fromJson(decoded);
      if (snapshot.version != _converterSnapshotVersion ||
          snapshot.ratesInrByCode.isEmpty) {
        return const ConverterDataState(
          mode: ConverterDataMode.offlineNoData,
          ratesInrByCode: {},
        );
      }
      return ConverterDataState(
        mode: ConverterDataMode.offlineCached,
        ratesInrByCode: snapshot.ratesInrByCode,
        fetchedAt: snapshot.fetchedAt,
        sourceCount: snapshot.sourceCount,
      );
    } catch (_) {
      return const ConverterDataState(
        mode: ConverterDataMode.offlineNoData,
        ratesInrByCode: {},
      );
    }
  }

  if (await isOffline()) {
    return loadCachedOrEmpty();
  }

  try {
    final response = await repo
        .getLatestMarketPrices(instrumentType: 'currency')
        .timeout(const Duration(seconds: 8));
    final rates = _inrRateMap(response.prices);
    if (rates.isNotEmpty) {
      final snapshot = ConverterFxSnapshot(
        version: _converterSnapshotVersion,
        fetchedAt: DateTime.now().toUtc(),
        ratesInrByCode: rates,
        sourceCount: response.prices.length,
      );
      prefs.setString(
        AppConstants.prefConverterFxSnapshot,
        jsonEncode(snapshot.toJson()),
      );
      return ConverterDataState(
        mode: ConverterDataMode.onlineFresh,
        ratesInrByCode: snapshot.ratesInrByCode,
        fetchedAt: snapshot.fetchedAt,
        sourceCount: snapshot.sourceCount,
      );
    }
  } catch (_) {
    // Fall through to cached snapshot lookup.
  }
  return loadCachedOrEmpty();
});

Map<String, double> _inrRateMap(List<MarketPrice> rows) {
  final map = <String, double>{'INR': 1.0};
  for (final row in rows) {
    final asset = row.asset.trim();
    if (!asset.contains('/INR')) continue;
    final code = asset.split('/').first.toUpperCase();
    map[code] = row.price;
  }
  for (final pair in Entities.fx) {
    if (!pair.contains('/INR')) continue;
    final code = pair.split('/').first.toUpperCase();
    map.putIfAbsent(code, () => 0);
  }
  return map;
}
