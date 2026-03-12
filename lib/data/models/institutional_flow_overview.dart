import 'package:flutter/foundation.dart';

@immutable
class InstitutionalFlowTrendPoint {
  final DateTime sessionDate;
  final double? fiiValue;
  final double? diiValue;
  final double combinedValue;
  final DateTime? asOf;

  const InstitutionalFlowTrendPoint({
    required this.sessionDate,
    required this.fiiValue,
    required this.diiValue,
    required this.combinedValue,
    required this.asOf,
  });

  factory InstitutionalFlowTrendPoint.fromJson(Map<String, dynamic> json) =>
      InstitutionalFlowTrendPoint(
        sessionDate: DateTime.parse(json['session_date'] as String),
        fiiValue: (json['fii_value'] as num?)?.toDouble(),
        diiValue: (json['dii_value'] as num?)?.toDouble(),
        combinedValue: (json['combined_value'] as num).toDouble(),
        asOf: json['as_of'] != null
            ? DateTime.tryParse(json['as_of'] as String)
            : null,
      );
}

@immutable
class InstitutionalFlowsOverview {
  final DateTime? asOf;
  final double? fiiValue;
  final double? diiValue;
  final double? combinedValue;
  final List<InstitutionalFlowTrendPoint> trend;

  const InstitutionalFlowsOverview({
    required this.asOf,
    required this.fiiValue,
    required this.diiValue,
    required this.combinedValue,
    required this.trend,
  });

  factory InstitutionalFlowsOverview.fromJson(Map<String, dynamic> json) =>
      InstitutionalFlowsOverview(
        asOf: json['as_of'] != null
            ? DateTime.tryParse(json['as_of'] as String)
            : null,
        fiiValue: (json['fii_value'] as num?)?.toDouble(),
        diiValue: (json['dii_value'] as num?)?.toDouble(),
        combinedValue: (json['combined_value'] as num?)?.toDouble(),
        trend: (json['trend'] as List<dynamic>? ?? const [])
            .map((e) =>
                InstitutionalFlowTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
