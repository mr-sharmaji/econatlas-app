import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/discover.dart';
import '../../data/services/recently_viewed_service.dart';
import '../../data/services/starred_stocks_service.dart';
import '../../domain/repositories/discover_repository.dart';
import 'dashboard_widget_providers.dart';
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
  all,
  momentum,
  value,
  lowVolatility,
  quality,
  dividend,
  largeCap,
  midCap,
  smallCap,
}

extension DiscoverStockPresetX on DiscoverStockPreset {
  String get apiValue {
    switch (this) {
      case DiscoverStockPreset.all:
        return 'all';
      case DiscoverStockPreset.momentum:
        return 'momentum';
      case DiscoverStockPreset.value:
        return 'value';
      case DiscoverStockPreset.lowVolatility:
        return 'low-volatility';
      case DiscoverStockPreset.quality:
        return 'quality';
      case DiscoverStockPreset.dividend:
        return 'dividend';
      case DiscoverStockPreset.largeCap:
        return 'large-cap';
      case DiscoverStockPreset.midCap:
        return 'mid-cap';
      case DiscoverStockPreset.smallCap:
        return 'small-cap';
    }
  }

  String get label {
    switch (this) {
      case DiscoverStockPreset.all:
        return 'All';
      case DiscoverStockPreset.momentum:
        return 'Momentum';
      case DiscoverStockPreset.value:
        return 'Value';
      case DiscoverStockPreset.lowVolatility:
        return 'Low Volatility';
      case DiscoverStockPreset.quality:
        return 'Quality';
      case DiscoverStockPreset.dividend:
        return 'Dividend';
      case DiscoverStockPreset.largeCap:
        return 'Large Cap';
      case DiscoverStockPreset.midCap:
        return 'Mid Cap';
      case DiscoverStockPreset.smallCap:
        return 'Small Cap';
    }
  }

  /// Segment labels for the SegmentedButton grouping.
  static const segmentLabels = ['All', 'Strategy', 'Market Cap'];

  /// Sub-presets for each segment.
  static List<DiscoverStockPreset> subPresetsFor(String segment) {
    switch (segment) {
      case 'Strategy':
        return [
          DiscoverStockPreset.momentum,
          DiscoverStockPreset.value,
          DiscoverStockPreset.quality,
          DiscoverStockPreset.lowVolatility,
          DiscoverStockPreset.dividend,
        ];
      case 'Market Cap':
        return [
          DiscoverStockPreset.largeCap,
          DiscoverStockPreset.midCap,
          DiscoverStockPreset.smallCap,
        ];
      default:
        return [];
    }
  }

