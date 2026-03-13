import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kRecentlyViewedKey = 'recently_viewed_discover';
const _kMaxItems = 10;

@immutable
class RecentlyViewedItem {
  /// "stock" or "mf"
  final String type;

  /// Stock symbol or MF scheme code.
  final String id;

  /// Human-readable display name.
  final String name;

  /// Epoch millis when the item was last viewed.
  final int timestamp;

  const RecentlyViewedItem({
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

  factory RecentlyViewedItem.fromJson(Map<String, dynamic> json) {
    return RecentlyViewedItem(
      type: json['type'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      timestamp: json['timestamp'] as int,
    );
  }
}

class RecentlyViewedService {
  final SharedPreferences _prefs;

  RecentlyViewedService(this._prefs);

  List<RecentlyViewedItem> load() {
    final raw = _prefs.getString(_kRecentlyViewedKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RecentlyViewedItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<RecentlyViewedItem>> addItem({
    required String type,
    required String id,
    required String name,
  }) async {
    final items = load();

    // Remove existing entry for the same item (dedup by type+id).
    items.removeWhere((e) => e.type == type && e.id == id);

    // Insert at front.
    items.insert(
      0,
      RecentlyViewedItem(
        type: type,
        id: id,
        name: name,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    // Cap at max.
    final capped = items.length > _kMaxItems ? items.sublist(0, _kMaxItems) : items;

    await _prefs.setString(
      _kRecentlyViewedKey,
      jsonEncode(capped.map((e) => e.toJson()).toList()),
    );

    return capped;
  }

  Future<void> clear() async {
    await _prefs.remove(_kRecentlyViewedKey);
  }
}
