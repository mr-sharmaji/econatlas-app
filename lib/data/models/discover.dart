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
// Tag V2 (structured tags with category, severity, explanation)
// ---------------------------------------------------------------------------

@immutable
class TagV2 {
  final String tag;
  final String category; // classification, style, strength, valuation, risk, trend, ownership
  final String severity; // positive, negative, neutral
  final int priority;
  final double? confidence;
  final String? explanation;
  final DateTime? expiresAt;

  const TagV2({
    required this.tag,
    required this.category,
    required this.severity,
    required this.priority,
    this.confidence,
    this.explanation,
    this.expiresAt,
  });

  factory TagV2.fromJson(Map<String, dynamic> json) {
    return TagV2(
      tag: json['tag'] as String,
      category: json['category'] as String? ?? 'classification',
      severity: json['severity'] as String? ?? 'neutral',
      priority: (json['priority'] as num?)?.toInt() ?? 99,
      confidence: (json['confidence'] as num?)?.toDouble(),
      explanation: json['explanation'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }

  bool get isPositive => severity == 'positive';
  bool get isNegative => severity == 'negative';
  bool get isNeutral => severity == 'neutral';
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

// ---------------------------------------------------------------------------
// Stock
// ---------------------------------------------------------------------------

@immutable
class DiscoverStockScoreBreakdown {
  // Legacy scores (kept for backward compatibility)
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
  // 6-layer scores (from score_breakdown JSONB)
  final double? quality;
  final double? institutional;
  final double? risk;
  // Supplementary
  final double? sectorPercentile;
  final String? lynchClassification;
  final String? marketRegime;
  final double? pegRatio;
  final double? technicalScore;
  final double? rsi14;
  final String? actionTag;
  final String? actionTagReasoning;
  final String? scoreConfidence; // "high" | "medium" | "low"
  final String? trendAlignment; // "aligned" | "aligned_bullish" | "aligned_bearish" | "divergent" | "conflicting"
  final String? breakoutSignal; // "breakout" | "approaching_breakout" | "breakdown" | "approaching_breakdown" | "resistance" | "support" | "none"
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
    this.quality,
    this.institutional,
    this.risk,
    this.sectorPercentile,
    this.lynchClassification,
    this.marketRegime,
    this.pegRatio,
    this.technicalScore,
    this.rsi14,
    this.actionTag,
    this.actionTagReasoning,
    this.scoreConfidence,
    this.trendAlignment,
    this.breakoutSignal,
  });

  /// Whether the 6-layer scoring model is available.
  bool get has6LayerScores =>
      quality != null && quality! > 0 &&
      valuation != null && valuation! > 0;

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
      quality: (json['quality'] as num?)?.toDouble(),
      institutional: (json['institutional'] as num?)?.toDouble(),
      risk: (json['risk'] as num?)?.toDouble(),
      sectorPercentile: (json['sector_percentile'] as num?)?.toDouble(),
      lynchClassification: json['lynch_classification'] as String?,
      marketRegime: json['market_regime'] as String?,
      pegRatio: (json['peg_ratio'] as num?)?.toDouble(),
      technicalScore: (json['technical_score'] as num?)?.toDouble(),
      rsi14: (json['rsi_14'] as num?)?.toDouble(),
      actionTag: json['action_tag'] as String?,
      actionTagReasoning: json['action_tag_reasoning'] as String?,
      scoreConfidence: json['score_confidence'] as String?,
      trendAlignment: json['trend_alignment'] as String?,
      breakoutSignal: json['breakout_signal'] as String?,
    );
  }
}

@immutable
class MetricInsight {
  final String explanation;
  final String sentiment; // positive, negative, neutral, warning

  const MetricInsight({required this.explanation, required this.sentiment});