  static DiscoverStockPreset fromApi(String? value) {
    switch (value) {
      case 'all':
        return DiscoverStockPreset.all;
      case 'value':
        return DiscoverStockPreset.value;
      case 'low-volatility':
        return DiscoverStockPreset.lowVolatility;
      case 'quality':
        return DiscoverStockPreset.quality;
      case 'dividend':
        return DiscoverStockPreset.dividend;
      case 'large-cap':
        return DiscoverStockPreset.largeCap;
      case 'mid-cap':
        return DiscoverStockPreset.midCap;
      case 'small-cap':
        return DiscoverStockPreset.smallCap;
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
  other,
  // Equity sub-categories
  indexFund,
  largeCap,
  largeMidCap,
  midCap,
  smallCap,
  flexiCap,
  multiCap,
  elss,
  valueMf,
  focused,
  sectoral,
  international,
  // Equity / Index sub-categories (added 2026-04 after backend
  // taxonomy split — Smart Beta and International Index are new
  // sub-buckets carved out of the old generic "Index Funds" group).
  smartBetaIndex,
  // Debt sub-categories
  liquid,
  overnight,
  moneyMarket,
  ultraShort,
  shortDuration,
  lowDuration,
  mediumDuration,
  mediumLongDuration,
  longDuration,
  corporateBond,
  bankingPsu,
  gilt,
  giltConstant10y,
  dynamicBond,
  floater,
  targetMaturity,
  creditRisk,
  // Hybrid sub-categories
  aggressiveHybrid,
  balancedHybrid,
  conservativeHybrid,
  arbitrage,
  dynamicAssetAllocation,
  multiAsset,
  equitySavings,
  retirementSolutions,
  // Other sub-categories
  fofDomestic,
  fofOverseas,
  goldSilver,
  retirement,
  children,
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
      case DiscoverMutualFundPreset.other:
        return 'other';
      case DiscoverMutualFundPreset.indexFund:
        return 'index';
      case DiscoverMutualFundPreset.largeCap:
        return 'large-cap';
      case DiscoverMutualFundPreset.largeMidCap:
        return 'large-mid-cap';
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
      case DiscoverMutualFundPreset.international:
        return 'international';
      case DiscoverMutualFundPreset.smartBetaIndex:
        return 'smart-beta-index';
      case DiscoverMutualFundPreset.liquid:
        return 'liquid';
      case DiscoverMutualFundPreset.overnight:
        return 'overnight';
      case DiscoverMutualFundPreset.moneyMarket:
        return 'money-market';
      case DiscoverMutualFundPreset.ultraShort:
        return 'ultra-short';
      case DiscoverMutualFundPreset.shortDuration:
        return 'short-duration';
      case DiscoverMutualFundPreset.lowDuration:
        return 'low-duration';
      case DiscoverMutualFundPreset.mediumDuration:
        return 'medium-duration';
      case DiscoverMutualFundPreset.mediumLongDuration:
        return 'medium-long-duration';
      case DiscoverMutualFundPreset.longDuration:
        return 'long-duration';
      case DiscoverMutualFundPreset.corporateBond:
        return 'corporate-bond';
      case DiscoverMutualFundPreset.bankingPsu:
        return 'banking-psu';
      case DiscoverMutualFundPreset.gilt:
        return 'gilt';
      case DiscoverMutualFundPreset.giltConstant10y:
        return 'gilt-10yr';
      case DiscoverMutualFundPreset.dynamicBond:
        return 'dynamic-bond';
      case DiscoverMutualFundPreset.floater:
        return 'floater';
      case DiscoverMutualFundPreset.targetMaturity:
        return 'target-maturity';
      case DiscoverMutualFundPreset.creditRisk:
        return 'credit-risk';
      case DiscoverMutualFundPreset.aggressiveHybrid:
        return 'aggressive-hybrid';
      case DiscoverMutualFundPreset.balancedHybrid:
        return 'balanced-hybrid';
      case DiscoverMutualFundPreset.conservativeHybrid:
        return 'conservative-hybrid';
      case DiscoverMutualFundPreset.arbitrage:
        return 'arbitrage';
      case DiscoverMutualFundPreset.dynamicAssetAllocation:
        return 'dynamic-asset-allocation';
      case DiscoverMutualFundPreset.multiAsset:
        return 'multi-asset';
      case DiscoverMutualFundPreset.equitySavings:
        return 'equity-savings';
      case DiscoverMutualFundPreset.retirementSolutions:
        return 'retirement-solutions';
      case DiscoverMutualFundPreset.fofDomestic:
        return 'fof-domestic';
      case DiscoverMutualFundPreset.fofOverseas:
        return 'fof-overseas';
      case DiscoverMutualFundPreset.goldSilver:
        return 'gold-silver';
      case DiscoverMutualFundPreset.retirement:
        return 'retirement';
      case DiscoverMutualFundPreset.children:
        return 'children';
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
      case DiscoverMutualFundPreset.other:
        return 'Other';
      case DiscoverMutualFundPreset.indexFund:
        return 'Index';
      case DiscoverMutualFundPreset.largeCap:
        return 'Large Cap';
      case DiscoverMutualFundPreset.largeMidCap:
        return 'Large & Mid Cap';
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
      case DiscoverMutualFundPreset.international:
        return 'International';
      case DiscoverMutualFundPreset.smartBetaIndex:
        return 'Smart Beta';
      case DiscoverMutualFundPreset.liquid:
        return 'Liquid';
      case DiscoverMutualFundPreset.overnight:
        return 'Overnight';
      case DiscoverMutualFundPreset.moneyMarket:
        return 'Money Market';
      case DiscoverMutualFundPreset.ultraShort:
        return 'Ultra Short';
      case DiscoverMutualFundPreset.shortDuration:
        return 'Short Duration';
      case DiscoverMutualFundPreset.lowDuration:
        return 'Low Duration';
      case DiscoverMutualFundPreset.mediumDuration:
        return 'Medium Duration';
      case DiscoverMutualFundPreset.mediumLongDuration:
        return 'Medium-Long Duration';
      case DiscoverMutualFundPreset.longDuration:
        return 'Long Duration';
      case DiscoverMutualFundPreset.corporateBond:
        return 'Corporate Bond';
      case DiscoverMutualFundPreset.bankingPsu:
        return 'Banking & PSU';
      case DiscoverMutualFundPreset.gilt:
        return 'Gilt';
      case DiscoverMutualFundPreset.giltConstant10y:
        return 'Gilt 10Y';
      case DiscoverMutualFundPreset.dynamicBond:
        return 'Dynamic Bond';
      case DiscoverMutualFundPreset.floater:
        return 'Floater';
      case DiscoverMutualFundPreset.targetMaturity:
        return 'Target Maturity';
      case DiscoverMutualFundPreset.creditRisk:
        return 'Credit Risk';
      case DiscoverMutualFundPreset.aggressiveHybrid:
        return 'Aggressive';
      case DiscoverMutualFundPreset.balancedHybrid:
        return 'Balanced';
      case DiscoverMutualFundPreset.conservativeHybrid:
        return 'Conservative';
      case DiscoverMutualFundPreset.arbitrage:
        return 'Arbitrage';
      case DiscoverMutualFundPreset.dynamicAssetAllocation:
        return 'Dynamic Asset';
      case DiscoverMutualFundPreset.multiAsset:
        return 'Multi Asset';
      case DiscoverMutualFundPreset.equitySavings:
        return 'Equity Savings';
      case DiscoverMutualFundPreset.retirementSolutions:
        return 'Retirement';
      case DiscoverMutualFundPreset.fofDomestic:
        return 'FoF Domestic';
      case DiscoverMutualFundPreset.fofOverseas:
        return 'FoF Overseas';
      case DiscoverMutualFundPreset.goldSilver:
        return 'Gold & Silver';
      case DiscoverMutualFundPreset.retirement:
        return 'Retirement';
      case DiscoverMutualFundPreset.children:
        return 'Children';
      case DiscoverMutualFundPreset.lowRisk:
        return 'Low Risk';
    }
  }

