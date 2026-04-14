import 'package:flutter/foundation.dart';

/// Brokerage rate for a single broker × segment combination.
@immutable
class BrokerSegmentRate {
  final String mode; // "free", "percent_cap", "flat"
  final double pct;
  final double cap;
  final double flat;
  final double minCharge;

  const BrokerSegmentRate({
    required this.mode,
    required this.pct,
    required this.cap,
    required this.flat,
    required this.minCharge,
  });

  factory BrokerSegmentRate.fromJson(Map<String, dynamic> json) =>
      BrokerSegmentRate(
        mode: json['mode'] as String? ?? 'flat',
        pct: (json['pct'] as num?)?.toDouble() ?? 0,
        cap: (json['cap'] as num?)?.toDouble() ?? 0,
        flat: (json['flat'] as num?)?.toDouble() ?? 0,
        minCharge: (json['min_charge'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'pct': pct,
        'cap': cap,
        'flat': flat,
        'min_charge': minCharge,
      };
}

/// Full broker preset including metadata and per-segment rates.
@immutable
class BrokerPreset {
  final String id;
  final String name;
  final String tagline;
  final double dpCharge;
  final bool dpIncludesGst;
  final double amcYearly;

  /// One-line AMC headline (e.g. "₹0 – ₹354/yr depending on account type").
  /// Empty when the backend hasn't populated it for this broker.
  final String amcNote;

  /// Full AMC rules (BSDA tiers, non-BSDA, first-year-free etc.) as a
  /// pre-split list — each entry renders as a bullet in the UI.
  final List<String> amcRules;

  final double accountOpeningFee;
  final double callTradeFee;
  final Map<String, BrokerSegmentRate> segments;

  const BrokerPreset({
    required this.id,
    required this.name,
    required this.tagline,
    required this.dpCharge,
    required this.dpIncludesGst,
    required this.amcYearly,
    required this.amcNote,
    required this.amcRules,
    required this.accountOpeningFee,
    required this.callTradeFee,
    required this.segments,
  });

  factory BrokerPreset.fromJson(String id, Map<String, dynamic> json) {
    final segs = <String, BrokerSegmentRate>{};
    final segMap = json['segments'] as Map<String, dynamic>? ?? {};
    for (final entry in segMap.entries) {
      segs[entry.key] =
          BrokerSegmentRate.fromJson(entry.value as Map<String, dynamic>);
    }
    final rules = <String>[];
    final rawRules = json['amc_rules'];
    if (rawRules is List) {
      for (final r in rawRules) {
        if (r is String && r.trim().isNotEmpty) rules.add(r);
      }
    }
    return BrokerPreset(
      id: id,
      name: json['name'] as String? ?? id,
      tagline: json['tagline'] as String? ?? '',
      dpCharge: (json['dp_charge'] as num?)?.toDouble() ?? 0,
      dpIncludesGst: json['dp_includes_gst'] as bool? ?? false,
      amcYearly: (json['amc_yearly'] as num?)?.toDouble() ?? 0,
      amcNote: json['amc_note'] as String? ?? '',
      amcRules: rules,
      accountOpeningFee:
          (json['account_opening_fee'] as num?)?.toDouble() ?? 0,
      callTradeFee: (json['call_trade_fee'] as num?)?.toDouble() ?? 0,
      segments: segs,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tagline': tagline,
        'dp_charge': dpCharge,
        'dp_includes_gst': dpIncludesGst,
        'amc_yearly': amcYearly,
        'amc_note': amcNote,
        'amc_rules': amcRules,
        'account_opening_fee': accountOpeningFee,
        'call_trade_fee': callTradeFee,
        'segments':
            segments.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// Statutory rates for a segment × exchange combination.
@immutable
class StatutoryRate {
  final double sttBuyRate;
  final double sttSellRate;
  final double exchangeTxnRate;
  final double stampDutyBuyRate;
  final double ipftRate;
  final double sebiFeeRate;
  final double gstRate;

  const StatutoryRate({
    required this.sttBuyRate,
    required this.sttSellRate,
    required this.exchangeTxnRate,
    required this.stampDutyBuyRate,
    required this.ipftRate,
    required this.sebiFeeRate,
    required this.gstRate,
  });

  factory StatutoryRate.fromJson(Map<String, dynamic> json) => StatutoryRate(
        sttBuyRate: (json['stt_buy_rate'] as num?)?.toDouble() ?? 0,
        sttSellRate: (json['stt_sell_rate'] as num?)?.toDouble() ?? 0,
        exchangeTxnRate:
            (json['exchange_txn_rate'] as num?)?.toDouble() ?? 0,
        stampDutyBuyRate:
            (json['stamp_duty_buy_rate'] as num?)?.toDouble() ?? 0,
        ipftRate: (json['ipft_rate'] as num?)?.toDouble() ?? 0,
        sebiFeeRate: (json['sebi_fee_rate'] as num?)?.toDouble() ?? 0.000001,
        gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 0.18,
      );

  Map<String, dynamic> toJson() => {
        'stt_buy_rate': sttBuyRate,
        'stt_sell_rate': sttSellRate,
        'exchange_txn_rate': exchangeTxnRate,
        'stamp_duty_buy_rate': stampDutyBuyRate,
        'ipft_rate': ipftRate,
        'sebi_fee_rate': sebiFeeRate,
        'gst_rate': gstRate,
      };
}

/// Full API response from GET /broker-charges.
@immutable
class BrokerChargesResponse {
  final Map<String, BrokerPreset> brokers;

  /// Nested: segment → exchange → StatutoryRate
  final Map<String, Map<String, StatutoryRate>> statutory;
  final String lastUpdated;

  const BrokerChargesResponse({
    required this.brokers,
    required this.statutory,
    required this.lastUpdated,
  });

  factory BrokerChargesResponse.fromJson(Map<String, dynamic> json) {
    // Parse brokers
    final brokersMap = <String, BrokerPreset>{};
    final brokersJson = json['brokers'] as Map<String, dynamic>? ?? {};
    for (final entry in brokersJson.entries) {
      brokersMap[entry.key] = BrokerPreset.fromJson(
        entry.key,
        entry.value as Map<String, dynamic>,
      );
    }

    // Parse statutory: { segment: { exchange: rates } }
    final statMap = <String, Map<String, StatutoryRate>>{};
    final statJson = json['statutory'] as Map<String, dynamic>? ?? {};
    for (final segEntry in statJson.entries) {
      final exchanges = <String, StatutoryRate>{};
      final exchJson = segEntry.value as Map<String, dynamic>? ?? {};
      for (final exchEntry in exchJson.entries) {
        exchanges[exchEntry.key] = StatutoryRate.fromJson(
          exchEntry.value as Map<String, dynamic>,
        );
      }
      statMap[segEntry.key] = exchanges;
    }

    return BrokerChargesResponse(
      brokers: brokersMap,
      statutory: statMap,
      lastUpdated: json['last_updated'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'brokers': brokers.map((k, v) => MapEntry(k, v.toJson())),
        'statutory': statutory.map(
          (seg, exchanges) => MapEntry(
            seg,
            exchanges.map((exch, rate) => MapEntry(exch, rate.toJson())),
          ),
        ),
        'last_updated': lastUpdated,
      };
}
