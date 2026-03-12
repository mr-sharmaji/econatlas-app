import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../data/models/discover.dart';
import '../../domain/repositories/discover_repository.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

enum DiscoverSegment { stocks, mutualFunds }

extension DiscoverSegmentX on DiscoverSegment {
  String get apiValue {
    switch (this) {
      case DiscoverSegment.stocks:
        return 'stocks';
      case DiscoverSegment.mutualFunds:
        return 'mutual_funds';
    }
  }

  String get label {
    switch (this) {
      case DiscoverSegment.stocks:
        return 'Stocks';
      case DiscoverSegment.mutualFunds:
        return 'Mutual Funds';
    }
  }

  static DiscoverSegment fromApi(String? value) {
    if (value == 'mutual_funds') return DiscoverSegment.mutualFunds;
    return DiscoverSegment.stocks;
  }
}

enum DiscoverStockPreset {
  momentum,
  value,
  lowVolatility,
  highVolume,
  breakout,
}

extension DiscoverStockPresetX on DiscoverStockPreset {
  String get apiValue {
    switch (this) {
      case DiscoverStockPreset.momentum:
        return 'momentum';
      case DiscoverStockPreset.value:
        return 'value';
      case DiscoverStockPreset.lowVolatility:
        return 'low-volatility';
      case DiscoverStockPreset.highVolume:
        return 'high-volume';
      case DiscoverStockPreset.breakout:
        return 'breakout';
    }
  }

  String get label {
    switch (this) {
      case DiscoverStockPreset.momentum:
        return 'Momentum';
      case DiscoverStockPreset.value:
        return 'Value';
      case DiscoverStockPreset.lowVolatility:
        return 'Low Volatility';
      case DiscoverStockPreset.highVolume:
        return 'High Volume';
      case DiscoverStockPreset.breakout:
        return 'Breakout';
    }
  }

  static DiscoverStockPreset fromApi(String? value) {
    switch (value) {
      case 'value':
        return DiscoverStockPreset.value;
      case 'low-volatility':
        return DiscoverStockPreset.lowVolatility;
      case 'high-volume':
        return DiscoverStockPreset.highVolume;
      case 'breakout':
        return DiscoverStockPreset.breakout;
      case 'momentum':
      default:
        return DiscoverStockPreset.momentum;
    }
  }
}

enum DiscoverMutualFundPreset {
  all,
  largeCap,
  flexiCap,
  indexFund,
  lowRisk,
}

extension DiscoverMutualFundPresetX on DiscoverMutualFundPreset {
  String get apiValue {
    switch (this) {
      case DiscoverMutualFundPreset.all:
        return 'all';
      case DiscoverMutualFundPreset.largeCap:
        return 'large-cap';
      case DiscoverMutualFundPreset.flexiCap:
        return 'flexi-cap';
      case DiscoverMutualFundPreset.indexFund:
        return 'index';
      case DiscoverMutualFundPreset.lowRisk:
        return 'low-risk';
    }
  }

  String get label {
    switch (this) {
      case DiscoverMutualFundPreset.all:
        return 'All';
      case DiscoverMutualFundPreset.largeCap:
        return 'Large Cap';
      case DiscoverMutualFundPreset.flexiCap:
        return 'Flexi Cap';
      case DiscoverMutualFundPreset.indexFund:
        return 'Index';
      case DiscoverMutualFundPreset.lowRisk:
        return 'Low Risk';
    }
  }

  static DiscoverMutualFundPreset fromApi(String? value) {
    switch (value) {
      case 'large-cap':
        return DiscoverMutualFundPreset.largeCap;
      case 'flexi-cap':
        return DiscoverMutualFundPreset.flexiCap;
      case 'index':
        return DiscoverMutualFundPreset.indexFund;
      case 'low-risk':
        return DiscoverMutualFundPreset.lowRisk;
      case 'all':
      default:
        return DiscoverMutualFundPreset.all;
    }
  }
}

class DiscoverStockFilters {
  final String search;
  final String sector;
  final double minScore;
  final double? minPrice;
  final double? maxPrice;
  final double? minPe;
  final double? maxPe;
  final double? minRoe;
  final double? minRoce;
  final double? maxDebtToEquity;
  final int? minVolume;
  final double? minTradedValue;
  final String sourceStatus;
  final String sortBy;
  final String sortOrder;

  const DiscoverStockFilters({
    this.search = '',
    this.sector = 'All',
    this.minScore = 40,
    this.minPrice,
    this.maxPrice,
    this.minPe,
    this.maxPe,
    this.minRoe,
    this.minRoce,
    this.maxDebtToEquity,
    this.minVolume,
    this.minTradedValue,
    this.sourceStatus = 'all',
    this.sortBy = 'score',
    this.sortOrder = 'desc',
  });

