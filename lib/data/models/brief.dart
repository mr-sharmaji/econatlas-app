import 'package:flutter/foundation.dart';

@immutable
class BriefStockItem {
  final String symbol;
  final String displayName;
  final String market;
  final double lastPrice;
  final double? pointChange;
  final double? percentChange;
  final int? volume;
  final double? tradedValue;
  final String? sector;
  final DateTime sourceTimestamp;
  final DateTime ingestedAt;

  const BriefStockItem({
    required this.symbol,
    required this.displayName,
    required this.market,
    required this.lastPrice,
    this.pointChange,
    this.percentChange,
    this.volume,
    this.tradedValue,
    this.sector,
    required this.sourceTimestamp,
    required this.ingestedAt,
  });

  factory BriefStockItem.fromJson(Map<String, dynamic> json) => BriefStockItem(
        symbol: json['symbol'] as String,
        displayName: json['display_name'] as String,
        market: json['market'] as String,
        lastPrice: (json['last_price'] as num).toDouble(),
        pointChange: (json['point_change'] as num?)?.toDouble(),
        percentChange: (json['percent_change'] as num?)?.toDouble(),
        volume: (json['volume'] as num?)?.toInt(),
        tradedValue: (json['traded_value'] as num?)?.toDouble(),
        sector: json['sector'] as String?,
        sourceTimestamp: DateTime.parse(json['source_timestamp'] as String),
        ingestedAt: DateTime.parse(json['ingested_at'] as String),
      );
}

@immutable
class BriefStockListResponse {
  final String market;
  final DateTime? asOf;
  final List<BriefStockItem> items;
  final int count;

  const BriefStockListResponse({
    required this.market,
    required this.asOf,
    required this.items,
    required this.count,
  });

  factory BriefStockListResponse.fromJson(Map<String, dynamic> json) =>
      BriefStockListResponse(
        market: json['market'] as String,
        asOf: json['as_of'] != null
            ? DateTime.tryParse(json['as_of'] as String)
            : null,
        items: (json['items'] as List<dynamic>)
            .map((e) => BriefStockItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
      );
}

@immutable
class BriefSectorItem {
  final String sector;
  final double avgChangePercent;
  final int gainers;
  final int losers;
  final int count;

  const BriefSectorItem({
    required this.sector,
    required this.avgChangePercent,
    required this.gainers,
    required this.losers,
    required this.count,
  });

  factory BriefSectorItem.fromJson(Map<String, dynamic> json) => BriefSectorItem(
        sector: json['sector'] as String,
        avgChangePercent: (json['avg_change_percent'] as num).toDouble(),
        gainers: (json['gainers'] as num).toInt(),
        losers: (json['losers'] as num).toInt(),
        count: (json['count'] as num).toInt(),
      );
}

@immutable
class BriefSectorPulseResponse {
  final String market;
  final DateTime? asOf;
  final List<BriefSectorItem> sectors;
  final int count;

  const BriefSectorPulseResponse({
    required this.market,
    required this.asOf,
    required this.sectors,
    required this.count,
  });

  factory BriefSectorPulseResponse.fromJson(Map<String, dynamic> json) =>
      BriefSectorPulseResponse(
        market: json['market'] as String,
        asOf: json['as_of'] != null
            ? DateTime.tryParse(json['as_of'] as String)
            : null,
        sectors: (json['sectors'] as List<dynamic>)
            .map((e) => BriefSectorItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
      );
}

@immutable
class PostMarketOverview {
  final String market;
  final DateTime? asOf;
  final int totalStocks;
  final int advancers;
  final int decliners;
  final int unchanged;
  final double? avgChangePercent;
  final String? topSector;
  final String? bottomSector;
  final String summary;
  final List<String> driverTags;

  const PostMarketOverview({
    required this.market,
    required this.asOf,
    required this.totalStocks,
    required this.advancers,
    required this.decliners,
    required this.unchanged,
    required this.avgChangePercent,
    required this.topSector,
    required this.bottomSector,
    required this.summary,
    required this.driverTags,
  });

  factory PostMarketOverview.fromJson(Map<String, dynamic> json) =>
      PostMarketOverview(
        market: json['market'] as String,
        asOf: json['as_of'] != null
            ? DateTime.tryParse(json['as_of'] as String)
            : null,
        totalStocks: (json['total_stocks'] as num).toInt(),
        advancers: (json['advancers'] as num).toInt(),
        decliners: (json['decliners'] as num).toInt(),
        unchanged: (json['unchanged'] as num).toInt(),
        avgChangePercent: (json['avg_change_percent'] as num?)?.toDouble(),
        topSector: json['top_sector'] as String?,
        bottomSector: json['bottom_sector'] as String?,
        summary: json['summary'] as String,
        driverTags: (json['driver_tags'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );
}
