import 'package:flutter/foundation.dart';

@immutable
class WatchlistResponse {
  final String deviceId;
  final List<String> assets;
  final int count;

  const WatchlistResponse({
    required this.deviceId,
    required this.assets,
    required this.count,
  });

  factory WatchlistResponse.fromJson(Map<String, dynamic> json) =>
      WatchlistResponse(
        deviceId: json['device_id'] as String,
        assets: (json['assets'] as List<dynamic>).map((e) => '$e').toList(),
        count: json['count'] as int,
      );
}
