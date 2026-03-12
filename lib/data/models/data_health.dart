import 'package:flutter/foundation.dart';

@immutable
class HealthBucket {
  final int total;
  final int live;
  final int stale;
  final int closed;
  final double? avgLatencySeconds;

  const HealthBucket({
    required this.total,
    required this.live,
    required this.stale,
    required this.closed,
    this.avgLatencySeconds,
  });

  factory HealthBucket.fromJson(Map<String, dynamic> json) => HealthBucket(
        total: json['total'] as int? ?? 0,
        live: json['live'] as int? ?? 0,
        stale: json['stale'] as int? ?? 0,
        closed: json['closed'] as int? ?? 0,
        avgLatencySeconds: (json['avg_latency_seconds'] as num?)?.toDouble(),
      );
}

@immutable
class DataHealthResponse {
  final DateTime timestamp;
  final int totalAssets;
  final int staleAssets;
  final double? avgLatencySeconds;
  final Map<String, HealthBucket> byRegion;
  final Map<String, HealthBucket> byInstrumentType;
  final Map<String, int> qualityCounts;

  const DataHealthResponse({
    required this.timestamp,
    required this.totalAssets,
    required this.staleAssets,
    required this.byRegion,
    required this.byInstrumentType,
    required this.qualityCounts,
    this.avgLatencySeconds,
  });

  factory DataHealthResponse.fromJson(Map<String, dynamic> json) =>
      DataHealthResponse(
        timestamp: DateTime.parse(json['timestamp'] as String),
        totalAssets: json['total_assets'] as int? ?? 0,
        staleAssets: json['stale_assets'] as int? ?? 0,
        avgLatencySeconds: (json['avg_latency_seconds'] as num?)?.toDouble(),
        byRegion: (json['by_region'] as Map<String, dynamic>? ?? {}).map(
            (k, v) =>
                MapEntry(k, HealthBucket.fromJson(v as Map<String, dynamic>))),
        byInstrumentType:
            (json['by_instrument_type'] as Map<String, dynamic>? ?? {}).map((k,
                    v) =>
                MapEntry(k, HealthBucket.fromJson(v as Map<String, dynamic>))),
        qualityCounts: (json['quality_counts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}
