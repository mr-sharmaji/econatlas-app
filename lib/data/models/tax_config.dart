import 'package:flutter/foundation.dart';

@immutable
class TaxFinancialYear {
  final String id;
  final String label;

  const TaxFinancialYear({
    required this.id,
    required this.label,
  });

  factory TaxFinancialYear.fromJson(Map<String, dynamic> json) {
    return TaxFinancialYear(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
      };
}

@immutable
class TaxCalculatorMeta {
  final String key;
  final String title;
  final String subtitle;
  final bool visible;
  final int order;

  const TaxCalculatorMeta({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.visible,
    required this.order,
  });

  factory TaxCalculatorMeta.fromJson(Map<String, dynamic> json) {
    return TaxCalculatorMeta(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      visible: json['visible'] as bool? ?? true,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'subtitle': subtitle,
        'visible': visible,
        'order': order,
      };
}

@immutable
class TaxRoundingPolicy {
  final int currencyScale;
  final int percentageScale;
  final String taxRounding;

  const TaxRoundingPolicy({
    required this.currencyScale,
    required this.percentageScale,
    required this.taxRounding,
  });

  factory TaxRoundingPolicy.fromJson(Map<String, dynamic> json) {
    return TaxRoundingPolicy(
      currencyScale: (json['currency_scale'] as num?)?.toInt() ?? 2,
      percentageScale: (json['percentage_scale'] as num?)?.toInt() ?? 2,
      taxRounding: json['tax_rounding'] as String? ?? 'nearest_rupee',
    );
  }

  Map<String, dynamic> toJson() => {
        'currency_scale': currencyScale,
        'percentage_scale': percentageScale,
        'tax_rounding': taxRounding,
      };
}

@immutable
class TaxSlab {
  final double upperLimit;
  final double rate;

  const TaxSlab({
    required this.upperLimit,
    required this.rate,
  });

