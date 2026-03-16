import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kStarredKey = 'starred_discover_items';

@immutable
class StarredItem {
  /// "stock" or "mf"
  final String type;

  /// Stock symbol or MF scheme code.
  final String id;

  /// Human-readable display name.
  final String name;

  /// Epoch millis when starred.
  final int timestamp;

  const StarredItem({
    required this.type,
    required this.id,
    required this.name,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'name': name,
        'timestamp': timestamp,
      };

  factory StarredItem.fromJson(Map<String, dynamic> json) {
    return StarredItem(
      type: json['type'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      timestamp: json['timestamp'] as int,
    );
  }
}

class StarredStocksService {
  final SharedPreferences _prefs;

  StarredStocksService(this._prefs);

  List<StarredItem> load() {
    final raw = _prefs.getString(_kStarredKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StarredItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<StarredItem>> toggle({
    required String type,
    required String id,
    required String name,
  }) async {
    final items = load();
    final existingIdx = items.indexWhere((e) => e.type == type && e.id == id);

    if (existingIdx >= 0) {
      items.removeAt(existingIdx);
    } else {
      items.insert(
        0,
        StarredItem(
          type: type,
          id: id,
          name: name,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    await _prefs.setString(
      _kStarredKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );

    return items;
  }

  bool isStarred({required String type, required String id}) {
    return load().any((e) => e.type == type && e.id == id);
  }
}
