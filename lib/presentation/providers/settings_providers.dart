import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_loadThemeMode(_prefs));

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final value = prefs.getString(AppConstants.prefThemeMode);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _prefs.setString(AppConstants.prefThemeMode, mode.name);
  }
}

final baseUrlProvider = StateNotifierProvider<BaseUrlNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BaseUrlNotifier(prefs);
});

class BaseUrlNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;

  BaseUrlNotifier(this._prefs)
      : super(
          _prefs.getString(AppConstants.prefBaseUrl) ??
              AppConstants.defaultBaseUrl,
        );

  void setBaseUrl(String url) {
    state = url;
    _prefs.setString(AppConstants.prefBaseUrl, url);
  }
}

final developerOptionsUnlockedProvider =
    StateNotifierProvider<DeveloperOptionsUnlockedNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DeveloperOptionsUnlockedNotifier(prefs);
});

class DeveloperOptionsUnlockedNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  DeveloperOptionsUnlockedNotifier(this._prefs)
      : super(
            _prefs.getBool(AppConstants.prefDeveloperOptionsUnlocked) ?? false);

  void setUnlocked(bool unlocked) {
    state = unlocked;
    _prefs.setBool(AppConstants.prefDeveloperOptionsUnlocked, unlocked);
  }
}

// ---------------------------------------------------------------------------
// Expert Mode toggle (beginner vs advanced)
// ---------------------------------------------------------------------------

final expertModeProvider =
    StateNotifierProvider<ExpertModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ExpertModeNotifier(prefs);
});

class ExpertModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  ExpertModeNotifier(this._prefs)
      : super(_prefs.getBool(AppConstants.prefExpertMode) ?? false);

  void toggle() {
    state = !state;
    _prefs.setBool(AppConstants.prefExpertMode, state);
  }

  void set(bool value) {
    state = value;
    _prefs.setBool(AppConstants.prefExpertMode, value);
  }
}

enum UnitSystem { international, indian }

final unitSystemProvider =
    StateNotifierProvider<UnitSystemNotifier, UnitSystem>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UnitSystemNotifier(prefs);
});

class UnitSystemNotifier extends StateNotifier<UnitSystem> {
  final SharedPreferences _prefs;

  UnitSystemNotifier(this._prefs) : super(_load(_prefs));

  static UnitSystem _load(SharedPreferences prefs) {
    final value = prefs.getString(AppConstants.prefUnitSystem);
    return value == 'international'
        ? UnitSystem.international
        : UnitSystem.indian;
  }

  void set(UnitSystem system) {
    state = system;
    _prefs.setString(AppConstants.prefUnitSystem, system.name);
  }
}

final chartTimezoneProvider =
    StateNotifierProvider<ChartTimezoneNotifier, ChartTimezone>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ChartTimezoneNotifier(prefs);
});

class ChartTimezoneNotifier extends StateNotifier<ChartTimezone> {
  final SharedPreferences _prefs;

  ChartTimezoneNotifier(this._prefs) : super(_load(_prefs));

  static ChartTimezone _load(SharedPreferences prefs) {
    final value = prefs.getString(AppConstants.prefChartTimezone);
    return ChartTimezone.fromId(value);
  }

  void set(ChartTimezone tz) {
    state = tz;
    _prefs.setString(AppConstants.prefChartTimezone, tz.id);
  }
}

final deviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final existing = prefs.getString(AppConstants.prefDeviceId);
  if (existing != null && existing.trim().isNotEmpty) {
    return existing;
  }
  final rnd = Random();
  final id =
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}-${rnd.nextInt(1 << 32).toRadixString(16)}-${rnd.nextInt(1 << 32).toRadixString(16)}';
  prefs.setString(AppConstants.prefDeviceId, id);
  return id;
});

final converterFromCurrencyProvider =
    StateNotifierProvider<ConverterFromCurrencyNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ConverterFromCurrencyNotifier(prefs);
});

class ConverterFromCurrencyNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;

  ConverterFromCurrencyNotifier(this._prefs) : super(_load(_prefs));

  static String _load(SharedPreferences prefs) {
    final value = prefs.getString(AppConstants.prefConverterFrom);
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return 'USD';
  }

  void set(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return;
    state = normalized;
    _prefs.setString(AppConstants.prefConverterFrom, normalized);
  }
}

final converterToCurrencyProvider =
    StateNotifierProvider<ConverterToCurrencyNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ConverterToCurrencyNotifier(prefs);
});

class ConverterToCurrencyNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;

  ConverterToCurrencyNotifier(this._prefs) : super(_load(_prefs));

  static String _load(SharedPreferences prefs) {
    final value = prefs.getString(AppConstants.prefConverterTo);
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return 'INR';
  }

  void set(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return;
    state = normalized;
    _prefs.setString(AppConstants.prefConverterTo, normalized);
  }
}