  factory MetricInsight.fromJson(Map<String, dynamic> json) {
    return MetricInsight(
      explanation: json['explanation'] as String,
      sentiment: json['sentiment'] as String? ?? 'neutral',
    );
  }
}

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
  // 6-layer individual scores (top-level)
  final double? scoreQuality;
  final double? scoreInstitutional;
  final double? scoreRisk;
  // Percentile & classification
  final double? sectorPercentile;
  final String? lynchClassification;
  final double? pegRatio;
  // Technical
  final double? technicalScore;
  final double? rsi14;
  final String? actionTag;
  final String? actionTagReasoning;
  final String? scoreConfidence;
  final String? trendAlignment;
  final String? breakoutSignal;
  // Screener-derived signals
  final double? salesGrowthYoy;
  final double? profitGrowthYoy;
  final double? compoundedSalesGrowth3y;
  final double? compoundedProfitGrowth3y;
  final double? opmChange;
  final double? interestCoverage;
  final double? numShareholdersChangeQoq;
  final double? numShareholdersChangeYoy;
  final double? cashFromOperations;
  final double? cashFromInvesting;
  final double? cashFromFinancing;
  // Full annual financial tables (JSONB)
  final Map<String, dynamic>? plAnnual;
  final Map<String, dynamic>? bsAnnual;
  final Map<String, dynamic>? cfAnnual;
  final Map<String, dynamic>? shareholdingQuarterly;
  final Map<String, dynamic>? growthRanges;

  final DiscoverStockScoreBreakdown scoreBreakdown;
  final List<TagV2> tags;
  final List<String> whyRanked;
  final Map<String, MetricInsight> metricInsights;
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
    this.scoreQuality,
    this.scoreInstitutional,
    this.scoreRisk,
    this.sectorPercentile,
    this.lynchClassification,
    this.pegRatio,
    this.technicalScore,
    this.rsi14,
    this.actionTag,
    this.actionTagReasoning,
    this.scoreConfidence,
    this.trendAlignment,
    this.breakoutSignal,
    this.salesGrowthYoy,
    this.profitGrowthYoy,
    this.compoundedSalesGrowth3y,
    this.compoundedProfitGrowth3y,
    this.opmChange,
    this.interestCoverage,
    this.numShareholdersChangeQoq,
    this.numShareholdersChangeYoy,
    this.cashFromOperations,
    this.cashFromInvesting,
    this.cashFromFinancing,
    this.plAnnual,
    this.bsAnnual,
    this.cfAnnual,
    this.shareholdingQuarterly,
    this.growthRanges,
    required this.scoreBreakdown,
    this.tags = const [],
    required this.whyRanked,
    this.metricInsights = const {},
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
      scoreQuality: (json['score_quality'] as num?)?.toDouble(),
      scoreInstitutional: (json['score_institutional'] as num?)?.toDouble(),
      scoreRisk: (json['score_risk'] as num?)?.toDouble(),
      sectorPercentile: (json['sector_percentile'] as num?)?.toDouble(),
      lynchClassification: json['lynch_classification'] as String?,
      pegRatio: (json['peg_ratio'] as num?)?.toDouble(),
      technicalScore: (json['technical_score'] as num?)?.toDouble(),
      rsi14: (json['rsi_14'] as num?)?.toDouble(),
      actionTag: json['action_tag'] as String?,
      actionTagReasoning: json['action_tag_reasoning'] as String?,
      scoreConfidence: json['score_confidence'] as String?,
      trendAlignment: json['trend_alignment'] as String?,
      breakoutSignal: json['breakout_signal'] as String?,
      salesGrowthYoy: (json['sales_growth_yoy'] as num?)?.toDouble(),
      profitGrowthYoy: (json['profit_growth_yoy'] as num?)?.toDouble(),
      compoundedSalesGrowth3y: (json['compounded_sales_growth_3y'] as num?)?.toDouble(),
      compoundedProfitGrowth3y: (json['compounded_profit_growth_3y'] as num?)?.toDouble(),
      opmChange: (json['opm_change'] as num?)?.toDouble(),
      interestCoverage: (json['interest_coverage'] as num?)?.toDouble(),
      numShareholdersChangeQoq: (json['num_shareholders_change_qoq'] as num?)?.toDouble(),
      numShareholdersChangeYoy: (json['num_shareholders_change_yoy'] as num?)?.toDouble(),
      cashFromOperations: (json['cash_from_operations'] as num?)?.toDouble(),
      cashFromInvesting: (json['cash_from_investing'] as num?)?.toDouble(),
      cashFromFinancing: (json['cash_from_financing'] as num?)?.toDouble(),
      plAnnual: json['pl_annual'] as Map<String, dynamic>?,
      bsAnnual: json['bs_annual'] as Map<String, dynamic>?,
      cfAnnual: json['cf_annual'] as Map<String, dynamic>?,
      shareholdingQuarterly: json['shareholding_quarterly'] as Map<String, dynamic>?,
      growthRanges: json['growth_ranges'] as Map<String, dynamic>?,
      scoreBreakdown: DiscoverStockScoreBreakdown.fromJson(
        (json['score_breakdown'] as Map<String, dynamic>? ?? const {}),
      ),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => TagV2.fromJson(e as Map<String, dynamic>))
          .toList(),
      whyRanked:
          (json['why_ranked'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      metricInsights: (json['metric_insights'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, MetricInsight.fromJson(v as Map<String, dynamic>)),
          ) ?? const {},
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
  final double? categoryFitScore;

  const DiscoverMutualFundScoreBreakdown({
    required this.returnScore,
    required this.riskScore,
    required this.costScore,
    required this.consistencyScore,
    this.alphaScore,
    this.betaScore,
    this.categoryFitScore,
  });

  factory DiscoverMutualFundScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return DiscoverMutualFundScoreBreakdown(
      returnScore: (json['performance_score'] as num?)?.toDouble() ?? (json['return_score'] as num?)?.toDouble() ?? 0,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0,
      costScore: (json['cost_score'] as num?)?.toDouble() ?? 0,
      consistencyScore: (json['consistency_score'] as num?)?.toDouble() ?? 0,
      alphaScore: (json['alpha_score'] as num?)?.toDouble(),
      betaScore: (json['beta_score'] as num?)?.toDouble(),
      categoryFitScore: (json['category_fit_score'] as num?)?.toDouble(),
    );
  }
}

