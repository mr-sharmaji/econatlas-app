import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/discover.dart';
import '../../domain/repositories/discover_repository.dart';
import 'repository_providers.dart';

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
  quality,
  dividend,
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
      case DiscoverStockPreset.quality:
        return 'quality';
      case DiscoverStockPreset.dividend:
        return 'dividend';
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
      case DiscoverStockPreset.quality:
        return 'Quality';
      case DiscoverStockPreset.dividend:
        return 'Dividend';
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
      case 'quality':
        return DiscoverStockPreset.quality;
      case 'dividend':
        return DiscoverStockPreset.dividend;
      case 'momentum':
      default:
        return DiscoverStockPreset.momentum;
    }
  }
}

enum DiscoverMutualFundPreset {
  // Segments
  all,
  equity,
  debt,
  hybrid,
  // Equity sub-categories
  largeCap,
  midCap,
  smallCap,
  flexiCap,
  multiCap,
  elss,
  valueMf,
  focused,
  sectoral,
  indexFund,
  // Debt sub-categories
  shortDuration,
  corporateBond,
  bankingPsu,
  gilt,
  liquid,
  overnight,
  dynamicBond,
  moneyMarket,
  // Hybrid sub-categories
  aggressiveHybrid,
  balancedHybrid,
  conservativeHybrid,
  // Legacy
  lowRisk,
}

extension DiscoverMutualFundPresetX on DiscoverMutualFundPreset {
  String get apiValue {
    switch (this) {
      case DiscoverMutualFundPreset.all:
        return 'all';
      case DiscoverMutualFundPreset.equity:
        return 'equity';
      case DiscoverMutualFundPreset.debt:
        return 'debt';
      case DiscoverMutualFundPreset.hybrid:
        return 'hybrid';
      case DiscoverMutualFundPreset.largeCap:
        return 'large-cap';
      case DiscoverMutualFundPreset.midCap:
        return 'mid-cap';
      case DiscoverMutualFundPreset.smallCap:
        return 'small-cap';
      case DiscoverMutualFundPreset.flexiCap:
        return 'flexi-cap';
      case DiscoverMutualFundPreset.multiCap:
        return 'multi-cap';
      case DiscoverMutualFundPreset.elss:
        return 'elss';
      case DiscoverMutualFundPreset.valueMf:
        return 'value-mf';
      case DiscoverMutualFundPreset.focused:
        return 'focused';
      case DiscoverMutualFundPreset.sectoral:
        return 'sectoral';
      case DiscoverMutualFundPreset.indexFund:
        return 'index';
      case DiscoverMutualFundPreset.shortDuration:
        return 'short-duration';
      case DiscoverMutualFundPreset.corporateBond:
        return 'corporate-bond';
      case DiscoverMutualFundPreset.bankingPsu:
        return 'banking-psu';
      case DiscoverMutualFundPreset.gilt:
        return 'gilt';
      case DiscoverMutualFundPreset.liquid:
        return 'liquid';
      case DiscoverMutualFundPreset.overnight:
        return 'overnight';
      case DiscoverMutualFundPreset.dynamicBond:
        return 'dynamic-bond';
      case DiscoverMutualFundPreset.moneyMarket:
        return 'money-market';
      case DiscoverMutualFundPreset.aggressiveHybrid:
        return 'aggressive-hybrid';
      case DiscoverMutualFundPreset.balancedHybrid:
        return 'balanced-hybrid';
      case DiscoverMutualFundPreset.conservativeHybrid:
        return 'conservative-hybrid';
      case DiscoverMutualFundPreset.lowRisk:
        return 'low-risk';
    }
  }

