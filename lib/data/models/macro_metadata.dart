import 'package:flutter/foundation.dart';

@immutable
class MacroIndicatorMetadata {
  final String indicatorName;
  final String displayName;
  final String helperText;
  final String unit;
  final String frequency;
  final String source;
  final String updateCadence;
  final String chartType;
  final Map<String, double> thresholds;

  const MacroIndicatorMetadata({
    required this.indicatorName,
    required this.displayName,
    required this.helperText,
    required this.unit,
    required this.frequency,
    required this.source,
    required this.updateCadence,
    required this.chartType,
    required this.thresholds,
  });

  factory MacroIndicatorMetadata.fromJson(Map<String, dynamic> json) {
    final raw = json['thresholds'] as Map<String, dynamic>? ?? const {};
    return MacroIndicatorMetadata(
      indicatorName: json['indicator_name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      helperText: json['helper_text'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      source: json['source'] as String? ?? '',
      updateCadence: json['update_cadence'] as String? ?? '',
      chartType: json['chart_type'] as String? ?? '',
      thresholds: raw.map(
        (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0),
      ),
    );
  }
}

@immutable
class MacroMetadataResponse {
  final List<MacroIndicatorMetadata> items;
  final int count;

  const MacroMetadataResponse({required this.items, required this.count});

  factory MacroMetadataResponse.fromJson(Map<String, dynamic> json) {
    return MacroMetadataResponse(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
              (e) => MacroIndicatorMetadata.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
