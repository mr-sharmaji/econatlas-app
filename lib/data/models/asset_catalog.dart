import 'package:flutter/foundation.dart';

@immutable
class AssetCatalogItem {
  final String asset;
  final String instrumentType;
  final String symbol;
  final String region;
  final String exchange;
  final String sessionPolicy;
  final int priorityRank;
  final String tradableType;
  final String unit;
  final bool defaultWatchlist;
  final String? benchmarkAsset;

  const AssetCatalogItem({
    required this.asset,
    required this.instrumentType,
    required this.symbol,
    required this.region,
    required this.exchange,
    required this.sessionPolicy,
    required this.priorityRank,
    required this.tradableType,
    required this.unit,
    required this.defaultWatchlist,
    this.benchmarkAsset,
  });

  factory AssetCatalogItem.fromJson(Map<String, dynamic> json) =>
      AssetCatalogItem(
        asset: json['asset'] as String,
        instrumentType: json['instrument_type'] as String,
        symbol: json['symbol'] as String,
        region: json['region'] as String,
        exchange: json['exchange'] as String,
        sessionPolicy: json['session_policy'] as String,
        priorityRank: json['priority_rank'] as int,
        tradableType: json['tradable_type'] as String,
        unit: json['unit'] as String,
        defaultWatchlist: json['default_watchlist'] as bool? ?? false,
        benchmarkAsset: json['benchmark_asset'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'asset': asset,
        'instrument_type': instrumentType,
        'symbol': symbol,
        'region': region,
        'exchange': exchange,
        'session_policy': sessionPolicy,
        'priority_rank': priorityRank,
        'tradable_type': tradableType,
        'unit': unit,
        'default_watchlist': defaultWatchlist,
        'benchmark_asset': benchmarkAsset,
      };
}

@immutable
class AssetCatalogResponse {
  final List<AssetCatalogItem> assets;
  final int count;

  const AssetCatalogResponse({required this.assets, required this.count});

  factory AssetCatalogResponse.fromJson(Map<String, dynamic> json) =>
      AssetCatalogResponse(
        assets: (json['assets'] as List<dynamic>)
            .map((e) => AssetCatalogItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
      );

  Map<String, dynamic> toJson() => {
        'assets': assets.map((a) => a.toJson()).toList(),
        'count': count,
      };
}
