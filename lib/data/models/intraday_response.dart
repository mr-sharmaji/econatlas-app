import 'package:flutter/foundation.dart';

@immutable
class IntradayPoint {
  final DateTime timestamp;
  final double price;

  const IntradayPoint({required this.timestamp, required this.price});

  factory IntradayPoint.fromJson(Map<String, dynamic> json) => IntradayPoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        price: (json['price'] as num).toDouble(),
      );
}

@immutable
class IntradayResponse {
  final List<IntradayPoint> prices;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final int? coverageMinutes;
  final int? expectedMinutes;
  final String? dataMode;

  const IntradayResponse({
    required this.prices,
    this.windowStart,
    this.windowEnd,
    this.coverageMinutes,
    this.expectedMinutes,
    this.dataMode,
  });

  factory IntradayResponse.fromJson(Map<String, dynamic> json) =>
      IntradayResponse(
        prices: (json['prices'] as List<dynamic>)
            .map((e) => IntradayPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        windowStart: json['window_start'] != null
            ? DateTime.tryParse(json['window_start'] as String)
            : null,
        windowEnd: json['window_end'] != null
            ? DateTime.tryParse(json['window_end'] as String)
            : null,
        coverageMinutes: json['coverage_minutes'] as int?,
        expectedMinutes: json['expected_minutes'] as int?,
        dataMode: json['data_mode'] as String?,
      );
}
