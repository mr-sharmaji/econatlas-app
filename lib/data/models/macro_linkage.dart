import 'package:flutter/foundation.dart';

@immutable
class MacroLinkagePoint {
  final DateTime date;
  final double macroValue;
  final double assetValue;

  const MacroLinkagePoint({
    required this.date,
    required this.macroValue,
    required this.assetValue,
  });

  factory MacroLinkagePoint.fromJson(Map<String, dynamic> json) {
    return MacroLinkagePoint(
      date: DateTime.parse(json['date'] as String),
      macroValue: (json['macro_value'] as num).toDouble(),
      assetValue: (json['asset_value'] as num).toDouble(),
    );
  }
}

@immutable
class MacroLinkageSeries {
  final String asset;
  final double? correlation;
  final int pointCount;
  final List<MacroLinkagePoint> points;

  const MacroLinkageSeries({
    required this.asset,
    required this.correlation,
    required this.pointCount,
    required this.points,
  });

  factory MacroLinkageSeries.fromJson(Map<String, dynamic> json) {
    return MacroLinkageSeries(
      asset: json['asset'] as String? ?? '',
      correlation: (json['correlation'] as num?)?.toDouble(),
      pointCount: (json['point_count'] as num?)?.toInt() ?? 0,
      points: (json['points'] as List<dynamic>? ?? const [])
          .map((e) => MacroLinkagePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@immutable
class MacroLinkagesResponse {
  final String country;
  final String indicatorName;
  final int windowDays;
  final DateTime? asOf;
  final List<MacroLinkageSeries> series;
  final int count;

  const MacroLinkagesResponse({
    required this.country,
    required this.indicatorName,
    required this.windowDays,
    required this.asOf,
    required this.series,
    required this.count,
  });

  factory MacroLinkagesResponse.fromJson(Map<String, dynamic> json) {
    return MacroLinkagesResponse(
      country: json['country'] as String? ?? '',
      indicatorName: json['indicator_name'] as String? ?? '',
      windowDays: (json['window_days'] as num?)?.toInt() ?? 0,
      asOf: json['as_of'] != null
          ? DateTime.tryParse(json['as_of'] as String)
          : null,
      series: (json['series'] as List<dynamic>? ?? const [])
          .map((e) => MacroLinkageSeries.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
