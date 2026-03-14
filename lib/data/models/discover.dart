import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Stock
// ---------------------------------------------------------------------------

@immutable
class DiscoverStockScoreBreakdown {
  final double momentum;
  final double liquidity;
  final double fundamentals;
  final double volatility;
  final double growth;
  final double combinedSignal;
  // v0.2.4 scores
  final double? financialHealth;
  final double? ownership;
  final double? analyst;
  final double? position52w;
  final String? fundamentalsCoverage;
  final String? dataQuality;
  final String? whyNarrative;
  // v0.4 scores
  final double? valuation;
  final double? earningsQuality;
  final double? smartMoney;

  const DiscoverStockScoreBreakdown({
    required this.momentum,
    required this.liquidity,
    required this.fundamentals,
    required this.volatility,
    required this.growth,
    required this.combinedSignal,
    this.financialHealth,
    this.ownership,
    this.analyst,
    this.position52w,
    this.fundamentalsCoverage,
    this.dataQuality,
    this.whyNarrative,
    this.valuation,
    this.earningsQuality,
    this.smartMoney,
  });

  factory DiscoverStockScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return DiscoverStockScoreBreakdown(
      momentum: (json['momentum'] as num?)?.toDouble() ?? 0,
      liquidity: (json['liquidity'] as num?)?.toDouble() ?? 0,
      fundamentals: (json['fundamentals'] as num?)?.toDouble() ?? 0,
      volatility: (json['volatility'] as num?)?.toDouble() ?? 0,
      growth: (json['growth'] as num?)?.toDouble() ?? 0,
      combinedSignal: (json['combined_signal'] as num?)?.toDouble() ?? 0,
      financialHealth: (json['financial_health'] as num?)?.toDouble(),
      ownership: (json['ownership'] as num?)?.toDouble(),
      analyst: (json['analyst'] as num?)?.toDouble(),
      position52w: (json['52w_position'] as num?)?.toDouble(),
      fundamentalsCoverage: json['fundamentals_coverage'] as String?,
      dataQuality: json['data_quality'] as String?,
      whyNarrative: json['why_narrative'] as String?,
      valuation: (json['valuation'] as num?)?.toDouble(),
      earningsQuality: (json['earnings_quality'] as num?)?.toDouble(),
      smartMoney: (json['smart_money'] as num?)?.toDouble(),
    );
  }
}

