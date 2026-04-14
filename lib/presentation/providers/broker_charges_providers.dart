import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/constants.dart';
import '../../data/models/broker_charges.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

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
      return BrokerChargesResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
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