  DiscoverStockFilters copyWith({
    String? search,
    String? sector,
    double? minScore,
    double? minPrice,
    double? maxPrice,
    double? minPe,
    double? maxPe,
    double? minRoe,
    double? minRoce,
    double? maxDebtToEquity,
    int? minVolume,
    double? minTradedValue,
    String? sourceStatus,
    String? sortBy,
    String? sortOrder,
  }) {
    return DiscoverStockFilters(
      search: search ?? this.search,
      sector: sector ?? this.sector,
      minScore: minScore ?? this.minScore,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minPe: minPe ?? this.minPe,
      maxPe: maxPe ?? this.maxPe,
      minRoe: minRoe ?? this.minRoe,
      minRoce: minRoce ?? this.minRoce,
      maxDebtToEquity: maxDebtToEquity ?? this.maxDebtToEquity,
      minVolume: minVolume ?? this.minVolume,
      minTradedValue: minTradedValue ?? this.minTradedValue,
      sourceStatus: sourceStatus ?? this.sourceStatus,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'search': search,
        'sector': sector,
        'minScore': minScore,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'minPe': minPe,
        'maxPe': maxPe,
        'minRoe': minRoe,
        'minRoce': minRoce,
        'maxDebtToEquity': maxDebtToEquity,
        'minVolume': minVolume,
        'minTradedValue': minTradedValue,
        'sourceStatus': sourceStatus,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };

  factory DiscoverStockFilters.fromJson(Map<String, dynamic> json) {
    return DiscoverStockFilters(
      search: json['search'] as String? ?? '',
      sector: json['sector'] as String? ?? 'All',
      minScore: (json['minScore'] as num?)?.toDouble() ?? 40,
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      minPe: (json['minPe'] as num?)?.toDouble(),
      maxPe: (json['maxPe'] as num?)?.toDouble(),
      minRoe: (json['minRoe'] as num?)?.toDouble(),
      minRoce: (json['minRoce'] as num?)?.toDouble(),
      maxDebtToEquity: (json['maxDebtToEquity'] as num?)?.toDouble(),
      minVolume: (json['minVolume'] as num?)?.toInt(),
      minTradedValue: (json['minTradedValue'] as num?)?.toDouble(),
      sourceStatus: json['sourceStatus'] as String? ?? 'all',
      sortBy: json['sortBy'] as String? ?? 'score',
      sortOrder: json['sortOrder'] as String? ?? 'desc',
    );
  }
}

class DiscoverMutualFundFilters {
  final String search;
  final String category;
  final String riskLevel;
  final bool directOnly;
  final double minScore;
  final double? minAumCr;
  final double? maxExpenseRatio;
  final double? minReturn3y;
  final String sourceStatus;
  final String sortBy;
  final String sortOrder;

  const DiscoverMutualFundFilters({
    this.search = '',
    this.category = 'All',
    this.riskLevel = 'All',
    this.directOnly = true,
    this.minScore = 40,
    this.minAumCr,
    this.maxExpenseRatio,
    this.minReturn3y,
    this.sourceStatus = 'all',
    this.sortBy = 'score',
    this.sortOrder = 'desc',
  });

  DiscoverMutualFundFilters copyWith({
    String? search,
    String? category,
    String? riskLevel,
    bool? directOnly,
    double? minScore,
    double? minAumCr,
    double? maxExpenseRatio,
    double? minReturn3y,
    String? sourceStatus,
    String? sortBy,
    String? sortOrder,
  }) {
    return DiscoverMutualFundFilters(
      search: search ?? this.search,
      category: category ?? this.category,
      riskLevel: riskLevel ?? this.riskLevel,
      directOnly: directOnly ?? this.directOnly,
      minScore: minScore ?? this.minScore,
      minAumCr: minAumCr ?? this.minAumCr,
      maxExpenseRatio: maxExpenseRatio ?? this.maxExpenseRatio,
      minReturn3y: minReturn3y ?? this.minReturn3y,
      sourceStatus: sourceStatus ?? this.sourceStatus,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'search': search,
        'category': category,
        'riskLevel': riskLevel,
        'directOnly': directOnly,
        'minScore': minScore,
        'minAumCr': minAumCr,
        'maxExpenseRatio': maxExpenseRatio,
        'minReturn3y': minReturn3y,
        'sourceStatus': sourceStatus,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };

  factory DiscoverMutualFundFilters.fromJson(Map<String, dynamic> json) {
    return DiscoverMutualFundFilters(
      search: json['search'] as String? ?? '',
      category: json['category'] as String? ?? 'All',
      riskLevel: json['riskLevel'] as String? ?? 'All',
      directOnly: json['directOnly'] as bool? ?? true,
      minScore: (json['minScore'] as num?)?.toDouble() ?? 40,
      minAumCr: (json['minAumCr'] as num?)?.toDouble(),
      maxExpenseRatio: (json['maxExpenseRatio'] as num?)?.toDouble(),
      minReturn3y: (json['minReturn3y'] as num?)?.toDouble(),
      sourceStatus: json['sourceStatus'] as String? ?? 'all',
      sortBy: json['sortBy'] as String? ?? 'score',
      sortOrder: json['sortOrder'] as String? ?? 'desc',
    );
  }
}

class _DiscoverSegmentNotifier extends StateNotifier<DiscoverSegment> {
  _DiscoverSegmentNotifier(this._prefs)
      : super(
          DiscoverSegmentX.fromApi(
            _prefs.getString(AppConstants.prefDiscoverSegment),
          ),
        );