@immutable
class MfTag {
  final String tag;
  final String sentiment; // positive, cautionary, negative, neutral
  final String? preset; // screener preset to navigate to

  const MfTag({
    required this.tag,
    required this.sentiment,
    this.preset,
  });

  factory MfTag.fromJson(Map<String, dynamic> json) {
    return MfTag(
      tag: json['tag'] as String? ?? '',
      sentiment: json['sentiment'] as String? ?? 'neutral',
      preset: json['preset'] as String?,
    );
  }
}

@immutable
class MfFundInsight {
  final String text;
  final String sentiment; // "positive", "negative", "neutral"

  const MfFundInsight({required this.text, required this.sentiment});

  factory MfFundInsight.fromJson(Map<String, dynamic> json) => MfFundInsight(
        text: json['text'] as String? ?? '',
        sentiment: json['sentiment'] as String? ?? 'neutral',
      );

  bool get isPositive => sentiment == 'positive';
  bool get isNegative => sentiment == 'negative';
}

@immutable
class MfHolding {
  final String name;
  final double percentage;
  final String? sector;

  const MfHolding({required this.name, required this.percentage, this.sector});

  factory MfHolding.fromJson(Map<String, dynamic> json) => MfHolding(
    name: json['name'] as String,
    percentage: (json['percentage'] as num).toDouble(),
    sector: json['sector'] as String?,
  );
}

@immutable
class MfSectorAlloc {
  final String sector;
  final double percentage;

  const MfSectorAlloc({required this.sector, required this.percentage});

  factory MfSectorAlloc.fromJson(Map<String, dynamic> json) => MfSectorAlloc(
    sector: json['sector'] as String,
    percentage: (json['percentage'] as num).toDouble(),
  );
}

