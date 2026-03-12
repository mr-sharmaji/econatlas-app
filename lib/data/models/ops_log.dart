import 'package:flutter/foundation.dart';

@immutable
class OpsLogEntry {
  final int id;
  final DateTime timestamp;
  final String level;
  final String logger;
  final String message;
  final String? module;
  final String? functionName;
  final int? line;
  final String? exception;

  const OpsLogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.logger,
    required this.message,
    this.module,
    this.functionName,
    this.line,
    this.exception,
  });

  factory OpsLogEntry.fromJson(Map<String, dynamic> json) => OpsLogEntry(
        id: (json['id'] as num).toInt(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: (json['level'] as String? ?? 'INFO').trim(),
        logger: (json['logger'] as String? ?? '').trim(),
        message: (json['message'] as String? ?? '').trim(),
        module: (json['module'] as String?)?.trim(),
        functionName: (json['function'] as String?)?.trim(),
        line: (json['line'] as num?)?.toInt(),
        exception: (json['exception'] as String?)?.trim(),
      );
}

@immutable
class OpsLogListResponse {
  final List<OpsLogEntry> entries;
  final int count;
  final int latestId;

  const OpsLogListResponse({
    required this.entries,
    required this.count,
    required this.latestId,
  });

  factory OpsLogListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['entries'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => OpsLogEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return OpsLogListResponse(
      entries: items,
      count: (json['count'] as num?)?.toInt() ?? items.length,
      latestId: (json['latest_id'] as num?)?.toInt() ?? 0,
    );
  }
}
