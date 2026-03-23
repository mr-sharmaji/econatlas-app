import 'package:flutter/foundation.dart';

@immutable
class EconCalendarEvent {
  final String eventName;
  final String institution;
  final DateTime eventDate;
  final String country;
  final String eventType;
  final String? description;
  final String? source;

  const EconCalendarEvent({
    required this.eventName,
    required this.institution,
    required this.eventDate,
    required this.country,
    required this.eventType,
    this.description,
    this.source,
  });

  factory EconCalendarEvent.fromJson(Map<String, dynamic> json) {
    return EconCalendarEvent(
      eventName: json['event_name'] as String,
      institution: json['institution'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      country: json['country'] as String,
      eventType: json['event_type'] as String,
      description: json['description'] as String?,
      source: json['source'] as String?,
    );
  }
}

class EconCalendarResponse {
  final List<EconCalendarEvent> events;
  final int count;

  const EconCalendarResponse({required this.events, required this.count});

  factory EconCalendarResponse.fromJson(Map<String, dynamic> json) {
    return EconCalendarResponse(
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => EconCalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
