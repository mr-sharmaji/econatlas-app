import 'package:flutter/foundation.dart';

@immutable
class ConverterFxSnapshot {
  final int version;
  final DateTime fetchedAt;
  final Map<String, double> ratesInrByCode;
  final int sourceCount;

  const ConverterFxSnapshot({
    required this.version,
    required this.fetchedAt,
    required this.ratesInrByCode,
    required this.sourceCount,
  });

  factory ConverterFxSnapshot.fromJson(Map<String, dynamic> json) {
    final rawRates = (json['rates_inr_by_code'] as Map<String, dynamic>? ?? {});
    final rates = <String, double>{};
    for (final entry in rawRates.entries) {
      final value = entry.value;
      if (value is num) {
        rates[entry.key.toUpperCase()] = value.toDouble();
      }
    }
    return ConverterFxSnapshot(
      version: (json['version'] as num?)?.toInt() ?? 1,
      fetchedAt: DateTime.parse(json['fetched_at'] as String).toUtc(),
      ratesInrByCode: rates,
      sourceCount: (json['source_count'] as num?)?.toInt() ?? rates.length,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
        'rates_inr_by_code': ratesInrByCode,
        'source_count': sourceCount,
      };
}
