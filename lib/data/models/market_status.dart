import 'package:flutter/foundation.dart';

@immutable
class MarketStatus {
  final bool nseOpen;
  final bool nyseOpen;
  final bool giftNiftyOpen;
  final bool indiaOpen;
  final bool usOpen;
  final bool europeOpen;
  final bool japanOpen;
  final bool fxOpen;
  final bool commoditiesOpen;
  final bool live;

  const MarketStatus({
    required this.nseOpen,
    required this.nyseOpen,
    required this.giftNiftyOpen,
    required this.indiaOpen,
    required this.usOpen,
    required this.europeOpen,
    required this.japanOpen,
    required this.fxOpen,
    required this.commoditiesOpen,
    required this.live,
  });

  factory MarketStatus.fromJson(Map<String, dynamic> json) => MarketStatus(
        nseOpen: json['nse_open'] as bool? ?? false,
        nyseOpen: json['nyse_open'] as bool? ?? false,
        giftNiftyOpen: json['gift_nifty_open'] as bool? ?? false,
        indiaOpen: json['india_open'] as bool? ?? false,
        usOpen: json['us_open'] as bool? ?? false,
        europeOpen: json['europe_open'] as bool? ?? false,
        japanOpen: json['japan_open'] as bool? ?? false,
        fxOpen: json['fx_open'] as bool? ?? false,
        commoditiesOpen: json['commodities_open'] as bool? ?? false,
        live: json['live'] as bool? ?? false,
      );
}
