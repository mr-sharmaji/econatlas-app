import 'package:flutter/foundation.dart';

@immutable
class MacroCountrySummary {
  final String country;
  final String nowTitle;
  final String nowSubtitle;
  final double riskScore;
  final String riskLabel;
  final double? freshnessHours;
  final String? nextEventName;
  final DateTime? nextEventDate;
  final List<String> watchouts;

  const MacroCountrySummary({
    required this.country,
    required this.nowTitle,
    required this.nowSubtitle,
    required this.riskScore,
    required this.riskLabel,
    required this.freshnessHours,
    required this.nextEventName,
    required this.nextEventDate,
    required this.watchouts,
  });

  factory MacroCountrySummary.fromJson(Map<String, dynamic> json) {
    return MacroCountrySummary(
      country: json['country'] as String? ?? '',
      nowTitle: json['now_title'] as String? ?? '',
      nowSubtitle: json['now_subtitle'] as String? ?? '',
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0,
      riskLabel: json['risk_label'] as String? ?? '',
      freshnessHours: (json['freshness_hours'] as num?)?.toDouble(),
      nextEventName: json['next_event_name'] as String?,
      nextEventDate: json['next_event_date'] != null
          ? DateTime.tryParse(json['next_event_date'] as String)
          : null,
      watchouts: (json['watchouts'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

@immutable
class MacroSummaryResponse {
  final DateTime? asOf;
  final List<MacroCountrySummary> countries;
  final int count;

  const MacroSummaryResponse({
    required this.asOf,
    required this.countries,
    required this.count,
  });

  factory MacroSummaryResponse.fromJson(Map<String, dynamic> json) {
    return MacroSummaryResponse(
      asOf: json['as_of'] != null
          ? DateTime.tryParse(json['as_of'] as String)
          : null,
      countries: (json['countries'] as List<dynamic>? ?? const [])
          .map((e) => MacroCountrySummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