@immutable
class MfAssetAllocation {
  final double equity;
  final double debt;
  final double cash;
  final double other;

  const MfAssetAllocation({
    required this.equity,
    required this.debt,
    required this.cash,
    required this.other,
  });

  factory MfAssetAllocation.fromJson(Map<String, dynamic> json) => MfAssetAllocation(
    equity: (json['equity_pct'] as num?)?.toDouble() ?? 0,
    debt: (json['debt_pct'] as num?)?.toDouble() ?? 0,
    cash: (json['cash_pct'] as num?)?.toDouble() ?? 0,
    other: (json['other_pct'] as num?)?.toDouble() ?? 0,
  );
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
  final List<MfTag> mfTags;
  final Map<String, dynamic>? metricInsights;
  final List<Map<String, dynamic>>? fundManagers;
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
  final double? scorePerformance;
  final double? scoreCategoryFit;
  final double? subCategoryPercentile;
  final String? fundClassification;
  final String? fundType;
  final DiscoverMutualFundScoreBreakdown scoreBreakdown;
  final List<String> whyRanked;
  final List<MfFundInsight> fundInsights;
  final String sourceStatus;
  final DateTime sourceTimestamp;
  final DateTime ingestedAt;
  final String? primarySource;
  final String? secondarySource;
  final List<MfHolding>? topHoldings;
  final List<MfSectorAlloc>? sectorAllocation;
  final MfAssetAllocation? assetAllocation;
  final String? holdingsAsOf;

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
    this.mfTags = const [],
    this.metricInsights,
    this.fundManagers,
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
    this.scorePerformance,
    this.scoreCategoryFit,
    this.subCategoryPercentile,
    this.fundClassification,
    this.fundType,
    required this.scoreBreakdown,
    required this.whyRanked,
    this.fundInsights = const [],
    required this.sourceStatus,
    required this.sourceTimestamp,
    required this.ingestedAt,
    required this.primarySource,
    required this.secondarySource,
    this.topHoldings,
    this.sectorAllocation,
    this.assetAllocation,
    this.holdingsAsOf,
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
      mfTags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((e) => MfTag.fromJson(e))
          .toList(),
      metricInsights: json['metric_insights'] as Map<String, dynamic>?,
      fundManagers: (json['fund_managers'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
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
      scorePerformance: (json['score_performance'] as num?)?.toDouble(),
      scoreCategoryFit: (json['score_category_fit'] as num?)?.toDouble(),
      subCategoryPercentile: (json['sub_category_percentile'] as num?)?.toDouble(),
      fundClassification: json['fund_classification'] as String?,
      fundType: json['fund_type'] as String?,
      scoreBreakdown: DiscoverMutualFundScoreBreakdown.fromJson(
        (json['score_breakdown'] as Map<String, dynamic>? ?? const {}),
      ),
      whyRanked:
          (json['why_ranked'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      fundInsights: (json['fund_insights'] as List<dynamic>? ?? const [])
          .map((e) => MfFundInsight.fromJson(e as Map<String, dynamic>))
          .toList(),
      sourceStatus: json['source_status'] as String? ?? 'limited',
      sourceTimestamp: DateTime.parse(json['source_timestamp'] as String),
      ingestedAt: DateTime.parse(json['ingested_at'] as String),
      primarySource: json['primary_source'] as String?,
      secondarySource: json['secondary_source'] as String?,
      topHoldings: (json['top_holdings'] as List<dynamic>?)
          ?.map((e) => MfHolding.fromJson(e as Map<String, dynamic>))
          .toList(),
      sectorAllocation: (json['sector_allocation'] as List<dynamic>?)
          ?.map((e) => MfSectorAlloc.fromJson(e as Map<String, dynamic>))
          .toList(),
      assetAllocation: json['asset_allocation'] != null
          ? MfAssetAllocation.fromJson(json['asset_allocation'] as Map<String, dynamic>)
          : null,
      holdingsAsOf: json['holdings_as_of'] as String?,
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
  final double? percentChange3m;
  final double score;

  const SearchStockResult({
    required this.symbol,
    required this.displayName,
    this.sector,
    required this.lastPrice,
    this.percentChange,
    this.percentChange3m,
    required this.score,
  });

  factory SearchStockResult.fromJson(Map<String, dynamic> json) {
    return SearchStockResult(
      symbol: json['symbol'] as String,
      displayName: json['display_name'] as String,
      sector: json['sector'] as String?,
      lastPrice: (json['last_price'] as num).toDouble(),
      percentChange: (json['percent_change'] as num?)?.toDouble(),
      percentChange3m: (json['percent_change_3m'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class SearchMfResult {
  final String schemeCode;
  final String schemeName;
  final String? displayName;
  final String? category;
  final double nav;
  final double? returns1y;
  final double score;

  const SearchMfResult({
    required this.schemeCode,
    required this.schemeName,
    this.displayName,
    this.category,
    required this.nav,
    this.returns1y,
    required this.score,
  });

  factory SearchMfResult.fromJson(Map<String, dynamic> json) {
    return SearchMfResult(
      schemeCode: json['scheme_code'] as String,
      schemeName: json['scheme_name'] as String,
      displayName: json['display_name'] as String?,
      category: json['category'] as String?,
      nav: (json['nav'] as num).toDouble(),
      returns1y: (json['returns_1y'] as num?)?.toDouble(),
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
  final String? industry;
  final double lastPrice;
  final double? percentChange;
  final double? percentChange3m;
  final double? percentChange1w;
  final double? percentChange1y;
  final double score;
  final double? scoreQuality;
  final double? scoreGrowth;
  final double? scoreValuation;
  final double? high52w;
  final double? low52w;
  final double? marketCap;
  final double? peRatio;
  final double? roe;
  final double? debtToEquity;
  final double? dividendYield;
  final String? actionTag;

  const DiscoverHomeStockItem({
    required this.symbol,
    required this.displayName,
    this.sector,
    this.industry,
    required this.lastPrice,
    this.percentChange,
    this.percentChange3m,
    this.percentChange1w,
    this.percentChange1y,
    required this.score,
    this.scoreQuality,
    this.scoreGrowth,
    this.scoreValuation,
    this.high52w,
    this.low52w,
    this.marketCap,
    this.peRatio,
    this.roe,
    this.debtToEquity,
    this.dividendYield,
    this.actionTag,
  });

  factory DiscoverHomeStockItem.fromJson(Map<String, dynamic> json) {
    return DiscoverHomeStockItem(
      symbol: json['symbol'] as String,
      displayName: json['display_name'] as String,
      sector: json['sector'] as String?,
      industry: json['industry'] as String?,
      lastPrice: (json['last_price'] as num).toDouble(),
      percentChange: (json['percent_change'] as num?)?.toDouble(),
      percentChange3m: (json['percent_change_3m'] as num?)?.toDouble(),
      percentChange1w: (json['percent_change_1w'] as num?)?.toDouble(),
      percentChange1y: (json['percent_change_1y'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      scoreQuality: (json['score_quality'] as num?)?.toDouble(),
      scoreGrowth: (json['score_growth'] as num?)?.toDouble(),
      scoreValuation: (json['score_valuation'] as num?)?.toDouble(),
      high52w: (json['high_52w'] as num?)?.toDouble(),
      low52w: (json['low_52w'] as num?)?.toDouble(),
      marketCap: (json['market_cap'] as num?)?.toDouble(),
      peRatio: (json['pe_ratio'] as num?)?.toDouble(),
      roe: (json['roe'] as num?)?.toDouble(),
      debtToEquity: (json['debt_to_equity'] as num?)?.toDouble(),
      dividendYield: (json['dividend_yield'] as num?)?.toDouble(),
      actionTag: json['action_tag'] as String?,
    );
  }
}

@immutable
class DiscoverHomeMfItem {
  final String schemeCode;
  final String schemeName;
  final String? displayName;
  final String? category;
  final String? fundClassification;
  final double score;
  final double? returns1y;
  final List<String> qualityBadges;

  const DiscoverHomeMfItem({
    required this.schemeCode,
    required this.schemeName,
    this.displayName,
    this.category,
    this.fundClassification,
    required this.score,
    this.returns1y,
    this.qualityBadges = const [],
  });

  /// Returns the best available label: fund_classification > category > ''.
  String get categoryLabel => fundClassification ?? category ?? '';

  factory DiscoverHomeMfItem.fromJson(Map<String, dynamic> json) {
    return DiscoverHomeMfItem(
      schemeCode: json['scheme_code'] as String,
      schemeName: json['scheme_name'] as String,
      displayName: json['display_name'] as String?,
      category: json['category'] as String?,
      fundClassification: json['fund_classification'] as String?,
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
class DiscoverHomeSection<T> {
  final String key;
  final String title;
  final String subtitle;
  final List<T> items;

  const DiscoverHomeSection({
    required this.key,
    required this.title,
    required this.subtitle,
    this.items = const [],
  });
}

@immutable
class DiscoverHomeData {
  final List<DiscoverHomeSection<DiscoverHomeStockItem>> stockSections;
  final List<DiscoverHomeSection<DiscoverHomeMfItem>> mfSections;
  final List<QuickCategory> quickCategories;

  const DiscoverHomeData({
    this.stockSections = const [],
    this.mfSections = const [],
    this.quickCategories = const [],
  });

  factory DiscoverHomeData.fromJson(Map<String, dynamic> json) {
    final stockSections = (json['stock_sections'] as List<dynamic>? ?? [])
        .map((s) {
      final sec = s as Map<String, dynamic>;
      return DiscoverHomeSection<DiscoverHomeStockItem>(
        key: sec['key'] as String,
        title: sec['title'] as String,
        subtitle: sec['subtitle'] as String,
        items: (sec['items'] as List<dynamic>? ?? [])
            .map((e) =>
                DiscoverHomeStockItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }).toList();

    final mfSections = (json['mf_sections'] as List<dynamic>? ?? [])
        .map((s) {
      final sec = s as Map<String, dynamic>;
      return DiscoverHomeSection<DiscoverHomeMfItem>(
        key: sec['key'] as String,
        title: sec['title'] as String,
        subtitle: sec['subtitle'] as String,
        items: (sec['items'] as List<dynamic>? ?? [])
            .map((e) =>
                DiscoverHomeMfItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }).toList();

    return DiscoverHomeData(
      stockSections: stockSections,
      mfSections: mfSections,
      quickCategories:
          (json['quick_categories'] as List<dynamic>? ?? const [])
              .map((e) => QuickCategory.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Score History
// ---------------------------------------------------------------------------

@immutable
class ScoreHistoryPoint {
  final DateTime scoredAt;
  final double score;

  const ScoreHistoryPoint({required this.scoredAt, required this.score});

  factory ScoreHistoryPoint.fromJson(Map<String, dynamic> json) {
    return ScoreHistoryPoint(
      scoredAt: DateTime.parse(json['scored_at'] as String),
      score: (json['score'] as num).toDouble(),
    );
  }
}

@immutable
class ScoreHistoryResponse {
  final String symbol;
  final List<ScoreHistoryPoint> points;
  final int count;

  const ScoreHistoryResponse({
    required this.symbol,
    this.points = const [],
    this.count = 0,
  });

  factory ScoreHistoryResponse.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List<dynamic>? ?? const [])
        .map((e) => ScoreHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return ScoreHistoryResponse(
      symbol: json['symbol'] as String? ?? '',
      points: pts,
      count: (json['count'] as num?)?.toInt() ?? pts.length,
    );
  }
}

// ---------------------------------------------------------------------------
// Stock Story
// ---------------------------------------------------------------------------

@immutable
class ScoreChange {
  final String layer;
  final double? oldValue;
  final double? newValue;
  final String direction; // "up" | "down" | "unchanged"

  const ScoreChange({
    required this.layer,
    this.oldValue,
    this.newValue,
    required this.direction,
  });

  factory ScoreChange.fromJson(Map<String, dynamic> json) {
    return ScoreChange(
      layer: json['layer'] as String? ?? '',
      oldValue: (json['old_value'] as num?)?.toDouble(),
      newValue: (json['new_value'] as num?)?.toDouble(),
      direction: json['direction'] as String? ?? 'unchanged',
    );
  }
}

@immutable
class StockStory {
  final String symbol;
  final String? verdict;
  final String? actionTag;
  final String? actionTagReasoning;
  final String? trendAlignment;
  final String? breakoutSignal;
  final String? lynchClassification;
  final String? whyNarrative;
  final String? scoreConfidence;
  final List<ScoreChange> scoreChanges;

  const StockStory({
    required this.symbol,
    this.verdict,
    this.actionTag,
    this.actionTagReasoning,
    this.trendAlignment,
    this.breakoutSignal,
    this.lynchClassification,
    this.whyNarrative,
    this.scoreConfidence,
    this.scoreChanges = const [],
  });

  factory StockStory.fromJson(Map<String, dynamic> json) {
    return StockStory(
      symbol: json['symbol'] as String? ?? '',
      verdict: json['verdict'] as String?,
      actionTag: json['action_tag'] as String?,
      actionTagReasoning: json['action_tag_reasoning'] as String?,
      trendAlignment: json['trend_alignment'] as String?,
      breakoutSignal: json['breakout_signal'] as String?,
      lynchClassification: json['lynch_classification'] as String?,
      whyNarrative: json['why_narrative'] as String?,
      scoreConfidence: json['score_confidence'] as String?,
      scoreChanges: (json['score_changes'] as List<dynamic>? ?? const [])
          .map((e) => ScoreChange.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock Compare
// ---------------------------------------------------------------------------

@immutable
class ComparisonDimension {
  final String metric;
  final String label;
  final List<double?> values;
  final int? winnerIndex;

  const ComparisonDimension({
    required this.metric,
    required this.label,
    required this.values,
    this.winnerIndex,
  });

  factory ComparisonDimension.fromJson(Map<String, dynamic> json) {
    return ComparisonDimension(
      metric: json['metric'] as String? ?? '',
      label: json['label'] as String? ?? '',
      values: (json['values'] as List<dynamic>? ?? const [])
          .map((e) => (e as num?)?.toDouble())
          .toList(),
      winnerIndex: (json['winner_index'] as num?)?.toInt(),
    );
  }
}

@immutable
class StockCompareResponse {
  final List<DiscoverStockItem> items;
  final List<ComparisonDimension> dimensions;

  const StockCompareResponse({
    this.items = const [],
    this.dimensions = const [],
  });

  factory StockCompareResponse.fromJson(Map<String, dynamic> json) {
    return StockCompareResponse(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => DiscoverStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      dimensions:
          (json['comparison_dimensions'] as List<dynamic>? ?? const [])
              .map((e) =>
                  ComparisonDimension.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Market Mood
// ---------------------------------------------------------------------------

@immutable
class MarketMood {
  final double? avgScore;
  final ScoreDistribution? scoreDistribution;
  final String? summary;

  const MarketMood({this.avgScore, this.scoreDistribution, this.summary});

  factory MarketMood.fromJson(Map<String, dynamic> json) {
    final dist = json['score_distribution'] as Map<String, dynamic>?;
    return MarketMood(
      avgScore: (json['avg_score'] as num?)?.toDouble(),
      scoreDistribution: dist != null ? ScoreDistribution.fromJson(dist) : null,
      summary: json['summary'] as String?,
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
