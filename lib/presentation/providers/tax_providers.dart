import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/connectivity.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

enum TaxConfigSource {
  live,
  cached,
}

int _currentFyStartYearIst() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return now.month >= 4 ? now.year : now.year - 1;
}

class TaxConfigState {
  final TaxConfig config;
  final TaxConfigSource source;

  const TaxConfigState({
    required this.config,
    required this.source,
  });
}

final taxConfigProvider =
    FutureProvider.autoDispose<TaxConfigState>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final ds = ref.watch(remoteDataSourceProvider);

  TaxConfig? cachedConfig() {
    final raw = prefs.getString(AppConstants.prefTaxConfigCache);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return TaxConfig.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  void persistConfig(TaxConfig config) {
    prefs.setString(
        AppConstants.prefTaxConfigCache, jsonEncode(config.toJson()));
    prefs.setString(AppConstants.prefTaxConfigVersion, config.version);
    prefs.setString(AppConstants.prefTaxConfigHash, config.hash);
  }

  void ensureSelectedFy(TaxConfig config) {
    final current = prefs.getString(AppConstants.prefTaxSelectedFy);
    final validIds = config.supportedFy.map((e) => e.id).toSet();
    String resolveDefault() {
      if (validIds.contains(config.defaultFy)) return config.defaultFy;
      final nowStart = _currentFyStartYearIst();
      String? nearestId;
      var bestDistance = 1 << 30;
      var bestStartYear = -1;
      final fyPattern = RegExp(r'^FY(\d{4})-\d{2}$');
      for (final fy in config.supportedFy) {
        final match = fyPattern.firstMatch(fy.id.trim());
        if (match == null) continue;
        final startYear = int.tryParse(match.group(1) ?? '');
        if (startYear == null) continue;
        final distance = (startYear - nowStart).abs();
        final isBetter = distance < bestDistance ||
            (distance == bestDistance && startYear > bestStartYear);
        if (isBetter) {
          bestDistance = distance;
          bestStartYear = startYear;
          nearestId = fy.id;
        }
      }
      return nearestId ??
          (config.supportedFy.isNotEmpty
              ? config.supportedFy.first.id
              : config.defaultFy);
    }

    if (current == null || !validIds.contains(current)) {
      final resolved = resolveDefault();
      prefs.setString(AppConstants.prefTaxSelectedFy, resolved);
      ref.read(selectedTaxFyProvider.notifier).set(resolved);
    }
  }

  if (await isOffline()) {
    final cached = cachedConfig();
    if (cached != null) {
      ensureSelectedFy(cached);
      return TaxConfigState(config: cached, source: TaxConfigSource.cached);
    }
    throw StateError('Tax rules unavailable offline. Open once with internet.');
  }

  try {
    final live = await ds.getTaxConfig().timeout(const Duration(seconds: 8));
    persistConfig(live);
    ensureSelectedFy(live);
    return TaxConfigState(config: live, source: TaxConfigSource.live);
  } catch (_) {
    final cached = cachedConfig();
    if (cached != null) {
      ensureSelectedFy(cached);
      return TaxConfigState(config: cached, source: TaxConfigSource.cached);
    }
    throw StateError('Unable to load tax rules. Check connection and retry.');
  }
});

final selectedTaxFyProvider =
    StateNotifierProvider<SelectedTaxFyNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SelectedTaxFyNotifier(prefs);
});

class SelectedTaxFyNotifier extends StateNotifier<String> {
  SelectedTaxFyNotifier(this._prefs)
      : super(_prefs.getString(AppConstants.prefTaxSelectedFy) ?? '');

  final SharedPreferences _prefs;

  void set(String fy) {
    final normalized = fy.trim();
    if (normalized.isEmpty) return;
    state = normalized;
    _prefs.setString(AppConstants.prefTaxSelectedFy, normalized);
  }
}

final activeTaxRuleSetProvider = Provider<TaxRuleSet?>((ref) {
  final configState = ref.watch(taxConfigProvider).valueOrNull;
  if (configState == null) return null;
  final selectedFy = ref.watch(selectedTaxFyProvider);
  return configState.config.ruleSetFor(selectedFy);
});
