import 'package:flutter/foundation.dart';

@immutable
class MacroForecast {
  final String indicatorName;
  final String country;
  final int forecastYear;
  final double value;
  final String? source;
  final DateTime? fetchedAt;

  const MacroForecast({
    required this.indicatorName,
    required this.country,
    required this.forecastYear,
    required this.value,
    this.source,
    this.fetchedAt,
  });

  factory MacroForecast.fromJson(Map<String, dynamic> json) {
    return MacroForecast(
      indicatorName: json['indicator_name'] as String,
      country: json['country'] as String,
      forecastYear: (json['forecast_year'] as num).toInt(),
      value: (json['value'] as num).toDouble(),
      source: json['source'] as String?,
      fetchedAt: json['fetched_at'] != null
          ? DateTime.tryParse(json['fetched_at'] as String)
          : null,
    );
  }
}

class MacroForecastResponse {
  final List<MacroForecast> forecasts;
  final int count;

  const MacroForecastResponse({required this.forecasts, required this.count});

  factory MacroForecastResponse.fromJson(Map<String, dynamic> json) {
    return MacroForecastResponse(
      forecasts: (json['forecasts'] as List<dynamic>? ?? [])
          .map((e) => MacroForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
