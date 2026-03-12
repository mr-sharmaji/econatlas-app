import 'package:flutter/foundation.dart';

@immutable
class ScoreDistribution {
  final int excellent;
  final int good;
  final int average;
  final int poor;

  const ScoreDistribution({
    this.excellent = 0,
    this.good = 0,
    this.average = 0,
    this.poor = 0,
  });

  int get total => excellent + good + average + poor;

  factory ScoreDistribution.fromJson(Map<String, dynamic> json) {
    return ScoreDistribution(
      excellent: (json['excellent'] as num?)?.toInt() ?? 0,
      good: (json['good'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toInt() ?? 0,
      poor: (json['poor'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class TopSegmentEntry {
  final String name;
  final double avgScore;
  final int count;

  const TopSegmentEntry({
    required this.name,
    required this.avgScore,
    required this.count,
  });

  factory TopSegmentEntry.fromJson(Map<String, dynamic> json) {
    return TopSegmentEntry(
      name: json['name'] as String? ?? '',
      avgScore: (json['avg_score'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class DiscoverOverview {
  final String segment;
  final DateTime? asOf;
  final int totalItems;
  final String sourceStatus;
  final List<String> leaders;
  final List<String> laggards;
  final double? avgScore;
  final ScoreDistribution? scoreDistribution;
  final List<TopSegmentEntry> topSectors;
  final List<TopSegmentEntry> topCategories;
  final double? dataFreshnessMinutes;

  const DiscoverOverview({
    required this.segment,
    required this.asOf,
    required this.totalItems,
    required this.sourceStatus,
    required this.leaders,
    required this.laggards,
    this.avgScore,
    this.scoreDistribution,
    this.topSectors = const [],
    this.topCategories = const [],
    this.dataFreshnessMinutes,
  });

  factory DiscoverOverview.fromJson(Map<String, dynamic> json) {
    return DiscoverOverview(
      segment: json['segment'] as String? ?? 'stocks',
      asOf: json['as_of'] != null
          ? DateTime.tryParse(json['as_of'] as String)
          : null,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      sourceStatus: json['source_status'] as String? ?? 'limited',
      leaders:
          (json['leaders'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      laggards:
          (json['laggards'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      avgScore: (json['avg_score'] as num?)?.toDouble(),
      scoreDistribution: json['score_distribution'] != null
          ? ScoreDistribution.fromJson(
              json['score_distribution'] as Map<String, dynamic>)
          : null,
      topSectors: (json['top_sectors'] as List<dynamic>? ?? const [])
          .map((e) => TopSegmentEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      topCategories: (json['top_categories'] as List<dynamic>? ?? const [])
          .map((e) => TopSegmentEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataFreshnessMinutes:
          (json['data_freshness_minutes'] as num?)?.toDouble(),
    );
  }
}

@immutable
class DiscoverStockScoreBreakdown {
  final double momentum;
  final double liquidity;
  final double fundamentals;
  final double combinedSignal;

  const DiscoverStockScoreBreakdown({
    required this.momentum,
    required this.liquidity,
    required this.fundamentals,
    required this.combinedSignal,
  });

  factory DiscoverStockScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return DiscoverStockScoreBreakdown(
      momentum: (json['momentum'] as num?)?.toDouble() ?? 0,
      liquidity: (json['liquidity'] as num?)?.toDouble() ?? 0,
      fundamentals: (json['fundamentals'] as num?)?.toDouble() ?? 0,
      combinedSignal: (json['combined_signal'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class DiscoverStockItem {
  final String symbol;
  final String displayName;
  final String market;
  final String? sector;
  final double lastPrice;
  final double? pointChange;
  final double? percentChange;
  final int? volume;
  final double? tradedValue;
  final double? peRatio;
  final double? roe;
  final double? roce;
  final double? debtToEquity;
  final double? priceToBook;
  final double? eps;
  final double score;
  final double scoreMomentum;
  final double scoreLiquidity;
  final double scoreFundamentals;
  final DiscoverStockScoreBreakdown scoreBreakdown;
  final List<String> tags;
  final List<String> whyRanked;
  final String sourceStatus;
  final DateTime sourceTimestamp;
  final DateTime ingestedAt;
  final String? primarySource;
  final String? secondarySource;

  const DiscoverStockItem({
    required this.symbol,
    required this.displayName,
    required this.market,
    required this.sector,
    required this.lastPrice,
    required this.pointChange,
    required this.percentChange,
    required this.volume,
    required this.tradedValue,
    required this.peRatio,
    required this.roe,
    required this.roce,
    required this.debtToEquity,
    required this.priceToBook,
    required this.eps,
    required this.score,
    required this.scoreMomentum,
    required this.scoreLiquidity,
    required this.scoreFundamentals,
    required this.scoreBreakdown,
    required this.tags,
    required this.whyRanked,
    required this.sourceStatus,
    required this.sourceTimestamp,
    required this.ingestedAt,
    required this.primarySource,
    required this.secondarySource,
  });

  factory DiscoverStockItem.fromJson(Map<String, dynamic> json) {
    return DiscoverStockItem(
      symbol: json['symbol'] as String,
      displayName: json['display_name'] as String,
      market: json['market'] as String? ?? 'IN',
      sector: json['sector'] as String?,
      lastPrice: (json['last_price'] as num).toDouble(),
      pointChange: (json['point_change'] as num?)?.toDouble(),
      percentChange: (json['percent_change'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toInt(),
      tradedValue: (json['traded_value'] as num?)?.toDouble(),
      peRatio: (json['pe_ratio'] as num?)?.toDouble(),
      roe: (json['roe'] as num?)?.toDouble(),
      roce: (json['roce'] as num?)?.toDouble(),
      debtToEquity: (json['debt_to_equity'] as num?)?.toDouble(),
      priceToBook: (json['price_to_book'] as num?)?.toDouble(),
      eps: (json['eps'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      scoreMomentum: (json['score_momentum'] as num?)?.toDouble() ?? 0,
      scoreLiquidity: (json['score_liquidity'] as num?)?.toDouble() ?? 0,
      scoreFundamentals: (json['score_fundamentals'] as num?)?.toDouble() ?? 0,
      scoreBreakdown: DiscoverStockScoreBreakdown.fromJson(
        (json['score_breakdown'] as Map<String, dynamic>? ?? const {}),
      ),
      tags: (json['tags'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      whyRanked:
          (json['why_ranked'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      sourceStatus: json['source_status'] as String? ?? 'limited',
      sourceTimestamp: DateTime.parse(json['source_timestamp'] as String),
      ingestedAt: DateTime.parse(json['ingested_at'] as String),
      primarySource: json['primary_source'] as String?,
      secondarySource: json['secondary_source'] as String?,
    );
  }
}

@immutable
class DiscoverStockListResponse {
  final String preset;
  final DateTime? asOf;
  final String sourceStatus;
  final List<DiscoverStockItem> items;
  final int count;
  final int? totalCount;

  const DiscoverStockListResponse({
    required this.preset,
    required this.asOf,
    required this.sourceStatus,
    required this.items,
    required this.count,
    this.totalCount,
  });

  factory DiscoverStockListResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    return DiscoverStockListResponse(
      preset: json['preset'] as String? ?? 'momentum',
      asOf: json['as_of'] != null
          ? DateTime.tryParse(json['as_of'] as String)
          : null,
      sourceStatus: json['source_status'] as String? ?? 'limited',
      items: itemsRaw
          .map((e) => DiscoverStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? itemsRaw.length,
      totalCount: (json['total_count'] as num?)?.toInt(),
    );
  }
}

@immutable
class DiscoverMutualFundScoreBreakdown {
  final double returnScore;
  final double riskScore;
  final double costScore;
  final double consistencyScore;

  const DiscoverMutualFundScoreBreakdown({
    required this.returnScore,
    required this.riskScore,
    required this.costScore,
    required this.consistencyScore,
  });

  factory DiscoverMutualFundScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return DiscoverMutualFundScoreBreakdown(
      returnScore: (json['return_score'] as num?)?.toDouble() ?? 0,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0,
      costScore: (json['cost_score'] as num?)?.toDouble() ?? 0,
      consistencyScore: (json['consistency_score'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class DiscoverMutualFundItem {
  final String schemeCode;
  final String schemeName;
  final String? amc;
  final String? category;
  final String? subCategory;
  final String planType;
  final String? optionType;
  final double nav;
  final DateTime? navDate;
  final double? expenseRatio;
  final double? aumCr;
  final String? riskLevel;
  final double? returns1y;
  final double? returns3y;
  final double? returns5y;
  final double? stdDev;
  final double? sharpe;
  final double? sortino;
  final double score;
  final double scoreReturn;
  final double scoreRisk;
  final double scoreCost;
  final double scoreConsistency;
  final DiscoverMutualFundScoreBreakdown scoreBreakdown;
  final List<String> tags;
  final List<String> whyRanked;
  final String sourceStatus;
  final DateTime sourceTimestamp;
  final DateTime ingestedAt;
  final String? primarySource;
  final String? secondarySource;

  const DiscoverMutualFundItem({
    required this.schemeCode,
    required this.schemeName,
    required this.amc,
    required this.category,
    required this.subCategory,
    required this.planType,
    required this.optionType,
    required this.nav,
    required this.navDate,
    required this.expenseRatio,
    required this.aumCr,
    required this.riskLevel,
    required this.returns1y,
    required this.returns3y,
    required this.returns5y,
    required this.stdDev,
    required this.sharpe,
    required this.sortino,
    required this.score,
    required this.scoreReturn,
    required this.scoreRisk,
    required this.scoreCost,
    required this.scoreConsistency,
    required this.scoreBreakdown,
    required this.tags,
    required this.whyRanked,
    required this.sourceStatus,
    required this.sourceTimestamp,
    required this.ingestedAt,
    required this.primarySource,
    required this.secondarySource,
  });

  factory DiscoverMutualFundItem.fromJson(Map<String, dynamic> json) {
    return DiscoverMutualFundItem(
      schemeCode: json['scheme_code'] as String,
      schemeName: json['scheme_name'] as String,
      amc: json['amc'] as String?,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      planType: json['plan_type'] as String? ?? 'direct',
      optionType: json['option_type'] as String?,
      nav: (json['nav'] as num).toDouble(),
      navDate: json['nav_date'] != null
          ? DateTime.tryParse(json['nav_date'] as String)
          : null,
      expenseRatio: (json['expense_ratio'] as num?)?.toDouble(),
      aumCr: (json['aum_cr'] as num?)?.toDouble(),
      riskLevel: json['risk_level'] as String?,
      returns1y: (json['returns_1y'] as num?)?.toDouble(),
      returns3y: (json['returns_3y'] as num?)?.toDouble(),
      returns5y: (json['returns_5y'] as num?)?.toDouble(),
      stdDev: (json['std_dev'] as num?)?.toDouble(),
      sharpe: (json['sharpe'] as num?)?.toDouble(),
      sortino: (json['sortino'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      scoreReturn: (json['score_return'] as num?)?.toDouble() ?? 0,
      scoreRisk: (json['score_risk'] as num?)?.toDouble() ?? 0,
      scoreCost: (json['score_cost'] as num?)?.toDouble() ?? 0,
      scoreConsistency: (json['score_consistency'] as num?)?.toDouble() ?? 0,
      scoreBreakdown: DiscoverMutualFundScoreBreakdown.fromJson(
        (json['score_breakdown'] as Map<String, dynamic>? ?? const {}),
      ),
      tags: (json['tags'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      whyRanked:
          (json['why_ranked'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      sourceStatus: json['source_status'] as String? ?? 'limited',
      sourceTimestamp: DateTime.parse(json['source_timestamp'] as String),
      ingestedAt: DateTime.parse(json['ingested_at'] as String),
      primarySource: json['primary_source'] as String?,
      secondarySource: json['secondary_source'] as String?,
    );
  }
}

@immutable
class DiscoverMutualFundListResponse {
  final String preset;
  final DateTime? asOf;
  final String sourceStatus;
  final List<DiscoverMutualFundItem> items;
  final int count;
  final int? totalCount;

  const DiscoverMutualFundListResponse({
    required this.preset,
    required this.asOf,
    required this.sourceStatus,
    required this.items,
    required this.count,
    this.totalCount,
  });

  factory DiscoverMutualFundListResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    return DiscoverMutualFundListResponse(
      preset: json['preset'] as String? ?? 'all',
      asOf: json['as_of'] != null
          ? DateTime.tryParse(json['as_of'] as String)
          : null,
      sourceStatus: json['source_status'] as String? ?? 'limited',
      items: itemsRaw
          .map((e) => DiscoverMutualFundItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? itemsRaw.length,
      totalCount: (json['total_count'] as num?)?.toInt(),
    );
  }
}

@immutable
class ComparisonSummary {
  final String winner;
  final double scoreDelta;
  final Map<String, String> metricWinners;

  const ComparisonSummary({
    required this.winner,
    required this.scoreDelta,
    this.metricWinners = const {},
  });

  factory ComparisonSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['metric_winners'] as Map<String, dynamic>? ?? const {};
    return ComparisonSummary(
      winner: json['winner'] as String? ?? '',
      scoreDelta: (json['score_delta'] as num?)?.toDouble() ?? 0,
      metricWinners: raw.map((k, v) => MapEntry(k, '$v')),
    );
  }
}

@immutable
class DiscoverCompareResponse {
  final String segment;
  final DateTime? asOf;
  final int count;
  final String sourceStatus;
  final List<DiscoverStockItem> stockItems;
  final List<DiscoverMutualFundItem> mutualFundItems;
  final ComparisonSummary? comparisonSummary;

  const DiscoverCompareResponse({
    required this.segment,
    required this.asOf,
    required this.count,
    required this.sourceStatus,
    required this.stockItems,
    required this.mutualFundItems,
    this.comparisonSummary,
  });

  factory DiscoverCompareResponse.fromJson(Map<String, dynamic> json) {
    final stockRaw = json['stock_items'] as List<dynamic>? ?? const [];
    final mfRaw = json['mutual_fund_items'] as List<dynamic>? ?? const [];
    return DiscoverCompareResponse(
      segment: json['segment'] as String? ?? 'stocks',
      asOf: json['as_of'] != null
          ? DateTime.tryParse(json['as_of'] as String)
          : null,
      count: (json['count'] as num?)?.toInt() ?? 0,
      sourceStatus: json['source_status'] as String? ?? 'limited',
      stockItems: stockRaw
          .map((e) => DiscoverStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      mutualFundItems: mfRaw
          .map((e) =>
              DiscoverMutualFundItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      comparisonSummary: json['comparison_summary'] != null
          ? ComparisonSummary.fromJson(
              json['comparison_summary'] as Map<String, dynamic>)
          : null,
    );
  }
}