  final SharedPreferences _prefs;

  void setSegment(DiscoverSegment segment) {
    state = segment;
    _prefs.setString(AppConstants.prefDiscoverSegment, segment.apiValue);
  }
}

class _DiscoverStockPresetNotifier extends StateNotifier<DiscoverStockPreset> {
  _DiscoverStockPresetNotifier(this._prefs)
      : super(
          DiscoverStockPresetX.fromApi(
            _prefs.getString(AppConstants.prefDiscoverStockPreset),
          ),
        );

  final SharedPreferences _prefs;

  void setPreset(DiscoverStockPreset preset) {
    state = preset;
    _prefs.setString(AppConstants.prefDiscoverStockPreset, preset.apiValue);
  }
}

class _DiscoverMutualFundPresetNotifier
    extends StateNotifier<DiscoverMutualFundPreset> {
  _DiscoverMutualFundPresetNotifier(this._prefs)
      : super(
          DiscoverMutualFundPresetX.fromApi(
            _prefs.getString(AppConstants.prefDiscoverMutualFundPreset),
          ),
        );

  final SharedPreferences _prefs;

  void setPreset(DiscoverMutualFundPreset preset) {
    state = preset;
    _prefs.setString(AppConstants.prefDiscoverMutualFundPreset, preset.apiValue);
  }
}

class _DiscoverStockFiltersNotifier extends StateNotifier<DiscoverStockFilters> {
  _DiscoverStockFiltersNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static DiscoverStockFilters _load(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.prefDiscoverStockFilters);
    if (raw == null || raw.trim().isEmpty) return const DiscoverStockFilters();
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return DiscoverStockFilters.fromJson(data);
    } catch (_) {
      return const DiscoverStockFilters();
    }
  }

  void setFilters(DiscoverStockFilters next) {
    state = next;
    _prefs.setString(AppConstants.prefDiscoverStockFilters, jsonEncode(next.toJson()));
  }
}

class _DiscoverMutualFundFiltersNotifier
    extends StateNotifier<DiscoverMutualFundFilters> {
  _DiscoverMutualFundFiltersNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static DiscoverMutualFundFilters _load(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.prefDiscoverMutualFundFilters);
    if (raw == null || raw.trim().isEmpty) {
      return const DiscoverMutualFundFilters();
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return DiscoverMutualFundFilters.fromJson(data);
    } catch (_) {
      return const DiscoverMutualFundFilters();
    }
  }

  void setFilters(DiscoverMutualFundFilters next) {
    state = next;
    _prefs.setString(
      AppConstants.prefDiscoverMutualFundFilters,
      jsonEncode(next.toJson()),
    );
  }
}

class _DiscoverCompareNotifier extends StateNotifier<List<String>> {
  _DiscoverCompareNotifier(this._prefs, this._key) : super(_load(_prefs, _key));

  final SharedPreferences _prefs;
  final String _key;

  static List<String> _load(SharedPreferences prefs, String key) {
    final raw = prefs.getStringList(key) ?? const <String>[];
    return raw.take(3).toList();
  }

  void toggle(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) return;
    final current = [...state];
    if (current.contains(normalized)) {
      current.remove(normalized);
    } else {
      if (current.length >= 3) current.removeAt(0);
      current.add(normalized);
    }
    state = current;
    _prefs.setStringList(_key, current);
  }

  void clear() {
    state = const [];
    _prefs.setStringList(_key, const []);
  }
}

