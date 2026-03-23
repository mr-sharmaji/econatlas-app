import 'package:flutter/foundation.dart';

@immutable
class MacroRegimeCountry {
  final String country;
  final double? growthScore;
  final double? inflationScore;
  final double? policyScore;
  final String regimeLabel;
  final double confidence;
  final double? freshnessHours;
  final Map<String, double> metrics;

  const MacroRegimeCountry({
    required this.country,
    required this.growthScore,
    required this.inflationScore,
    required this.policyScore,
    required this.regimeLabel,
    required this.confidence,
    required this.freshnessHours,
    required this.metrics,
  });

  factory MacroRegimeCountry.fromJson(Map<String, dynamic> json) {
    final raw = json['metrics'] as Map<String, dynamic>? ?? const {};
    return MacroRegimeCountry(
      country: json['country'] as String? ?? '',
      growthScore: (json['growth_score'] as num?)?.toDouble(),
      inflationScore: (json['inflation_score'] as num?)?.toDouble(),
      policyScore: (json['policy_score'] as num?)?.toDouble(),
      regimeLabel: json['regime_label'] as String? ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      freshnessHours: (json['freshness_hours'] as num?)?.toDouble(),
      metrics: raw.map(
        (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0),
      ),
    );
  }
}

@immutable
class MacroRegimeResponse {
  final DateTime? asOf;
  final List<MacroRegimeCountry> countries;
  final int count;

  const MacroRegimeResponse({
    required this.asOf,
    required this.countries,
    required this.count,
  });

  factory MacroRegimeResponse.fromJson(Map<String, dynamic> json) {
    return MacroRegimeResponse(
      asOf: json['as_of'] != null
          ? DateTime.tryParse(json['as_of'] as String)
          : null,
      countries: (json['countries'] as List<dynamic>? ?? const [])
          .map((e) => MacroRegimeCountry.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