  String get label {
    switch (this) {
      case DiscoverMutualFundPreset.all:
        return 'All';
      case DiscoverMutualFundPreset.equity:
        return 'Equity';
      case DiscoverMutualFundPreset.debt:
        return 'Debt';
      case DiscoverMutualFundPreset.hybrid:
        return 'Hybrid';
      case DiscoverMutualFundPreset.largeCap:
        return 'Large Cap';
      case DiscoverMutualFundPreset.midCap:
        return 'Mid Cap';
      case DiscoverMutualFundPreset.smallCap:
        return 'Small Cap';
      case DiscoverMutualFundPreset.flexiCap:
        return 'Flexi Cap';
      case DiscoverMutualFundPreset.multiCap:
        return 'Multi Cap';
      case DiscoverMutualFundPreset.elss:
        return 'ELSS';
      case DiscoverMutualFundPreset.valueMf:
        return 'Value';
      case DiscoverMutualFundPreset.focused:
        return 'Focused';
      case DiscoverMutualFundPreset.sectoral:
        return 'Sectoral & Thematic';
      case DiscoverMutualFundPreset.indexFund:
        return 'Index';
      case DiscoverMutualFundPreset.shortDuration:
        return 'Short Duration';
      case DiscoverMutualFundPreset.corporateBond:
        return 'Corporate Bond';
      case DiscoverMutualFundPreset.bankingPsu:
        return 'Banking & PSU';
      case DiscoverMutualFundPreset.gilt:
        return 'Gilt';
      case DiscoverMutualFundPreset.liquid:
        return 'Liquid';
      case DiscoverMutualFundPreset.overnight:
        return 'Overnight';
      case DiscoverMutualFundPreset.dynamicBond:
        return 'Dynamic Bond';
      case DiscoverMutualFundPreset.moneyMarket:
        return 'Money Market';
      case DiscoverMutualFundPreset.aggressiveHybrid:
        return 'Aggressive Hybrid';
      case DiscoverMutualFundPreset.balancedHybrid:
        return 'Balanced Hybrid';
      case DiscoverMutualFundPreset.conservativeHybrid:
        return 'Conservative Hybrid';
      case DiscoverMutualFundPreset.lowRisk:
        return 'Low Risk';
    }
  }

  static List<DiscoverMutualFundPreset> get segments => [
        DiscoverMutualFundPreset.all,
        DiscoverMutualFundPreset.equity,
        DiscoverMutualFundPreset.debt,
        DiscoverMutualFundPreset.hybrid,
      ];

  static List<DiscoverMutualFundPreset> get equitySubCategories => [
        DiscoverMutualFundPreset.largeCap,
        DiscoverMutualFundPreset.midCap,
        DiscoverMutualFundPreset.smallCap,
        DiscoverMutualFundPreset.flexiCap,
        DiscoverMutualFundPreset.multiCap,
        DiscoverMutualFundPreset.elss,
        DiscoverMutualFundPreset.valueMf,
        DiscoverMutualFundPreset.focused,
        DiscoverMutualFundPreset.sectoral,
        DiscoverMutualFundPreset.indexFund,
      ];

  static List<DiscoverMutualFundPreset> get debtSubCategories => [
        DiscoverMutualFundPreset.shortDuration,
        DiscoverMutualFundPreset.corporateBond,
        DiscoverMutualFundPreset.bankingPsu,
        DiscoverMutualFundPreset.gilt,
        DiscoverMutualFundPreset.liquid,
        DiscoverMutualFundPreset.overnight,
        DiscoverMutualFundPreset.dynamicBond,
        DiscoverMutualFundPreset.moneyMarket,
      ];

  static List<DiscoverMutualFundPreset> get hybridSubCategories => [
        DiscoverMutualFundPreset.aggressiveHybrid,
        DiscoverMutualFundPreset.balancedHybrid,
        DiscoverMutualFundPreset.conservativeHybrid,
      ];

