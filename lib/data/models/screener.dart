import 'package:flutter/foundation.dart';

@immutable
class ScreenerItem {
  final String asset;
  final String instrumentType;
  final String region;
  final String exchange;
  final double price;
  final double? changePercent;
  final double score;
  final List<String> signalTags;
  final String? marketPhase;
  final bool? isStale;
  final DateTime? lastTickTimestamp;
  final String? dataQuality;
  final String? changeWindow;
  final String? benchmarkAsset;
  final double? benchmarkChangePercent;
  final double? relativeStrength;

  const ScreenerItem({
    required this.asset,
    required this.instrumentType,
    required this.region,
    required this.exchange,
    required this.price,
    required this.score,
    required this.signalTags,
    this.changePercent,
    this.marketPhase,
    this.isStale,
    this.lastTickTimestamp,
    this.dataQuality,
    this.changeWindow,
    this.benchmarkAsset,
    this.benchmarkChangePercent,
    this.relativeStrength,
  });

  factory ScreenerItem.fromJson(Map<String, dynamic> json) => ScreenerItem(
        asset: json['asset'] as String,
        instrumentType: json['instrument_type'] as String,
        region: json['region'] as String,
        exchange: json['exchange'] as String,
        price: (json['price'] as num).toDouble(),
        changePercent: (json['change_percent'] as num?)?.toDouble(),
        score: (json['score'] as num).toDouble(),
        signalTags:
            (json['signal_tags'] as List<dynamic>).map((e) => '$e').toList(),
        marketPhase: json['market_phase'] as String?,
        isStale: json['is_stale'] as bool?,
        lastTickTimestamp: json['last_tick_timestamp'] != null
            ? DateTime.tryParse(json['last_tick_timestamp'] as String)
            : null,
        dataQuality: json['data_quality'] as String?,
        changeWindow: json['change_window'] as String?,
        benchmarkAsset: json['benchmark_asset'] as String?,
        benchmarkChangePercent:
            (json['benchmark_change_percent'] as num?)?.toDouble(),
        relativeStrength: (json['relative_strength'] as num?)?.toDouble(),
      );
}

@immutable
class ScreenerResponse {
  final String preset;
  final String? region;
  final String? instrumentType;
  final double minQuality;
  final List<ScreenerItem> items;
  final int count;

  const ScreenerResponse({
    required this.preset,
    required this.minQuality,
    required this.items,
    required this.count,
    this.region,
    this.instrumentType,
  });

  factory ScreenerResponse.fromJson(Map<String, dynamic> json) =>
      ScreenerResponse(
        preset: json['preset'] as String,
        region: json['region'] as String?,
        instrumentType: json['instrument_type'] as String?,
        minQuality: (json['min_quality'] as num?)?.toDouble() ?? 0.0,
        items: (json['items'] as List<dynamic>)
            .map((e) => ScreenerItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
      );
}
