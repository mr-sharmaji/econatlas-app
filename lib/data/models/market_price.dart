import 'package:flutter/foundation.dart';

@immutable
class MarketPrice {
  final String id;
  final String asset;
  final double price;
  final DateTime timestamp;
  final String source;
  final String instrumentType;
  final String unit;
  final double? changePercent;
  final double? previousClose;
  final DateTime? lastTickTimestamp;
  final DateTime? ingestedAt;
  final bool? isStale;
  final String? marketPhase;
  final String? changeWindow;
  final String? dataQuality;
  final bool? isPredictive;
  final String? sessionSource;
  final String? region;
  final String? exchange;
  final String? sessionPolicy;
  final String? tradableType;

  const MarketPrice({
    required this.id,
    required this.asset,
    required this.price,
    required this.timestamp,
    required this.source,
    required this.instrumentType,
    required this.unit,
    this.changePercent,
    this.previousClose,
    this.lastTickTimestamp,
    this.ingestedAt,
    this.isStale,
    this.marketPhase,
    this.changeWindow,
    this.dataQuality,
    this.isPredictive,
    this.sessionSource,
    this.region,
    this.exchange,
    this.sessionPolicy,
    this.tradableType,
  });

  factory MarketPrice.fromJson(Map<String, dynamic> json) => MarketPrice(
        id: json['id'] as String,
        asset: json['asset'] as String,
        price: (json['price'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        source: json['source'] as String? ?? '',
        instrumentType: json['instrument_type'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        changePercent: (json['change_percent'] as num?)?.toDouble(),
        previousClose: (json['previous_close'] as num?)?.toDouble(),
        lastTickTimestamp: json['last_tick_timestamp'] != null
            ? DateTime.tryParse(json['last_tick_timestamp'] as String)
            : null,
        ingestedAt: json['ingested_at'] != null
            ? DateTime.tryParse(json['ingested_at'] as String)
            : null,
        isStale: json['is_stale'] as bool?,
        marketPhase: json['market_phase'] as String?,
        changeWindow: json['change_window'] as String?,
        dataQuality: json['data_quality'] as String?,
        isPredictive: json['is_predictive'] as bool?,
        sessionSource: json['session_source'] as String?,
        region: json['region'] as String?,
        exchange: json['exchange'] as String?,
        sessionPolicy: json['session_policy'] as String?,
        tradableType: json['tradable_type'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'asset': asset,
        'price': price,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'instrument_type': instrumentType,
        'unit': unit,
        'change_percent': changePercent,
        'previous_close': previousClose,
        'last_tick_timestamp': lastTickTimestamp?.toIso8601String(),
        'ingested_at': ingestedAt?.toIso8601String(),
        'is_stale': isStale,
        'market_phase': marketPhase,
        'change_window': changeWindow,
        'data_quality': dataQuality,
        'is_predictive': isPredictive,
        'session_source': sessionSource,
        'region': region,
        'exchange': exchange,
        'session_policy': sessionPolicy,
        'tradable_type': tradableType,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketPrice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class MarketStory {
  final String asset;
  final String instrumentType;
  final String? verdict;
  final String? actionTag;
  final String? actionTagReasoning;
  final double? scoreTrend;
  final double? scoreVolatility;
  final double? scoreMomentum;
  final List<String> driverTags;
  final Map<String, dynamic>? typeExtras;
  final DateTime? computedAt;

  const MarketStory({
    required this.asset,
    required this.instrumentType,
    this.verdict,
    this.actionTag,
    this.actionTagReasoning,
    this.scoreTrend,
    this.scoreVolatility,
    this.scoreMomentum,
    this.driverTags = const [],
    this.typeExtras,
    this.computedAt,
  });

  factory MarketStory.fromJson(Map<String, dynamic> json) {
    return MarketStory(
      asset: json['asset'] as String,
      instrumentType: json['instrument_type'] as String,
      verdict: json['verdict'] as String?,
      actionTag: json['action_tag'] as String?,
      actionTagReasoning: json['action_tag_reasoning'] as String?,
      scoreTrend: (json['score_trend'] as num?)?.toDouble(),
      scoreVolatility: (json['score_volatility'] as num?)?.toDouble(),
      scoreMomentum: (json['score_momentum'] as num?)?.toDouble(),
      driverTags: (json['driver_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      typeExtras: json['type_extras'] as Map<String, dynamic>?,
      computedAt: json['computed_at'] != null
          ? DateTime.tryParse(json['computed_at'] as String)
          : null,
    );
  }
}

@immutable
class MarketPriceResponse {
  final List<MarketPrice> prices;
  final int count;

  const MarketPriceResponse({required this.prices, required this.count});

  factory MarketPriceResponse.fromJson(Map<String, dynamic> json) =>
      MarketPriceResponse(
        prices: (json['prices'] as List<dynamic>)
            .map((e) => MarketPrice.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
      );
}