  static DiscoverMutualFundPreset fromApi(String? value) {
    switch (value) {
      case 'equity':
        return DiscoverMutualFundPreset.equity;
      case 'debt':
        return DiscoverMutualFundPreset.debt;
      case 'hybrid':
        return DiscoverMutualFundPreset.hybrid;
      case 'large-cap':
        return DiscoverMutualFundPreset.largeCap;
      case 'mid-cap':
        return DiscoverMutualFundPreset.midCap;
      case 'small-cap':
        return DiscoverMutualFundPreset.smallCap;
      case 'flexi-cap':
        return DiscoverMutualFundPreset.flexiCap;
      case 'multi-cap':
        return DiscoverMutualFundPreset.multiCap;
      case 'elss':
        return DiscoverMutualFundPreset.elss;
      case 'value-mf':
        return DiscoverMutualFundPreset.valueMf;
      case 'focused':
        return DiscoverMutualFundPreset.focused;
      case 'sectoral':
        return DiscoverMutualFundPreset.sectoral;
      case 'index':
        return DiscoverMutualFundPreset.indexFund;
      case 'short-duration':
        return DiscoverMutualFundPreset.shortDuration;
      case 'corporate-bond':
        return DiscoverMutualFundPreset.corporateBond;
      case 'banking-psu':
        return DiscoverMutualFundPreset.bankingPsu;
      case 'gilt':
        return DiscoverMutualFundPreset.gilt;
      case 'liquid':
        return DiscoverMutualFundPreset.liquid;
      case 'overnight':
        return DiscoverMutualFundPreset.overnight;
      case 'dynamic-bond':
        return DiscoverMutualFundPreset.dynamicBond;
      case 'money-market':
        return DiscoverMutualFundPreset.moneyMarket;
      case 'aggressive-hybrid':
        return DiscoverMutualFundPreset.aggressiveHybrid;
      case 'balanced-hybrid':
        return DiscoverMutualFundPreset.balancedHybrid;
      case 'conservative-hybrid':
        return DiscoverMutualFundPreset.conservativeHybrid;
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
  final double? minMarketCap;
  final double? maxMarketCap;
  final double? minDividendYield;
  final double? minPb;
  final double? maxPb;
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
    this.minMarketCap,
    this.maxMarketCap,
    this.minDividendYield,
    this.minPb,
    this.maxPb,
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
    double? minMarketCap,
    double? maxMarketCap,
    double? minDividendYield,
    double? minPb,
    double? maxPb,
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
      minMarketCap: minMarketCap ?? this.minMarketCap,
      maxMarketCap: maxMarketCap ?? this.maxMarketCap,
      minDividendYield: minDividendYield ?? this.minDividendYield,
      minPb: minPb ?? this.minPb,
      maxPb: maxPb ?? this.maxPb,
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
        'minMarketCap': minMarketCap,
        'maxMarketCap': maxMarketCap,
        'minDividendYield': minDividendYield,
        'minPb': minPb,
        'maxPb': maxPb,
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
      minMarketCap: (json['minMarketCap'] as num?)?.toDouble(),
      maxMarketCap: (json['maxMarketCap'] as num?)?.toDouble(),
      minDividendYield: (json['minDividendYield'] as num?)?.toDouble(),
      minPb: (json['minPb'] as num?)?.toDouble(),
      maxPb: (json['maxPb'] as num?)?.toDouble(),
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
  final double? minReturn1y;
  final double? minReturn3y;
  final double? minReturn5y;
  final double? minFundAge;
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
    this.minReturn1y,
    this.minReturn3y,
    this.minReturn5y,
    this.minFundAge,
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
    double? minReturn1y,
    double? minReturn3y,
    double? minReturn5y,
    double? minFundAge,
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
      minReturn1y: minReturn1y ?? this.minReturn1y,
      minReturn3y: minReturn3y ?? this.minReturn3y,
      minReturn5y: minReturn5y ?? this.minReturn5y,
      minFundAge: minFundAge ?? this.minFundAge,
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
        'minReturn1y': minReturn1y,
        'minReturn3y': minReturn3y,
        'minReturn5y': minReturn5y,
        'minFundAge': minFundAge,
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
      minReturn1y: (json['minReturn1y'] as num?)?.toDouble(),
      minReturn3y: (json['minReturn3y'] as num?)?.toDouble(),
      minReturn5y: (json['minReturn5y'] as num?)?.toDouble(),
      minFundAge: (json['minFundAge'] as num?)?.toDouble(),
      sourceStatus: json['sourceStatus'] as String? ?? 'all',
      sortBy: json['sortBy'] as String? ?? 'score',
      sortOrder: json['sortOrder'] as String? ?? 'desc',
    );
  }
}

class _DiscoverSegmentNotifier extends StateNotifier<DiscoverSegment> {
  _DiscoverSegmentNotifier() : super(DiscoverSegment.stocks);

  void setSegment(DiscoverSegment segment) {
    state = segment;
  }
}

class _DiscoverStockPresetNotifier extends StateNotifier<DiscoverStockPreset> {
  _DiscoverStockPresetNotifier() : super(DiscoverStockPreset.momentum);

  void setPreset(DiscoverStockPreset preset) {
    state = preset;
  }
}

class _DiscoverMutualFundPresetNotifier
    extends StateNotifier<DiscoverMutualFundPreset> {
  _DiscoverMutualFundPresetNotifier() : super(DiscoverMutualFundPreset.all);

  void setPreset(DiscoverMutualFundPreset preset) {
    state = preset;
  }
}

class _DiscoverStockFiltersNotifier extends StateNotifier<DiscoverStockFilters> {
  _DiscoverStockFiltersNotifier() : super(const DiscoverStockFilters());

  void setFilters(DiscoverStockFilters next) {
    state = next;
  }
}

class _DiscoverMutualFundFiltersNotifier
    extends StateNotifier<DiscoverMutualFundFilters> {
  _DiscoverMutualFundFiltersNotifier() : super(const DiscoverMutualFundFilters());

  void setFilters(DiscoverMutualFundFilters next) {
    state = next;
  }
}

final discoverSegmentProvider =
    StateNotifierProvider<_DiscoverSegmentNotifier, DiscoverSegment>((ref) {
  return _DiscoverSegmentNotifier();
});