final discoverSegmentProvider =
    StateNotifierProvider<_DiscoverSegmentNotifier, DiscoverSegment>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _DiscoverSegmentNotifier(prefs);
});

final discoverStockPresetProvider =
    StateNotifierProvider<_DiscoverStockPresetNotifier, DiscoverStockPreset>(
        (ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _DiscoverStockPresetNotifier(prefs);
});

final discoverMutualFundPresetProvider = StateNotifierProvider<
    _DiscoverMutualFundPresetNotifier, DiscoverMutualFundPreset>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _DiscoverMutualFundPresetNotifier(prefs);
});

final discoverStockFiltersProvider =
    StateNotifierProvider<_DiscoverStockFiltersNotifier, DiscoverStockFilters>(
        (ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _DiscoverStockFiltersNotifier(prefs);
});

final discoverMutualFundFiltersProvider = StateNotifierProvider<
    _DiscoverMutualFundFiltersNotifier, DiscoverMutualFundFilters>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _DiscoverMutualFundFiltersNotifier(prefs);
});

final discoverStockCompareProvider =
    StateNotifierProvider<_DiscoverCompareNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _DiscoverCompareNotifier(prefs, AppConstants.prefDiscoverStockCompare);
});

final discoverMutualFundCompareProvider =
    StateNotifierProvider<_DiscoverCompareNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _DiscoverCompareNotifier(
    prefs,
    AppConstants.prefDiscoverMutualFundCompare,
  );
});

final discoverRepoProvider = Provider<DiscoverRepository>((ref) {
  return ref.watch(discoverRepositoryProvider);
});

final discoverOverviewProvider =
    FutureProvider.autoDispose.family<DiscoverOverview, DiscoverSegment>(
        (ref, segment) {
  return ref
      .watch(discoverRepoProvider)
      .getOverview(segment: segment.apiValue);
});

final discoverStocksProvider =
    FutureProvider.autoDispose<DiscoverStockListResponse>((ref) {
  final preset = ref.watch(discoverStockPresetProvider);
  final filters = ref.watch(discoverStockFiltersProvider);
  return ref.watch(discoverRepoProvider).getStocks(
        preset: preset.apiValue,
        search: filters.search,
        sector: filters.sector == 'All' ? null : filters.sector,
        minScore: filters.minScore,
        minPrice: filters.minPrice,
        maxPrice: filters.maxPrice,
        minPe: filters.minPe,
        maxPe: filters.maxPe,
        minRoe: filters.minRoe,
        minRoce: filters.minRoce,
        maxDebtToEquity: filters.maxDebtToEquity,
        minVolume: filters.minVolume,
        minTradedValue: filters.minTradedValue,
        sourceStatus:
            filters.sourceStatus == 'all' ? null : filters.sourceStatus,
        sortBy: filters.sortBy,
        sortOrder: filters.sortOrder,
        limit: 40,
        offset: 0,
      );
});

final discoverMutualFundsProvider =
    FutureProvider.autoDispose<DiscoverMutualFundListResponse>((ref) {
  final preset = ref.watch(discoverMutualFundPresetProvider);
  final filters = ref.watch(discoverMutualFundFiltersProvider);
  return ref.watch(discoverRepoProvider).getMutualFunds(
        preset: preset.apiValue,
        search: filters.search,
        category: filters.category == 'All' ? null : filters.category,
        riskLevel: filters.riskLevel == 'All' ? null : filters.riskLevel,
        directOnly: filters.directOnly,
        minScore: filters.minScore,
        minAumCr: filters.minAumCr,
        maxExpenseRatio: filters.maxExpenseRatio,
        minReturn3y: filters.minReturn3y,
        sourceStatus:
            filters.sourceStatus == 'all' ? null : filters.sourceStatus,
        sortBy: filters.sortBy,
        sortOrder: filters.sortOrder,
        limit: 40,
        offset: 0,
      );
});

final discoverCompareProvider =
    FutureProvider.autoDispose.family<DiscoverCompareResponse, DiscoverSegment>(
        (ref, segment) async {
  final ids = segment == DiscoverSegment.stocks
      ? ref.watch(discoverStockCompareProvider)
      : ref.watch(discoverMutualFundCompareProvider);
  if (ids.isEmpty) {
    return DiscoverCompareResponse(
      segment: segment.apiValue,
      asOf: null,
      count: 0,
      sourceStatus: 'limited',
      stockItems: const [],
      mutualFundItems: const [],
    );
  }
  return ref
      .watch(discoverRepoProvider)
      .getCompare(segment: segment.apiValue, ids: ids);
});
