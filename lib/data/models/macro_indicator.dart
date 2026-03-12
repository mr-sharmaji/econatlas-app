import 'package:flutter/foundation.dart';

@immutable
class MacroIndicator {
  final String id;
  final String indicatorName;
  final double value;
  final String country;
  final DateTime timestamp;

  const MacroIndicator({
    required this.id,
    required this.indicatorName,
    required this.value,
    required this.country,
    required this.timestamp,
  });

  factory MacroIndicator.fromJson(Map<String, dynamic> json) => MacroIndicator(
        id: json['id'] as String,
        indicatorName: json['indicator_name'] as String,
        value: (json['value'] as num).toDouble(),
        country: json['country'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'indicator_name': indicatorName,
        'value': value,
        'country': country,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroIndicator &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MacroIndicator(name: $indicatorName, value: $value, country: $country)';
}

@immutable
class MacroResponse {
  final List<MacroIndicator> indicators;
  final int count;

  const MacroResponse({required this.indicators, required this.count});

  factory MacroResponse.fromJson(Map<String, dynamic> json) => MacroResponse(
        indicators: (json['indicators'] as List<dynamic>)
            .map((e) => MacroIndicator.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
      );
}
