import 'package:flutter/foundation.dart';

@immutable
class EconomicEvent {
  final String id;
  final String eventType;
  final String entity;
  final String impact;
  final double confidence;
  final DateTime createdAt;

  const EconomicEvent({
    required this.id,
    required this.eventType,
    required this.entity,
    required this.impact,
    required this.confidence,
    required this.createdAt,
  });

  factory EconomicEvent.fromJson(Map<String, dynamic> json) {
    return EconomicEvent(
      id: json['id'] as String,
      eventType: json['event_type'] as String? ?? '',
      entity: json['entity'] as String? ?? '',
      impact: json['impact'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class EconomicEventListResponse {
  final List<EconomicEvent> events;
  final int count;

  const EconomicEventListResponse({required this.events, required this.count});

  factory EconomicEventListResponse.fromJson(Map<String, dynamic> json) {
    return EconomicEventListResponse(
      events: (json['events'] as List<dynamic>? ?? const [])
          .map((e) => EconomicEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
