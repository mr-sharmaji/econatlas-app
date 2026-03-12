import 'package:flutter/foundation.dart';

@immutable
class IpoItem {
  final String symbol;
  final String companyName;
  final String market;
  final String status;
  final String ipoType;
  final double? issueSizeCr;
  final String? priceBand;
  final double? gmpPercent;
  final double? subscriptionMultiple;
  final double? listingPrice;
  final double? listingGainPct;
  final String? outcomeState;
  final DateTime? openDate;
  final DateTime? closeDate;
  final DateTime? listingDate;
  final DateTime? sourceTimestamp;
  final String recommendation;
  final String recommendationReason;

  const IpoItem({
    required this.symbol,
    required this.companyName,
    required this.market,
    required this.status,
    required this.ipoType,
    required this.issueSizeCr,
    required this.priceBand,
    required this.gmpPercent,
    required this.subscriptionMultiple,
    required this.listingPrice,
    required this.listingGainPct,
    required this.outcomeState,
    required this.openDate,
    required this.closeDate,
    required this.listingDate,
    required this.sourceTimestamp,
    required this.recommendation,
    required this.recommendationReason,
  });

  factory IpoItem.fromJson(Map<String, dynamic> json) => IpoItem(
        symbol: json['symbol'] as String,
        companyName: json['company_name'] as String,
        market: json['market'] as String? ?? 'IN',
        status: json['status'] as String,
        ipoType: json['ipo_type'] as String,
        issueSizeCr: (json['issue_size_cr'] as num?)?.toDouble(),
        priceBand: json['price_band'] as String?,
        gmpPercent: (json['gmp_percent'] as num?)?.toDouble(),
        subscriptionMultiple:
            (json['subscription_multiple'] as num?)?.toDouble(),
        listingPrice: (json['listing_price'] as num?)?.toDouble(),
        listingGainPct: (json['listing_gain_pct'] as num?)?.toDouble(),
        outcomeState: json['outcome_state'] as String?,
        openDate: json['open_date'] != null
            ? DateTime.tryParse(json['open_date'] as String)
            : null,
        closeDate: json['close_date'] != null
            ? DateTime.tryParse(json['close_date'] as String)
            : null,
        listingDate: json['listing_date'] != null
            ? DateTime.tryParse(json['listing_date'] as String)
            : null,
        sourceTimestamp: json['source_timestamp'] != null
            ? DateTime.tryParse(json['source_timestamp'] as String)
            : null,
        recommendation: json['recommendation'] as String? ?? 'watch',
        recommendationReason: json['recommendation_reason'] as String? ?? '',
      );
}

@immutable
class IpoListResponse {
  final String status;
  final DateTime? asOf;
  final List<IpoItem> items;
  final int count;

  const IpoListResponse({
    required this.status,
    required this.asOf,
    required this.items,
    required this.count,
  });

  factory IpoListResponse.fromJson(Map<String, dynamic> json) =>
      IpoListResponse(
        status: json['status'] as String,
        asOf: json['as_of'] != null
            ? DateTime.tryParse(json['as_of'] as String)
            : null,
        items: (json['items'] as List<dynamic>)
            .map((e) => IpoItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: (json['count'] as num).toInt(),
      );
}

@immutable
class IpoAlertsResponse {
  final String deviceId;
  final List<String> symbols;
  final int count;

  const IpoAlertsResponse({
    required this.deviceId,
    required this.symbols,
    required this.count,
  });

  factory IpoAlertsResponse.fromJson(Map<String, dynamic> json) =>
      IpoAlertsResponse(
        deviceId: json['device_id'] as String,
        symbols: (json['symbols'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        count: (json['count'] as num).toInt(),
      );
}