  static List<DiscoverMutualFundPreset> get segments => [
        DiscoverMutualFundPreset.all,
        DiscoverMutualFundPreset.equity,
        DiscoverMutualFundPreset.debt,
        DiscoverMutualFundPreset.hybrid,
        DiscoverMutualFundPreset.other,
      ];

  static List<DiscoverMutualFundPreset> get equitySubCategories => [
        DiscoverMutualFundPreset.indexFund,
        DiscoverMutualFundPreset.largeCap,
        DiscoverMutualFundPreset.largeMidCap,
        DiscoverMutualFundPreset.midCap,
        DiscoverMutualFundPreset.smallCap,
        DiscoverMutualFundPreset.flexiCap,
        DiscoverMutualFundPreset.multiCap,
        DiscoverMutualFundPreset.elss,
        DiscoverMutualFundPreset.valueMf,
        DiscoverMutualFundPreset.focused,
        DiscoverMutualFundPreset.sectoral,
        DiscoverMutualFundPreset.smartBetaIndex,
        DiscoverMutualFundPreset.international,
      ];

  static List<DiscoverMutualFundPreset> get debtSubCategories => [
        // Duration-sorted: shortest → longest, then specialty buckets.
        DiscoverMutualFundPreset.liquid,
        DiscoverMutualFundPreset.overnight,
        DiscoverMutualFundPreset.moneyMarket,
        DiscoverMutualFundPreset.ultraShort,
        DiscoverMutualFundPreset.lowDuration,
        DiscoverMutualFundPreset.shortDuration,
        DiscoverMutualFundPreset.mediumDuration,
        DiscoverMutualFundPreset.mediumLongDuration,
        DiscoverMutualFundPreset.longDuration,
        DiscoverMutualFundPreset.corporateBond,
        DiscoverMutualFundPreset.bankingPsu,
        DiscoverMutualFundPreset.gilt,
        DiscoverMutualFundPreset.giltConstant10y,
        DiscoverMutualFundPreset.dynamicBond,
        DiscoverMutualFundPreset.floater,
        DiscoverMutualFundPreset.targetMaturity,
        DiscoverMutualFundPreset.creditRisk,
      ];

