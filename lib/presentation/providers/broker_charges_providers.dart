import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/constants.dart';
import '../../data/models/broker_charges.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

/// Force a fresh network fetch for [brokerChargesProvider], bypassing
/// the cached-return-then-background-refresh path.
///
/// Pull-to-refresh (and the AppBar refresh button on the trade charges
/// screen) should `await` this rather than just invalidating, because
/// the provider returns cached data instantly when present and only
/// fires the network refresh in a non-awaited microtask.
Future<void> forceRefreshBrokerCharges(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.remove(AppConstants.prefCacheBrokerCharges);
  await prefs.remove(AppConstants.prefCacheBrokerChargesTs);
  ref.invalidate(brokerChargesProvider);
  try {
    await ref.read(brokerChargesProvider.future);
  } catch (_) {}
}

final brokerChargesProvider =
    FutureProvider.autoDispose<BrokerChargesResponse>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final remote = ref.watch(remoteDataSourceProvider);
  const cacheKey = AppConstants.prefCacheBrokerCharges;
  const tsKey = AppConstants.prefCacheBrokerChargesTs;

  BrokerChargesResponse? loadCached() {
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final parsed = BrokerChargesResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // Cache-version gate: any cache saved before the amc_note field
      // was added to the API response will have an empty amc_note for
      // every broker. That's distinguishable from "API returned no
      // AMC info" because at least one broker (e.g. Zerodha) always
      // has a populated amc_note on the server. Drop those stale caches
      // so the UI doesn't hide the AMC block on first open after update.
      final anyAmcNote = parsed.brokers.values.any(
        (b) => b.amcNote.trim().isNotEmpty || b.amcRules.isNotEmpty,
      );
      if (!anyAmcNote) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  void saveCache(BrokerChargesResponse data) {
    prefs.setString(cacheKey, jsonEncode(data.toJson()));
    prefs.setString(
      tsKey,
      DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
    );
  }

  if (await isOffline()) {
    final cached = loadCached();
    if (cached != null) return cached;
    throw StateError('No internet connection and no cached broker charges.');
  }

  // Return cached data immediately, refresh in background.
  final cached = loadCached();
  if (cached != null) {
    Future.microtask(() async {
      try {
        final fresh =
            await remote.getBrokerCharges().timeout(const Duration(seconds: 8));
        if (fresh.brokers.isNotEmpty) {
          saveCache(fresh);
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
        await remote.getBrokerCharges().timeout(const Duration(seconds: 8));
    if (response.brokers.isNotEmpty) {
      saveCache(response);
    }
    return response;
  } catch (_) {
    final fallback = loadCached();
    if (fallback != null) return fallback;
    rethrow;
  }
});
