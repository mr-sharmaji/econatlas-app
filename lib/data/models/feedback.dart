import 'package:flutter/foundation.dart';

@immutable
class FeedbackSubmitResponse {
  final String id;
  final String status;
  final DateTime createdAt;

  const FeedbackSubmitResponse({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  factory FeedbackSubmitResponse.fromJson(Map<String, dynamic> json) =>
      FeedbackSubmitResponse(
        id: (json['id'] as String? ?? '').trim(),
        status: (json['status'] as String? ?? '').trim(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

@immutable
class FeedbackSubmission {
  final String id;
  final String deviceId;
  final String category;
  final String message;
  final String? appVersion;
  final String? platform;
  final String status;
  final DateTime createdAt;

  const FeedbackSubmission({
    required this.id,
    required this.deviceId,
    required this.category,
    required this.message,
    this.appVersion,
    this.platform,
    required this.status,
    required this.createdAt,
  });

  factory FeedbackSubmission.fromJson(Map<String, dynamic> json) =>
      FeedbackSubmission(
        id: (json['id'] as String? ?? '').trim(),
        deviceId: (json['device_id'] as String? ?? '').trim(),
        category: (json['category'] as String? ?? '').trim(),
        message: (json['message'] as String? ?? '').trim(),
        appVersion: (json['app_version'] as String?)?.trim(),
        platform: (json['platform'] as String?)?.trim(),
        status: (json['status'] as String? ?? 'received').trim(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

@immutable
class FeedbackListResponse {
  final List<FeedbackSubmission> entries;
  final int count;

  const FeedbackListResponse({
    required this.entries,
    required this.count,
  });

  factory FeedbackListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['entries'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => FeedbackSubmission.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return FeedbackListResponse(
      entries: items,
      count: (json['count'] as num?)?.toInt() ?? items.length,
    );
  }
}