  static List<DiscoverMutualFundPreset> get hybridSubCategories => [
        DiscoverMutualFundPreset.aggressiveHybrid,
        DiscoverMutualFundPreset.balancedHybrid,
        DiscoverMutualFundPreset.conservativeHybrid,
        DiscoverMutualFundPreset.arbitrage,
        DiscoverMutualFundPreset.dynamicAssetAllocation,
        DiscoverMutualFundPreset.multiAsset,
        DiscoverMutualFundPreset.equitySavings,
        DiscoverMutualFundPreset.retirementSolutions,
      ];

  static List<DiscoverMutualFundPreset> get otherSubCategories => [
        DiscoverMutualFundPreset.fofDomestic,
        DiscoverMutualFundPreset.fofOverseas,
        DiscoverMutualFundPreset.goldSilver,
        DiscoverMutualFundPreset.retirement,
        DiscoverMutualFundPreset.children,
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
      case 'large-mid-cap':
        return DiscoverMutualFundPreset.largeMidCap;
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
      case 'arbitrage':
        return DiscoverMutualFundPreset.arbitrage;
      case 'dynamic-asset-allocation':
        return DiscoverMutualFundPreset.dynamicAssetAllocation;
      case 'multi-asset':
        return DiscoverMutualFundPreset.multiAsset;
      case 'equity-savings':
        return DiscoverMutualFundPreset.equitySavings;
      case 'other':
        return DiscoverMutualFundPreset.other;
      case 'fof-domestic':
        return DiscoverMutualFundPreset.fofDomestic;
      case 'fof-overseas':
        return DiscoverMutualFundPreset.fofOverseas;
      case 'gold-silver':
        return DiscoverMutualFundPreset.goldSilver;
      case 'retirement':
        return DiscoverMutualFundPreset.retirement;
      case 'children':
        return DiscoverMutualFundPreset.children;
      case 'international':
        return DiscoverMutualFundPreset.international;
      case 'ultra-short':
        return DiscoverMutualFundPreset.ultraShort;
      case 'low-duration':
        return DiscoverMutualFundPreset.lowDuration;
      case 'medium-duration':
        return DiscoverMutualFundPreset.mediumDuration;
      case 'medium-long-duration':
        return DiscoverMutualFundPreset.mediumLongDuration;
      case 'long-duration':
        return DiscoverMutualFundPreset.longDuration;
      case 'gilt-10yr':
        return DiscoverMutualFundPreset.giltConstant10y;
      case 'floater':
        return DiscoverMutualFundPreset.floater;
      case 'target-maturity':
        return DiscoverMutualFundPreset.targetMaturity;
      case 'credit-risk':
        return DiscoverMutualFundPreset.creditRisk;
      case 'smart-beta-index':
        return DiscoverMutualFundPreset.smartBetaIndex;
      case 'retirement-solutions':
        return DiscoverMutualFundPreset.retirementSolutions;
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
    this.minScore = 0,
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
    this.minScore = 0,
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

class _DiscoverStockFiltersNotifier
    extends StateNotifier<DiscoverStockFilters> {
  _DiscoverStockFiltersNotifier() : super(const DiscoverStockFilters());

  void setFilters(DiscoverStockFilters next) {
    state = next;
  }
}

class _DiscoverMutualFundFiltersNotifier
    extends StateNotifier<DiscoverMutualFundFilters> {
  _DiscoverMutualFundFiltersNotifier()
      : super(const DiscoverMutualFundFilters());

  void setFilters(DiscoverMutualFundFilters next) {
    state = next;
  }
}

final discoverSegmentProvider =
    StateNotifierProvider<_DiscoverSegmentNotifier, DiscoverSegment>((ref) {
  return _DiscoverSegmentNotifier();
});

// autoDispose: filters/presets reset to defaults when screener screen is disposed
final discoverStockPresetProvider = StateNotifierProvider.autoDispose<
    _DiscoverStockPresetNotifier, DiscoverStockPreset>((ref) {
  return _DiscoverStockPresetNotifier();
});

final discoverMutualFundPresetProvider = StateNotifierProvider.autoDispose<
    _DiscoverMutualFundPresetNotifier, DiscoverMutualFundPreset>((ref) {
  return _DiscoverMutualFundPresetNotifier();
});

final discoverStockFiltersProvider = StateNotifierProvider.autoDispose<
    _DiscoverStockFiltersNotifier, DiscoverStockFilters>((ref) {
  return _DiscoverStockFiltersNotifier();
});

final discoverMutualFundFiltersProvider = StateNotifierProvider.autoDispose<
    _DiscoverMutualFundFiltersNotifier, DiscoverMutualFundFilters>((ref) {
  return _DiscoverMutualFundFiltersNotifier();
});

final discoverRepoProvider = Provider<DiscoverRepository>((ref) {
  return ref.watch(discoverRepositoryProvider);
});

final discoverOverviewProvider = FutureProvider.autoDispose
    .family<DiscoverOverview, DiscoverSegment>((ref, segment) {
  return ref.watch(discoverRepoProvider).getOverview(segment: segment.apiValue);
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
      final response = await _fetch(
          offset: current.items.length, preset: preset, filters: filters);
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

class DiscoverMfListNotifier extends AutoDisposeAsyncNotifier<
    PaginatedListState<DiscoverMutualFundItem>> {
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
      final response = await _fetch(
          offset: current.items.length, preset: preset, filters: filters);
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

final discoverSearchProvider = FutureProvider.autoDispose
    .family<UnifiedSearchResponse, String>((ref, query) {
  if (query.trim().length < 2) {
    return const UnifiedSearchResponse(stocks: [], mutualFunds: []);
  }
  return ref.watch(discoverRepoProvider).search(query: query, limit: 10);
});

final discoverStockHistoryProvider = FutureProvider.autoDispose
    .family<PriceHistoryResponse, ({String symbol, int days})>((ref, params) {
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

final discoverMfDetailProvider = FutureProvider.autoDispose
    .family<DiscoverMutualFundItem, String>((ref, schemeCode) {
  return ref
      .watch(discoverRepoProvider)
      .getMfBySchemeCode(schemeCode: schemeCode);
});

/// Detail lookup with a display-name fallback. When a stale or
/// regular-plan scheme code (e.g. 101762 for HDFC Flexi Cap) is
/// deep-linked from the home-screen widget, the snapshots table
/// doesn't have it — only the Direct Plan codes are ingested. In
/// that case fall back to a screener search on the display name
/// and return the first result (sorted by score server-side).
final discoverMfDetailWithFallbackProvider = FutureProvider.autoDispose
    .family<DiscoverMutualFundItem, ({String schemeCode, String? fallbackName})>(
  (ref, key) async {
    final repo = ref.watch(discoverRepoProvider);
    try {
      return await repo.getMfBySchemeCode(schemeCode: key.schemeCode);
    } catch (_) {
      final name = key.fallbackName?.trim();
      if (name == null || name.isEmpty) rethrow;
      final remote = ref.watch(remoteDataSourceProvider);
      final results = await remote.getDiscoverMutualFunds(
        preset: 'all',
        search: name,
        limit: 1,
      );
      if (results.items.isEmpty) rethrow;
      return results.items.first;
    }
  },
);

final discoverStockPeersProvider = FutureProvider.autoDispose
    .family<List<DiscoverStockItem>, String>((ref, symbol) {
  return ref
      .watch(discoverRepoProvider)
      .getStockPeers(symbol: symbol, limit: 5);
});

final discoverMfPeersProvider = FutureProvider.autoDispose
    .family<List<DiscoverMutualFundItem>, String>((ref, schemeCode) {
  return ref
      .watch(discoverRepoProvider)
      .getMfPeers(schemeCode: schemeCode, limit: 5);
});

// ---------------------------------------------------------------------------
// Sparklines
// ---------------------------------------------------------------------------

/// Key uses a CSV string (not List) so Riverpod family equality works correctly.
final discoverStockSparklinesProvider = FutureProvider.autoDispose.family<
    Map<String, List<PriceHistoryPoint>>,
    ({String symbolsCsv, int days})>((ref, params) {
  final symbols =
      params.symbolsCsv.split(',').where((s) => s.isNotEmpty).toList();
  return ref
      .watch(discoverRepoProvider)
      .getStockSparklines(symbols: symbols, days: params.days);
});

/// Key uses a CSV string (not List) so Riverpod family equality works correctly.
final discoverMfSparklinesProvider = FutureProvider.autoDispose.family<
    Map<String, List<PriceHistoryPoint>>,
    ({String codesCsv, int days})>((ref, params) {
  final codes = params.codesCsv.split(',').where((s) => s.isNotEmpty).toList();
  return ref
      .watch(discoverRepoProvider)
      .getMfSparklines(schemeCodes: codes, days: params.days);
});

// ---------------------------------------------------------------------------
// Recently Viewed
// ---------------------------------------------------------------------------

class RecentlyViewedNotifier extends StateNotifier<List<RecentlyViewedItem>> {
  late final RecentlyViewedService _service;

  RecentlyViewedNotifier(RecentlyViewedService service)
      : _service = service,
        super(service.load());

  Future<void> add({
    required String type,
    required String id,
    required String name,
  }) async {
    state = await _service.addItem(type: type, id: id, name: name);
  }

  Future<void> clear() async {
    await _service.clear();
    state = [];
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<RecentlyViewedItem>>(
        (ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecentlyViewedNotifier(RecentlyViewedService(prefs));
});

// ---------------------------------------------------------------------------
// Score History
// ---------------------------------------------------------------------------

final discoverStockScoreHistoryProvider = FutureProvider.family
    .autoDispose<ScoreHistoryResponse, ({String symbol, int days})>(
  (ref, params) {
    final repo = ref.watch(discoverRepositoryProvider);
    return repo.getStockScoreHistory(symbol: params.symbol, days: params.days);
  },
);

// ---------------------------------------------------------------------------
// Stock Story
// ---------------------------------------------------------------------------

final discoverStockStoryProvider =
    FutureProvider.family.autoDispose<StockStory, String>(
  (ref, symbol) {
    final repo = ref.watch(discoverRepositoryProvider);
    return repo.getStockStory(symbol: symbol);
  },
);

// ---------------------------------------------------------------------------
// Stock Compare
// ---------------------------------------------------------------------------

final discoverStockCompareProvider =
    FutureProvider.family.autoDispose<StockCompareResponse, List<String>>(
  (ref, symbols) {
    final repo = ref.watch(discoverRepositoryProvider);
    return repo.compareStocks(symbols: symbols);
  },
);

// ---------------------------------------------------------------------------
// Market Mood
// ---------------------------------------------------------------------------

final discoverMarketMoodProvider = FutureProvider.autoDispose<MarketMood>(
  (ref) {
    final repo = ref.watch(discoverRepositoryProvider);
    return repo.getMarketMood();
  },
);

// ---------------------------------------------------------------------------
// Starred Discover Items (stocks & MFs watchlist)
// ---------------------------------------------------------------------------

class StarredStocksNotifier extends StateNotifier<List<StarredItem>> {
  late final StarredStocksService _service;
  final Future<void> Function() _publishWidget;

  StarredStocksNotifier(
    StarredStocksService service, {
    required Future<void> Function() publishWidget,
  })  : _service = service,
        _publishWidget = publishWidget,
        super(service.load());

  Future<void> toggle({
    required String type,
    required String id,
    required String name,
    double? percentChange,
  }) async {
    state = await _service.toggle(
      type: type,
      id: id,
      name: name,
      percentChange: percentChange,
    );
    unawaited(_publishWidget());
  }

  bool isStarred({required String type, required String id}) {
    return state.any((e) => e.type == type && e.id == id);
  }
}

final starredStocksProvider =
    StateNotifierProvider<StarredStocksNotifier, List<StarredItem>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StarredStocksNotifier(
    StarredStocksService(prefs),
    publishWidget: () => ref.read(dashboardHomeWidgetServiceProvider).publish(),
  );
});

/// Live 1D quotes for every starred symbol.
///
/// Replaces the old pattern of reading `StarredItem.percentChange`, which
/// stored a frozen value at star-time and never refreshed (so the
/// watchlist showed "-0.7% 3M" for ACE months after the real change
/// had moved to +2.31%). This provider:
///
///   1. Reads the starred symbol list.
///   2. Fetches the live detail for each one in parallel via
///      /screener/stocks/{symbol}/detail (served from the snapshot
///      table that the intraday job refreshes every 30 min).
///   3. Returns a map keyed by symbol → DiscoverStockItem.
///
/// Watching UIs can look up each row's `percentChange` (today's 1D
/// change) and `lastPrice` without ever trusting the stale local copy.
/// The provider is autoDispose so it re-fetches when the tab re-opens.
final starredStockLiveQuotesProvider =
    FutureProvider.autoDispose<Map<String, DiscoverStockItem>>((ref) async {
  final starred = ref.watch(starredStocksProvider);
  final stockSymbols = starred
      .where((e) => e.type == 'stock')
      .map((e) => e.id)
      .toList(growable: false);
  if (stockSymbols.isEmpty) {
    return <String, DiscoverStockItem>{};
  }
  final repo = ref.watch(discoverRepositoryProvider);
  final futures = stockSymbols.map(
    (s) => repo
        .getStockBySymbol(symbol: s)
        .then<MapEntry<String, DiscoverStockItem>?>(
          (item) => MapEntry(s, item),
          onError: (_) => null,
        ),
  );
  final results = await Future.wait(futures);
  return {
    for (final e in results.whereType<MapEntry<String, DiscoverStockItem>>())
      e.key: e.value,
  };
});

/// Live detail snapshot for every starred mutual fund.
///
/// Mirrors [starredStockLiveQuotesProvider], but pulls the latest
/// fund detail via /screener/mutual-funds/{scheme_code}/detail so the
/// dashboard can show current NAV, 1Y return, score, and freshness.
/// Individual fetch failures are ignored to preserve partial results.
final starredMfLiveQuotesProvider =
    FutureProvider.autoDispose<Map<String, DiscoverMutualFundItem>>(
        (ref) async {
  final starred = ref.watch(starredStocksProvider);
  final schemeCodes = starred
      .where((e) => e.type == 'mf')
      .map((e) => e.id)
      .toList(growable: false);
  if (schemeCodes.isEmpty) {
    return <String, DiscoverMutualFundItem>{};
  }
  final repo = ref.watch(discoverRepositoryProvider);
  final futures = schemeCodes.map(
    (code) => repo
        .getMfBySchemeCode(schemeCode: code)
        .then<MapEntry<String, DiscoverMutualFundItem>?>(
          (item) => MapEntry(code, item),
          onError: (_) => null,
        ),
  );
  final results = await Future.wait(futures);
  return {
    for (final e
        in results.whereType<MapEntry<String, DiscoverMutualFundItem>>())
      e.key: e.value,
  };
});