  factory TaxSlab.fromJson(Map<String, dynamic> json) {
    return TaxSlab(
      upperLimit: (json['upper_limit'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'upper_limit': upperLimit,
        'rate': rate,
      };
}

@immutable
class IncomeTaxRebateRule {
  final double threshold;
  final double maxRebate;
  final bool residentOnly;
  final bool marginalRelief;

  const IncomeTaxRebateRule({
    required this.threshold,
    required this.maxRebate,
    required this.residentOnly,
    required this.marginalRelief,
  });

  factory IncomeTaxRebateRule.fromJson(Map<String, dynamic> json) {
    return IncomeTaxRebateRule(
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
      maxRebate: (json['max_rebate'] as num?)?.toDouble() ?? 0.0,
      residentOnly: json['resident_only'] as bool? ?? true,
      marginalRelief: json['marginal_relief'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'threshold': threshold,
        'max_rebate': maxRebate,
        'resident_only': residentOnly,
        'marginal_relief': marginalRelief,
      };
}

@immutable
class IncomeTaxSurchargeRule {
  final double threshold;
  final double rate;

  const IncomeTaxSurchargeRule({
    required this.threshold,
    required this.rate,
  });

  factory IncomeTaxSurchargeRule.fromJson(Map<String, dynamic> json) {
    return IncomeTaxSurchargeRule(
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'threshold': threshold,
        'rate': rate,
      };
}

@immutable
class IncomeTaxRules {
  final Map<String, double> standardDeduction;
  final Map<String, double> oldBasicExemption;
  final List<TaxSlab> oldSlabs;
  final List<TaxSlab> newSlabs;
  final Map<String, IncomeTaxRebateRule> rebate;
  final Map<String, List<IncomeTaxSurchargeRule>> surcharge;
  final double cessRate;

  const IncomeTaxRules({
    required this.standardDeduction,
    required this.oldBasicExemption,
    required this.oldSlabs,
    required this.newSlabs,
    required this.rebate,
    required this.surcharge,
    required this.cessRate,
  });

  factory IncomeTaxRules.fromJson(Map<String, dynamic> json) {
    final standardDeduction = <String, double>{};
    final standardRaw =
        (json['standard_deduction'] as Map<String, dynamic>? ?? {});
    for (final entry in standardRaw.entries) {
      final v = entry.value;
      if (v is num) standardDeduction[entry.key] = v.toDouble();
    }

    final oldBasicExemption = <String, double>{};
    final oldBasicRaw =
        (json['old_basic_exemption'] as Map<String, dynamic>? ?? {});
    for (final entry in oldBasicRaw.entries) {
      final v = entry.value;
      if (v is num) oldBasicExemption[entry.key] = v.toDouble();
    }

    final rebateMap = <String, IncomeTaxRebateRule>{};
    final rebateRaw = (json['rebate'] as Map<String, dynamic>? ?? {});
    for (final entry in rebateRaw.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        rebateMap[entry.key] = IncomeTaxRebateRule.fromJson(value);
      }
    }

    final surchargeMap = <String, List<IncomeTaxSurchargeRule>>{};
    final surchargeRaw = (json['surcharge'] as Map<String, dynamic>? ?? {});
    for (final entry in surchargeRaw.entries) {
      final value = entry.value;
      if (value is List<dynamic>) {
        surchargeMap[entry.key] = value
            .map((e) =>
                IncomeTaxSurchargeRule.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    return IncomeTaxRules(
      standardDeduction: standardDeduction,
      oldBasicExemption: oldBasicExemption,
      oldSlabs: ((json['old_slabs'] as List<dynamic>? ?? const <dynamic>[]))
          .map((e) => TaxSlab.fromJson(e as Map<String, dynamic>))
          .toList(),
      newSlabs: ((json['new_slabs'] as List<dynamic>? ?? const <dynamic>[]))
          .map((e) => TaxSlab.fromJson(e as Map<String, dynamic>))
          .toList(),
      rebate: rebateMap,
      surcharge: surchargeMap,
      cessRate: (json['cess_rate'] as num?)?.toDouble() ?? 0.04,
    );
  }

  Map<String, dynamic> toJson() => {
        'standard_deduction': standardDeduction,
        'old_basic_exemption': oldBasicExemption,
        'old_slabs': oldSlabs.map((e) => e.toJson()).toList(),
        'new_slabs': newSlabs.map((e) => e.toJson()).toList(),
        'rebate': rebate.map((k, v) => MapEntry(k, v.toJson())),
        'surcharge': surcharge.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
        'cess_rate': cessRate,
      };
}

@immutable
class CapitalGainsAssetRule {
  final int holdingPeriodMonths;
  final double stcgRate;
  final double ltcgRate;
  final double ltcgExemption;
  final String section;
  final String stcgMode;
  final String ltcgMode;
  final bool alwaysShortTerm;
  final String note;

  const CapitalGainsAssetRule({
    required this.holdingPeriodMonths,
    required this.stcgRate,
    required this.ltcgRate,
    required this.ltcgExemption,
    required this.section,
    required this.stcgMode,
    required this.ltcgMode,
    required this.alwaysShortTerm,
    required this.note,
  });

  factory CapitalGainsAssetRule.fromJson(Map<String, dynamic> json) {
    return CapitalGainsAssetRule(
      holdingPeriodMonths:
          (json['holding_period_months'] as num?)?.toInt() ?? 0,
      stcgRate: (json['stcg_rate'] as num?)?.toDouble() ?? 0.0,
      ltcgRate: (json['ltcg_rate'] as num?)?.toDouble() ?? 0.0,
      ltcgExemption: (json['ltcg_exemption'] as num?)?.toDouble() ?? 0.0,
      section: json['section'] as String? ?? '',
      stcgMode: json['stcg_mode'] as String? ?? 'fixed',
      ltcgMode: json['ltcg_mode'] as String? ?? 'fixed',
      alwaysShortTerm: json['always_short_term'] as bool? ?? false,
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'holding_period_months': holdingPeriodMonths,
        'stcg_rate': stcgRate,
        'ltcg_rate': ltcgRate,
        'ltcg_exemption': ltcgExemption,
        'section': section,
        'stcg_mode': stcgMode,
        'ltcg_mode': ltcgMode,
        'always_short_term': alwaysShortTerm,
        'note': note,
      };
}

@immutable
class CapitalGainsRules {
  final Map<String, CapitalGainsAssetRule> assets;

  const CapitalGainsRules({
    required this.assets,
  });

  factory CapitalGainsRules.fromJson(Map<String, dynamic> json) {
    final assets = <String, CapitalGainsAssetRule>{};
    final raw = (json['assets'] as Map<String, dynamic>? ?? {});
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is Map<String, dynamic>) {
        assets[entry.key] = CapitalGainsAssetRule.fromJson(v);
      }
    }
    return CapitalGainsRules(assets: assets);
  }

  Map<String, dynamic> toJson() => {
        'assets': assets.map((k, v) => MapEntry(k, v.toJson())),
      };
}

@immutable
class AdvanceTaxInstallment {
  final String label;
  final String dueDate;
  final double cumulativePercent;

  const AdvanceTaxInstallment({
    required this.label,
    required this.dueDate,
    required this.cumulativePercent,
  });

  factory AdvanceTaxInstallment.fromJson(Map<String, dynamic> json) {
    return AdvanceTaxInstallment(
      label: json['label'] as String? ?? '',
      dueDate: json['due_date'] as String? ?? '',
      cumulativePercent:
          (json['cumulative_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'due_date': dueDate,
        'cumulative_percent': cumulativePercent,
      };
}

@immutable
class AdvanceTaxRules {
  final List<AdvanceTaxInstallment> installments;
  final double interestRate234c;
  final double interestRate234b;
  final double interestThreshold;

  const AdvanceTaxRules({
    required this.installments,
    required this.interestRate234c,
    required this.interestRate234b,
    required this.interestThreshold,
  });

  factory AdvanceTaxRules.fromJson(Map<String, dynamic> json) {
    return AdvanceTaxRules(
      installments: ((json['installments'] as List<dynamic>? ??
              const <dynamic>[]))
          .map((e) => AdvanceTaxInstallment.fromJson(e as Map<String, dynamic>))
          .toList(),
      interestRate234c:
          (json['interest_rate_234c'] as num?)?.toDouble() ?? 0.01,
      interestRate234b:
          (json['interest_rate_234b'] as num?)?.toDouble() ?? 0.01,
      interestThreshold:
          (json['interest_threshold'] as num?)?.toDouble() ?? 10000,
    );
  }

  Map<String, dynamic> toJson() => {
        'installments': installments.map((e) => e.toJson()).toList(),
        'interest_rate_234c': interestRate234c,
        'interest_rate_234b': interestRate234b,
        'interest_threshold': interestThreshold,
      };
}

@immutable
class TdsSectionRule {
  final String section;
  final String label;
  final double rate;
  final double threshold;
  final bool residentOnly;

  const TdsSectionRule({
    required this.section,
    required this.label,
    required this.rate,
    required this.threshold,
    required this.residentOnly,
  });

  factory TdsSectionRule.fromJson(Map<String, dynamic> json) {
    return TdsSectionRule(
      section: json['section'] as String? ?? '',
      label: json['label'] as String? ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
      residentOnly: json['resident_only'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'section': section,
        'label': label,
        'rate': rate,
        'threshold': threshold,
        'resident_only': residentOnly,
      };
}

@immutable
class TdsSubTypeRule {
  final String value;
  final String label;
  final double rateIndividual;
  final double rateOther;
  final double rateNoPan;

  const TdsSubTypeRule({
    required this.value,
    required this.label,
    required this.rateIndividual,
    required this.rateOther,
    required this.rateNoPan,
  });

  factory TdsSubTypeRule.fromJson(Map<String, dynamic> json) {
    return TdsSubTypeRule(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
      rateIndividual: (json['rate_individual'] as num?)?.toDouble() ?? 0.0,
      rateOther: (json['rate_other'] as num?)?.toDouble() ?? 0.0,
      rateNoPan: (json['rate_no_pan'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'label': label,
        'rate_individual': rateIndividual,
        'rate_other': rateOther,
        'rate_no_pan': rateNoPan,
      };
}

@immutable
class TdsPaymentTypeRule {
  final String value;
  final String sectionCode;
  final String label;
  final String description;
  final double threshold;
  final double? thresholdIndividual;
  final double? thresholdOther;
  final bool alwaysApply;
  final double rateIndividual;
  final double rateOther;
  final double rateNoPan;
  final List<TdsSubTypeRule> subTypeOptions;

  const TdsPaymentTypeRule({
    required this.value,
    required this.sectionCode,
    required this.label,
    required this.description,
    required this.threshold,
    required this.thresholdIndividual,
    required this.thresholdOther,
    required this.alwaysApply,
    required this.rateIndividual,
    required this.rateOther,
    required this.rateNoPan,
    required this.subTypeOptions,
  });

  factory TdsPaymentTypeRule.fromJson(Map<String, dynamic> json) {
    final subtypes =
        ((json['sub_type_options'] as List<dynamic>? ?? const <dynamic>[]))
            .map((e) => TdsSubTypeRule.fromJson(e as Map<String, dynamic>))
            .where((row) => row.value.trim().isNotEmpty)
            .toList(growable: false);
    return TdsPaymentTypeRule(
      value: json['value'] as String? ?? '',
      sectionCode: json['section_code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
      thresholdIndividual: (json['threshold_individual'] as num?)?.toDouble(),
      thresholdOther: (json['threshold_other'] as num?)?.toDouble(),
      alwaysApply: json['always_apply'] as bool? ?? false,
      rateIndividual: (json['rate_individual'] as num?)?.toDouble() ?? 0.0,
      rateOther: (json['rate_other'] as num?)?.toDouble() ?? 0.0,
      rateNoPan: (json['rate_no_pan'] as num?)?.toDouble() ?? 0.0,
      subTypeOptions: subtypes,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'section_code': sectionCode,
        'label': label,
        'description': description,
        'threshold': threshold,
        'threshold_individual': thresholdIndividual,
        'threshold_other': thresholdOther,
        'always_apply': alwaysApply,
        'rate_individual': rateIndividual,
        'rate_other': rateOther,
        'rate_no_pan': rateNoPan,
        'sub_type_options': subTypeOptions.map((e) => e.toJson()).toList(),
      };
}

@immutable
class TdsDefaults {
  final String pan;
  final String recipient;
  final String fees194j;

  const TdsDefaults({
    required this.pan,
    required this.recipient,
    required this.fees194j,
  });

  factory TdsDefaults.fromJson(Map<String, dynamic> json) {
    return TdsDefaults(
      pan: json['pan'] as String? ?? 'yes',
      recipient: json['recipient'] as String? ?? 'individual',
      fees194j: json['fees194j'] as String? ?? 'others',
    );
  }

  Map<String, dynamic> toJson() => {
        'pan': pan,
        'recipient': recipient,
        'fees194j': fees194j,
      };
}

@immutable
class TdsRules {
  final List<TdsSectionRule> sections;
  final List<TdsPaymentTypeRule> paymentTypes;
  final TdsDefaults defaults;

  const TdsRules({
    required this.sections,
    required this.paymentTypes,
    required this.defaults,
  });

  factory TdsRules.fromJson(Map<String, dynamic> json) {
    return TdsRules(
      sections: ((json['sections'] as List<dynamic>? ?? const <dynamic>[]))
          .map((e) => TdsSectionRule.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      paymentTypes: ((json['payment_types'] as List<dynamic>? ??
              const <dynamic>[]))
          .map((e) => TdsPaymentTypeRule.fromJson(e as Map<String, dynamic>))
          .where((row) => row.value.trim().isNotEmpty)
          .toList(growable: false),
      defaults:
          TdsDefaults.fromJson(json['defaults'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'sections': sections.map((e) => e.toJson()).toList(),
        'payment_types': paymentTypes.map((e) => e.toJson()).toList(),
        'defaults': defaults.toJson(),
      };
}

@immutable
class TaxRuleSet {
  final IncomeTaxRules incomeTax;
  final CapitalGainsRules capitalGains;
  final AdvanceTaxRules advanceTax;
  final TdsRules tds;

  const TaxRuleSet({
    required this.incomeTax,
    required this.capitalGains,
    required this.advanceTax,
    required this.tds,
  });

  factory TaxRuleSet.fromJson(Map<String, dynamic> json) {
    return TaxRuleSet(
      incomeTax: IncomeTaxRules.fromJson(
          json['income_tax'] as Map<String, dynamic>? ?? {}),
      capitalGains: CapitalGainsRules.fromJson(
          json['capital_gains'] as Map<String, dynamic>? ?? {}),
      advanceTax: AdvanceTaxRules.fromJson(
          json['advance_tax'] as Map<String, dynamic>? ?? {}),
      tds: TdsRules.fromJson(json['tds'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'income_tax': incomeTax.toJson(),
        'capital_gains': capitalGains.toJson(),
        'advance_tax': advanceTax.toJson(),
        'tds': tds.toJson(),
      };
}

@immutable
class TaxHelperPoints {
  final List<String> hub;
  final List<String> incomeTax;
  final List<String> capitalGains;
  final List<String> advanceTax;
  final List<String> tds;

  const TaxHelperPoints({
    required this.hub,
    required this.incomeTax,
    required this.capitalGains,
    required this.advanceTax,
    required this.tds,
  });

  factory TaxHelperPoints.fromJson(Map<String, dynamic> json) {
    List<String> toList(String key) {
      final raw = json[key];
      if (raw is! List<dynamic>) return const [];
      return raw
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    return TaxHelperPoints(
      hub: toList('hub'),
      incomeTax: toList('income_tax'),
      capitalGains: toList('capital_gains'),
      advanceTax: toList('advance_tax'),
      tds: toList('tds'),
    );
  }

  Map<String, dynamic> toJson() => {
        'hub': hub,
        'income_tax': incomeTax,
        'capital_gains': capitalGains,
        'advance_tax': advanceTax,
        'tds': tds,
      };
}

@immutable
class TaxConfig {
  final String version;
  final String hash;
  final List<TaxFinancialYear> supportedFy;
  final String defaultFy;
  final DateTime? lastSyncedAt;
  final String disclaimer;
  final TaxHelperPoints helperPoints;
  final TaxRoundingPolicy roundingPolicy;
  final Map<String, TaxRuleSet> rulesByFy;

  const TaxConfig({
    required this.version,
    required this.hash,
    required this.supportedFy,
    required this.defaultFy,
    required this.lastSyncedAt,
    required this.disclaimer,
    required this.helperPoints,
    required this.roundingPolicy,
    required this.rulesByFy,
  });

  factory TaxConfig.fromJson(Map<String, dynamic> json) {
    final rulesByFy = <String, TaxRuleSet>{};
    final rulesRaw = (json['rules_by_fy'] as Map<String, dynamic>? ?? {});
    for (final entry in rulesRaw.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        rulesByFy[entry.key] = TaxRuleSet.fromJson(value);
      }
    }
    final supportedFy =
        ((json['supported_fy'] as List<dynamic>? ?? const <dynamic>[]))
            .map((e) => TaxFinancialYear.fromJson(e as Map<String, dynamic>))
            .toList();
    final rawDefaultFy = (json['default_fy'] as String? ?? '').trim();
    final resolvedDefaultFy = rawDefaultFy.isNotEmpty
        ? rawDefaultFy
        : supportedFy.isNotEmpty
            ? supportedFy.first.id
            : rulesByFy.isNotEmpty
                ? rulesByFy.keys.first
                : '';
    if (resolvedDefaultFy.isEmpty) {
      throw const FormatException('Tax config missing default_fy and rules.');
    }
    return TaxConfig(
      version: json['version'] as String? ?? 'bundled',
      hash: json['hash'] as String? ?? '',
      supportedFy: supportedFy,
      defaultFy: resolvedDefaultFy,
      lastSyncedAt:
          DateTime.tryParse((json['last_synced_at'] as String?) ?? ''),
      disclaimer: json['disclaimer'] as String? ??
          'Indicative estimate only. Verify with official rules before filing.',
      helperPoints: TaxHelperPoints.fromJson(
          json['helper_points'] as Map<String, dynamic>? ?? {}),
      roundingPolicy: TaxRoundingPolicy.fromJson(
          json['rounding_policy'] as Map<String, dynamic>? ?? {}),
      rulesByFy: rulesByFy,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'hash': hash,
        'supported_fy': supportedFy.map((e) => e.toJson()).toList(),
        'default_fy': defaultFy,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'disclaimer': disclaimer,
        'helper_points': helperPoints.toJson(),
        'rounding_policy': roundingPolicy.toJson(),
        'rules_by_fy': rulesByFy.map((k, v) => MapEntry(k, v.toJson())),
      };

  TaxRuleSet ruleSetFor(String fy) {
    final direct = rulesByFy[fy];
    if (direct != null) return direct;
    final fallback = rulesByFy[defaultFy];
    if (fallback != null) return fallback;
    if (rulesByFy.isEmpty) {
      throw StateError('Tax config has no rule sets.');
    }
    return rulesByFy.values.first;
  }
}