@immutable
class DiscoverStockItem {
  final String symbol;
  final String displayName;
  final String market;
  final String? sector;
  final String? industry;
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
  final double? high52w;
  final double? low52w;
  final double? marketCap;
  final double? dividendYield;
  final String? qualityTier;
  final double score;
  final double scoreMomentum;
  final double scoreLiquidity;
  final double scoreFundamentals;
  final double scoreVolatility;
  final double scoreGrowth;
  // v0.2.4 scores
  final double? scoreFinancialHealth;
  final double? scoreOwnership;
  final double? scoreAnalyst;
  // v0.4 scores
  final double? scoreValuation;
  final double? scoreEarningsQuality;
  final double? scoreSmartMoney;
  final double? percentChange3m;
  final double? percentChange1w;
  final double? percentChange1y;
  final double? percentChange3y;
  // Shareholding
  final double? promoterHolding;
  final double? fiiHolding;
  final double? diiHolding;
  final double? governmentHolding;
  final double? publicHolding;
  final int? numShareholders;
  final double? promoterHoldingChange;
  final double? fiiHoldingChange;
  final double? diiHoldingChange;
  // Yahoo fundamentals
  final double? beta;
  final double? freeCashFlow;
  final double? operatingCashFlow;
  final double? totalCash;
  final double? totalDebt;
  final double? totalRevenue;
  final double? grossMargins;
  final double? operatingMargins;
  final double? profitMargins;
  final double? revenueGrowth;
  final double? earningsGrowth;
  final double? forwardPe;
  final double? payoutRatio;
  // Analyst
  final double? analystTargetMean;
  final int? analystCount;
  final String? analystRecommendation;
  final double? analystRecommendationMean;
  // Pledged shares
  final double? pledgedPromoterPct;
  // Score trend
  final double? previousScore;

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
    this.industry,
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
    this.high52w,
    this.low52w,
    this.marketCap,
    this.dividendYield,
    this.qualityTier,
    required this.score,
    required this.scoreMomentum,
    required this.scoreLiquidity,
    required this.scoreFundamentals,
    required this.scoreVolatility,
    required this.scoreGrowth,
    this.scoreFinancialHealth,
    this.scoreOwnership,
    this.scoreAnalyst,
    this.scoreValuation,
    this.scoreEarningsQuality,
    this.scoreSmartMoney,
    this.percentChange3m,
    this.percentChange1w,
    this.percentChange1y,
    this.percentChange3y,
    this.promoterHolding,
    this.fiiHolding,
    this.diiHolding,
    this.governmentHolding,
    this.publicHolding,
    this.numShareholders,
    this.promoterHoldingChange,
    this.fiiHoldingChange,
    this.diiHoldingChange,
    this.beta,
    this.freeCashFlow,
    this.operatingCashFlow,
    this.totalCash,
    this.totalDebt,
    this.totalRevenue,
    this.grossMargins,
    this.operatingMargins,
    this.profitMargins,
    this.revenueGrowth,
    this.earningsGrowth,
    this.forwardPe,
    this.payoutRatio,
    this.analystTargetMean,
    this.analystCount,
    this.analystRecommendation,
    this.analystRecommendationMean,
    this.pledgedPromoterPct,
    this.previousScore,
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
      industry: json['industry'] as String?,
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
      high52w: (json['high_52w'] as num?)?.toDouble(),
      low52w: (json['low_52w'] as num?)?.toDouble(),
      marketCap: (json['market_cap'] as num?)?.toDouble(),
      dividendYield: (json['dividend_yield'] as num?)?.toDouble(),
      qualityTier: json['quality_tier'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      scoreMomentum: (json['score_momentum'] as num?)?.toDouble() ?? 0,
      scoreLiquidity: (json['score_liquidity'] as num?)?.toDouble() ?? 0,
      scoreFundamentals: (json['score_fundamentals'] as num?)?.toDouble() ?? 0,
      scoreVolatility: (json['score_volatility'] as num?)?.toDouble() ?? 0,
      scoreGrowth: (json['score_growth'] as num?)?.toDouble() ?? 0,
      scoreFinancialHealth:
          (json['score_financial_health'] as num?)?.toDouble(),
      scoreOwnership: (json['score_ownership'] as num?)?.toDouble(),
      scoreAnalyst: (json['score_analyst'] as num?)?.toDouble(),
      scoreValuation: (json['score_valuation'] as num?)?.toDouble(),
      scoreEarningsQuality:
          (json['score_earnings_quality'] as num?)?.toDouble(),
      scoreSmartMoney: (json['score_smart_money'] as num?)?.toDouble(),
      percentChange3m: (json['percent_change_3m'] as num?)?.toDouble(),
      percentChange1w: (json['percent_change_1w'] as num?)?.toDouble(),
      percentChange1y: (json['percent_change_1y'] as num?)?.toDouble(),
      percentChange3y: (json['percent_change_3y'] as num?)?.toDouble(),
      promoterHolding: (json['promoter_holding'] as num?)?.toDouble(),
      fiiHolding: (json['fii_holding'] as num?)?.toDouble(),
      diiHolding: (json['dii_holding'] as num?)?.toDouble(),
      governmentHolding: (json['government_holding'] as num?)?.toDouble(),
      publicHolding: (json['public_holding'] as num?)?.toDouble(),
      numShareholders: (json['num_shareholders'] as num?)?.toInt(),
      promoterHoldingChange:
          (json['promoter_holding_change'] as num?)?.toDouble(),
      fiiHoldingChange: (json['fii_holding_change'] as num?)?.toDouble(),
      diiHoldingChange: (json['dii_holding_change'] as num?)?.toDouble(),
      beta: (json['beta'] as num?)?.toDouble(),
      freeCashFlow: (json['free_cash_flow'] as num?)?.toDouble(),
      operatingCashFlow: (json['operating_cash_flow'] as num?)?.toDouble(),
      totalCash: (json['total_cash'] as num?)?.toDouble(),
      totalDebt: (json['total_debt'] as num?)?.toDouble(),
      totalRevenue: (json['total_revenue'] as num?)?.toDouble(),
      grossMargins: (json['gross_margins'] as num?)?.toDouble(),
      operatingMargins: (json['operating_margins'] as num?)?.toDouble(),
      profitMargins: (json['profit_margins'] as num?)?.toDouble(),
      revenueGrowth: (json['revenue_growth'] as num?)?.toDouble(),
      earningsGrowth: (json['earnings_growth'] as num?)?.toDouble(),
      forwardPe: (json['forward_pe'] as num?)?.toDouble(),
      payoutRatio: (json['payout_ratio'] as num?)?.toDouble(),
      analystTargetMean: (json['analyst_target_mean'] as num?)?.toDouble(),
      analystCount: (json['analyst_count'] as num?)?.toInt(),
      analystRecommendation: json['analyst_recommendation'] as String?,
      analystRecommendationMean:
          (json['analyst_recommendation_mean'] as num?)?.toDouble(),
      pledgedPromoterPct:
          (json['pledged_promoter_pct'] as num?)?.toDouble(),
      previousScore: (json['previous_score'] as num?)?.toDouble(),
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

// ---------------------------------------------------------------------------
// Mutual Fund
// ---------------------------------------------------------------------------

@immutable
class DiscoverMutualFundScoreBreakdown {
  final double returnScore;
  final double riskScore;
  final double costScore;
  final double consistencyScore;
  final double? alphaScore;
  final double? betaScore;

  const DiscoverMutualFundScoreBreakdown({
    required this.returnScore,
    required this.riskScore,
    required this.costScore,
    required this.consistencyScore,
    this.alphaScore,
    this.betaScore,
  });

  factory DiscoverMutualFundScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return DiscoverMutualFundScoreBreakdown(
      returnScore: (json['return_score'] as num?)?.toDouble() ?? 0,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0,
      costScore: (json['cost_score'] as num?)?.toDouble() ?? 0,
      consistencyScore: (json['consistency_score'] as num?)?.toDouble() ?? 0,
      alphaScore: (json['alpha_score'] as num?)?.toDouble(),
      betaScore: (json['beta_score'] as num?)?.toDouble(),
    );
  }
}

@immutable
class DiscoverMutualFundItem {
  final String schemeCode;
  final String schemeName;
  final String? displayName;
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
  final int? categoryRank;
  final int? categoryTotal;
  final int? subCategoryRank;
  final int? subCategoryTotal;
  final double? fundAgeYears;
  final List<String> qualityBadges;
  final double? categoryAvgReturns1y;
  final double? categoryAvgReturns3y;
  final double? categoryAvgReturns5y;
  // v0.2.4 risk/performance fields
  final double? maxDrawdown;
  final double? rollingReturnConsistency;
  final double? alpha;
  final double? beta;
  final double? scoreAlpha;
  final double? scoreBeta;

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
    this.displayName,
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
    this.categoryRank,
    this.categoryTotal,
    this.subCategoryRank,
    this.subCategoryTotal,
    this.fundAgeYears,
    this.qualityBadges = const [],
    this.categoryAvgReturns1y,
    this.categoryAvgReturns3y,
    this.categoryAvgReturns5y,
    this.maxDrawdown,
    this.rollingReturnConsistency,
    this.alpha,
    this.beta,
    this.scoreAlpha,
    this.scoreBeta,
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
      displayName: json['display_name'] as String?,
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
      categoryRank: (json['category_rank'] as num?)?.toInt(),
      categoryTotal: (json['category_total'] as num?)?.toInt(),
      subCategoryRank: (json['sub_category_rank'] as num?)?.toInt(),
      subCategoryTotal: (json['sub_category_total'] as num?)?.toInt(),
      fundAgeYears: (json['fund_age_years'] as num?)?.toDouble(),
      qualityBadges: (json['quality_badges'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
      categoryAvgReturns1y:
          (json['category_avg_returns_1y'] as num?)?.toDouble(),
      categoryAvgReturns3y:
          (json['category_avg_returns_3y'] as num?)?.toDouble(),
      categoryAvgReturns5y:
          (json['category_avg_returns_5y'] as num?)?.toDouble(),
      maxDrawdown: (json['max_drawdown'] as num?)?.toDouble(),
      rollingReturnConsistency:
          (json['rolling_return_consistency'] as num?)?.toDouble(),
      alpha: (json['alpha'] as num?)?.toDouble(),
      beta: (json['beta'] as num?)?.toDouble(),
      scoreAlpha: (json['score_alpha'] as num?)?.toDouble(),
      scoreBeta: (json['score_beta'] as num?)?.toDouble(),
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

// ---------------------------------------------------------------------------
// Unified Search
// ---------------------------------------------------------------------------

@immutable
class SearchStockResult {
  final String symbol;
  final String displayName;
  final String? sector;
  final double lastPrice;
  final double? percentChange;
  final double score;

  const SearchStockResult({
    required this.symbol,
    required this.displayName,
    this.sector,
    required this.lastPrice,
    this.percentChange,
    required this.score,
  });

  factory SearchStockResult.fromJson(Map<String, dynamic> json) {
    return SearchStockResult(
      symbol: json['symbol'] as String,
      displayName: json['display_name'] as String,
      sector: json['sector'] as String?,
      lastPrice: (json['last_price'] as num).toDouble(),
      percentChange: (json['percent_change'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class SearchMfResult {
  final String schemeCode;
  final String schemeName;
  final String? category;
  final double nav;
  final double? returns3y;
  final double score;

  const SearchMfResult({
    required this.schemeCode,
    required this.schemeName,
    this.category,
    required this.nav,
    this.returns3y,
    required this.score,
  });

  factory SearchMfResult.fromJson(Map<String, dynamic> json) {
    return SearchMfResult(
      schemeCode: json['scheme_code'] as String,
      schemeName: json['scheme_name'] as String,
      category: json['category'] as String?,
      nav: (json['nav'] as num).toDouble(),
      returns3y: (json['returns_3y'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class UnifiedSearchResponse {
  final List<SearchStockResult> stocks;
  final List<SearchMfResult> mutualFunds;

  const UnifiedSearchResponse({
    this.stocks = const [],
    this.mutualFunds = const [],
  });

  factory UnifiedSearchResponse.fromJson(Map<String, dynamic> json) {
    return UnifiedSearchResponse(
      stocks: (json['stocks'] as List<dynamic>? ?? const [])
          .map((e) => SearchStockResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      mutualFunds: (json['mutual_funds'] as List<dynamic>? ?? const [])
          .map((e) => SearchMfResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Discover Home
// ---------------------------------------------------------------------------

@immutable
class DiscoverHomeStockItem {
  final String symbol;
  final String displayName;
  final String? sector;
  final double lastPrice;
  final double? percentChange;
  final double? percentChange3m;
  final double? percentChange1w;
  final double score;
  final double? scoreVolatility;
  final double? scoreGrowth;
  final double? high52w;
  final double? low52w;
  final double? marketCap;
  final String? qualityTier;

  const DiscoverHomeStockItem({
    required this.symbol,
    required this.displayName,
    this.sector,
    required this.lastPrice,
    this.percentChange,
    this.percentChange3m,
    this.percentChange1w,
    required this.score,
    this.scoreVolatility,
    this.scoreGrowth,
    this.high52w,
    this.low52w,
    this.marketCap,
    this.qualityTier,
  });

  factory DiscoverHomeStockItem.fromJson(Map<String, dynamic> json) {
    return DiscoverHomeStockItem(
      symbol: json['symbol'] as String,
      displayName: json['display_name'] as String,
      sector: json['sector'] as String?,
      lastPrice: (json['last_price'] as num).toDouble(),
      percentChange: (json['percent_change'] as num?)?.toDouble(),
      percentChange3m: (json['percent_change_3m'] as num?)?.toDouble(),
      percentChange1w: (json['percent_change_1w'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      scoreVolatility: (json['score_volatility'] as num?)?.toDouble(),
      scoreGrowth: (json['score_growth'] as num?)?.toDouble(),
      high52w: (json['high_52w'] as num?)?.toDouble(),
      low52w: (json['low_52w'] as num?)?.toDouble(),
      marketCap: (json['market_cap'] as num?)?.toDouble(),
      qualityTier: json['quality_tier'] as String?,
    );
  }
}

@immutable
class DiscoverHomeMfItem {
  final String schemeCode;
  final String schemeName;
  final String? displayName;
  final String? category;
  final double score;
  final double? returns1y;
  final List<String> qualityBadges;

  const DiscoverHomeMfItem({
    required this.schemeCode,
    required this.schemeName,
    this.displayName,
    this.category,
    required this.score,
    this.returns1y,
    this.qualityBadges = const [],
  });

  factory DiscoverHomeMfItem.fromJson(Map<String, dynamic> json) {
    return DiscoverHomeMfItem(
      schemeCode: json['scheme_code'] as String,
      schemeName: json['scheme_name'] as String,
      displayName: json['display_name'] as String?,
      category: json['category'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      returns1y: (json['returns_1y'] as num?)?.toDouble(),
      qualityBadges: (json['quality_badges'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
    );
  }
}

@immutable
class QuickCategory {
  final String name;
  final String segment;
  final String? preset;
  final String? filterKey;
  final String? filterValue;

  const QuickCategory({
    required this.name,
    required this.segment,
    this.preset,
    this.filterKey,
    this.filterValue,
  });

  factory QuickCategory.fromJson(Map<String, dynamic> json) {
    return QuickCategory(
      name: json['name'] as String,
      segment: json['segment'] as String,
      preset: json['preset'] as String?,
      filterKey: json['filter_key'] as String?,
      filterValue: json['filter_value'] as String?,
    );
  }
}

@immutable
class DiscoverHomeData {
  final List<DiscoverHomeStockItem> topStocks;
  final List<DiscoverHomeMfItem> topEquityFunds;
  final List<DiscoverHomeMfItem> topDebtFunds;
  final List<DiscoverHomeStockItem> trendingThisWeek;
  final List<DiscoverHomeStockItem> sectorChampions;
  final List<DiscoverHomeStockItem> gainers;
  final List<DiscoverHomeStockItem> gainers3m;
  final List<DiscoverHomeStockItem> losers;
  final List<DiscoverHomeStockItem> losers3m;
  final List<QuickCategory> quickCategories;

  const DiscoverHomeData({
    this.topStocks = const [],
    this.topEquityFunds = const [],
    this.topDebtFunds = const [],
    this.trendingThisWeek = const [],
    this.sectorChampions = const [],
    this.gainers = const [],
    this.gainers3m = const [],
    this.losers = const [],
    this.losers3m = const [],
    this.quickCategories = const [],
  });

  factory DiscoverHomeData.fromJson(Map<String, dynamic> json) {
    List<DiscoverHomeStockItem> parseStocks(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) =>
                DiscoverHomeStockItem.fromJson(e as Map<String, dynamic>))
            .toList();

    return DiscoverHomeData(
      topStocks: parseStocks('top_stocks'),
      topEquityFunds:
          (json['top_equity_funds'] as List<dynamic>? ?? const [])
              .map((e) =>
                  DiscoverHomeMfItem.fromJson(e as Map<String, dynamic>))
              .toList(),
      topDebtFunds:
          (json['top_debt_funds'] as List<dynamic>? ?? const [])
              .map((e) =>
                  DiscoverHomeMfItem.fromJson(e as Map<String, dynamic>))
              .toList(),
      trendingThisWeek: parseStocks('trending_this_week'),
      sectorChampions: parseStocks('sector_champions'),
      gainers: parseStocks('gainers'),
      gainers3m: parseStocks('gainers_3m'),
      losers: parseStocks('losers'),
      losers3m: parseStocks('losers_3m'),
      quickCategories:
          (json['quick_categories'] as List<dynamic>? ?? const [])
              .map((e) => QuickCategory.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Price / NAV History (charts)
// ---------------------------------------------------------------------------

@immutable
class PriceHistoryPoint {
  final DateTime date;
  final double value;

  const PriceHistoryPoint({required this.date, required this.value});

  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) {
    return PriceHistoryPoint(
      date: DateTime.parse(json['date'] as String),
      value: (json['value'] as num).toDouble(),
    );
  }
}

@immutable
class PriceHistoryResponse {
  final String? symbol;
  final String? schemeCode;
  final List<PriceHistoryPoint> points;
  final int count;

  const PriceHistoryResponse({
    this.symbol,
    this.schemeCode,
    this.points = const [],
    this.count = 0,
  });

  factory PriceHistoryResponse.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List<dynamic>? ?? const [])
        .map((e) => PriceHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return PriceHistoryResponse(
      symbol: json['symbol'] as String?,
      schemeCode: json['scheme_code'] as String?,
      points: pts,
      count: (json['count'] as num?)?.toInt() ?? pts.length,
    );
  }
}