// autoDispose: filters/presets reset to defaults when screener screen is disposed
final discoverStockPresetProvider =
    StateNotifierProvider.autoDispose<_DiscoverStockPresetNotifier, DiscoverStockPreset>(
        (ref) {
  return _DiscoverStockPresetNotifier();
});

final discoverMutualFundPresetProvider = StateNotifierProvider.autoDispose<
    _DiscoverMutualFundPresetNotifier, DiscoverMutualFundPreset>((ref) {
  return _DiscoverMutualFundPresetNotifier();
});

final discoverStockFiltersProvider =
    StateNotifierProvider.autoDispose<_DiscoverStockFiltersNotifier, DiscoverStockFilters>(
        (ref) {
  return _DiscoverStockFiltersNotifier();
});

final discoverMutualFundFiltersProvider = StateNotifierProvider.autoDispose<
    _DiscoverMutualFundFiltersNotifier, DiscoverMutualFundFilters>((ref) {
  return _DiscoverMutualFundFiltersNotifier();
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

// Paginated state for stock/MF lists
@immutable
class PaginatedListState<T> {
  final List<T> items;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const PaginatedListState({
    this.items = const [],
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  PaginatedListState<T> copyWith({
    List<T>? items,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PaginatedListState<T>(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final discoverStocksProvider = AsyncNotifierProvider.autoDispose<
    DiscoverStockListNotifier,
    PaginatedListState<DiscoverStockItem>>(() => DiscoverStockListNotifier());

class DiscoverStockListNotifier
    extends AutoDisposeAsyncNotifier<PaginatedListState<DiscoverStockItem>> {
  static const _pageSize = 25;

  @override
  Future<PaginatedListState<DiscoverStockItem>> build() async {
    final preset = ref.watch(discoverStockPresetProvider);
    final filters = ref.watch(discoverStockFiltersProvider);
    final response = await _fetch(offset: 0, preset: preset, filters: filters);
    final total = response.totalCount ?? response.items.length;
    return PaginatedListState<DiscoverStockItem>(
      items: response.items,
      totalCount: total,
      hasMore: response.items.length < total,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final preset = ref.read(discoverStockPresetProvider);
      final filters = ref.read(discoverStockFiltersProvider);
      final response =
          await _fetch(offset: current.items.length, preset: preset, filters: filters);
      final newItems = [...current.items, ...response.items];
      final total = response.totalCount ?? newItems.length;
      state = AsyncData(PaginatedListState<DiscoverStockItem>(
        items: newItems,
        totalCount: total,
        hasMore: newItems.length < total,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<DiscoverStockListResponse> _fetch({
    required int offset,
    required DiscoverStockPreset preset,
    required DiscoverStockFilters filters,
  }) {
    return ref.read(discoverRepoProvider).getStocks(
          preset: preset.apiValue,
          search: filters.search.isEmpty ? null : filters.search,
          sector: filters.sector == 'All' ? null : filters.sector,
          minScore: filters.minScore > 0 ? filters.minScore : null,
          minPrice: filters.minPrice,
          maxPrice: filters.maxPrice,
          minPe: filters.minPe,
          maxPe: filters.maxPe,
          minRoe: filters.minRoe,
          minRoce: filters.minRoce,
          maxDebtToEquity: filters.maxDebtToEquity,
          minVolume: filters.minVolume,
          minTradedValue: filters.minTradedValue,
          minMarketCap: filters.minMarketCap,
          maxMarketCap: filters.maxMarketCap,
          minDividendYield: filters.minDividendYield,
          minPb: filters.minPb,
          maxPb: filters.maxPb,
          sourceStatus:
              filters.sourceStatus == 'all' ? null : filters.sourceStatus,
          sortBy: filters.sortBy,
          sortOrder: filters.sortOrder,
          limit: _pageSize,
          offset: offset,
        );
  }
}

final discoverMutualFundsProvider = AsyncNotifierProvider.autoDispose<
    DiscoverMfListNotifier,
    PaginatedListState<DiscoverMutualFundItem>>(() => DiscoverMfListNotifier());

class DiscoverMfListNotifier
    extends AutoDisposeAsyncNotifier<PaginatedListState<DiscoverMutualFundItem>> {
  static const _pageSize = 25;

  @override
  Future<PaginatedListState<DiscoverMutualFundItem>> build() async {
    final preset = ref.watch(discoverMutualFundPresetProvider);
    final filters = ref.watch(discoverMutualFundFiltersProvider);
    final response = await _fetch(offset: 0, preset: preset, filters: filters);
    final total = response.totalCount ?? response.items.length;
    return PaginatedListState<DiscoverMutualFundItem>(
      items: response.items,
      totalCount: total,
      hasMore: response.items.length < total,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final preset = ref.read(discoverMutualFundPresetProvider);
      final filters = ref.read(discoverMutualFundFiltersProvider);
      final response =
          await _fetch(offset: current.items.length, preset: preset, filters: filters);
      final newItems = [...current.items, ...response.items];
      final total = response.totalCount ?? newItems.length;
      state = AsyncData(PaginatedListState<DiscoverMutualFundItem>(
        items: newItems,
        totalCount: total,
        hasMore: newItems.length < total,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<DiscoverMutualFundListResponse> _fetch({
    required int offset,
    required DiscoverMutualFundPreset preset,
    required DiscoverMutualFundFilters filters,
  }) {
    return ref.read(discoverRepoProvider).getMutualFunds(
          preset: preset.apiValue,
          search: filters.search.isEmpty ? null : filters.search,
          category: filters.category == 'All' ? null : filters.category,
          riskLevel: filters.riskLevel == 'All' ? null : filters.riskLevel,
          directOnly: filters.directOnly,
          minScore: filters.minScore > 0 ? filters.minScore : null,
          minAumCr: filters.minAumCr,
          maxExpenseRatio: filters.maxExpenseRatio,
          minReturn1y: filters.minReturn1y,
          minReturn3y: filters.minReturn3y,
          minReturn5y: filters.minReturn5y,
          minFundAge: filters.minFundAge,
          sourceStatus:
              filters.sourceStatus == 'all' ? null : filters.sourceStatus,
          sortBy: filters.sortBy,
          sortOrder: filters.sortOrder,
          limit: _pageSize,
          offset: offset,
        );
  }
}

final discoverHomeDataProvider =
    FutureProvider.autoDispose<DiscoverHomeData>((ref) {
  return ref.watch(discoverRepoProvider).getHomeData();
});

/// Top 20 stocks sorted by score (for the Discover home tab).
final homeTopStocksProvider =
    FutureProvider.autoDispose<DiscoverStockListResponse>((ref) {
  return ref.watch(discoverRepoProvider).getStocks(
        preset: 'quality',
        sortBy: 'score',
        sortOrder: 'desc',
        limit: 20,
        offset: 0,
      );
});

/// Top 20 mutual funds sorted by score (for the Discover home tab).
final homeTopMutualFundsProvider =
    FutureProvider.autoDispose<DiscoverMutualFundListResponse>((ref) {
  return ref.watch(discoverRepoProvider).getMutualFunds(
        preset: 'all',
        directOnly: true,
        sortBy: 'score',
        sortOrder: 'desc',
        limit: 20,
        offset: 0,
      );
});

final discoverSearchProvider =
    FutureProvider.autoDispose.family<UnifiedSearchResponse, String>(
        (ref, query) {
  if (query.trim().length < 2) {
    return const UnifiedSearchResponse(stocks: [], mutualFunds: []);
  }
  return ref.watch(discoverRepoProvider).search(query: query, limit: 10);
});

final discoverStockHistoryProvider = FutureProvider.autoDispose
    .family<PriceHistoryResponse, ({String symbol, int days})>(
        (ref, params) {
  return ref
      .watch(discoverRepoProvider)
      .getStockHistory(symbol: params.symbol, days: params.days);
});

final discoverMfHistoryProvider = FutureProvider.autoDispose
    .family<PriceHistoryResponse, ({String schemeCode, int days})>(
        (ref, params) {
  return ref
      .watch(discoverRepoProvider)
      .getMfNavHistory(schemeCode: params.schemeCode, days: params.days);
});

final discoverStockDetailProvider =
    FutureProvider.autoDispose.family<DiscoverStockItem, String>((ref, symbol) {
  return ref.watch(discoverRepoProvider).getStockBySymbol(symbol: symbol);
});

final discoverMfDetailProvider =
    FutureProvider.autoDispose.family<DiscoverMutualFundItem, String>((ref, schemeCode) {
  return ref.watch(discoverRepoProvider).getMfBySchemeCode(schemeCode: schemeCode);
});

final discoverStockPeersProvider = FutureProvider.autoDispose
    .family<List<DiscoverStockItem>, String>((ref, symbol) {
  return ref.watch(discoverRepoProvider).getStockPeers(symbol: symbol, limit: 5);
});

final discoverMfPeersProvider = FutureProvider.autoDispose
    .family<List<DiscoverMutualFundItem>, String>((ref, schemeCode) {
  return ref.watch(discoverRepoProvider).getMfPeers(schemeCode: schemeCode, limit: 5);
});
