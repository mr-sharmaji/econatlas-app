import 'dart:math' as math;

import '../../../../data/models/tax_config.dart';

enum TaxRegime { old, newRegime }

enum AgeBucket { below60, age60to80, above80 }

class IncomeTaxResult {
  final double salary;
  final double deductionsUsed;
  final double taxableIncome;
  final double standardDeduction;
  final double baseTax;
  final double rebate;
  final double surcharge;
  final double cess;
  final double totalTax;
  final double effectiveRate;
  final double netIncome;
  final double monthlyNetIncome;

  const IncomeTaxResult({
    required this.salary,
    required this.deductionsUsed,
    required this.taxableIncome,
    required this.standardDeduction,
    required this.baseTax,
    required this.rebate,
    required this.surcharge,
    required this.cess,
    required this.totalTax,
    required this.effectiveRate,
    required this.netIncome,
    required this.monthlyNetIncome,
  });
}

class CapitalGainsResult {
  final double buyValue;
  final double sellValue;
  final double gain;
  final bool isLongTerm;
  final double taxableGain;
  final double tax;
  final double netGain;
  final String section;
  final double appliedRate;
  final String note;

  const CapitalGainsResult({
    required this.buyValue,
    required this.sellValue,
    required this.gain,
    required this.isLongTerm,
    required this.taxableGain,
    required this.tax,
    required this.netGain,
    required this.section,
    required this.appliedRate,
    required this.note,
  });
}

class AdvanceTaxInstallmentBreakdown {
  final String label;
  final String dueDate;
  final double cumulativePercent;
  final double cumulativeTarget;
  final double shortfall;

  const AdvanceTaxInstallmentBreakdown({
    required this.label,
    required this.dueDate,
    required this.cumulativePercent,
    required this.cumulativeTarget,
    required this.shortfall,
  });
}

class AdvanceTaxResult {
  final double totalLiability;
  final double paidTillNow;
  final List<AdvanceTaxInstallmentBreakdown> installments;
  final double currentTarget;
  final double currentShortfall;
  final double principalDue;
  final double interest234b;
  final double interest234c;
  final double totalPayable;

  const AdvanceTaxResult({
    required this.totalLiability,
    required this.paidTillNow,
    required this.installments,
    required this.currentTarget,
    required this.currentShortfall,
    required this.principalDue,
    required this.interest234b,
    required this.interest234c,
    required this.totalPayable,
  });
}

class TdsResult {
  final String paymentTypeValue;
  final String sectionCode;
  final String sectionLabel;
  final String description;
  final double amount;
  final double threshold;
  final double appliedRate;
  final double tdsAmount;
  final double netAmount;
  final double payerOutflow;

  const TdsResult({
    required this.paymentTypeValue,
    required this.sectionCode,
    required this.sectionLabel,
    required this.description,
    required this.amount,
    required this.threshold,
    required this.appliedRate,
    required this.tdsAmount,
    required this.netAmount,
    required this.payerOutflow,
  });
}

class TaxEngine {
  const TaxEngine._();

  static IncomeTaxResult computeIncomeTax({
    required IncomeTaxRules rules,
    required double salary,
    required double extraDeductions,
    required TaxRegime regime,
    required AgeBucket ageBucket,
    required bool resident,
  }) {
    final safeSalary = math.max(0.0, salary);
    final safeExtraDeductions = math.max(0.0, extraDeductions);
    final regimeKey = regime == TaxRegime.newRegime ? 'new' : 'old';
    final ageKey = switch (ageBucket) {
      AgeBucket.below60 => 'below60',
      AgeBucket.age60to80 => 'age60to80',
      AgeBucket.above80 => 'above80',
    };
    final standardDeduction = rules.standardDeduction[regimeKey] ?? 0.0;
    final deductionsUsed = regime == TaxRegime.old
        ? math.min(safeExtraDeductions, safeSalary)
        : 0.0;
    final taxableIncome =
        math.max(0.0, safeSalary - standardDeduction - deductionsUsed);
    final baseTax = regime == TaxRegime.newRegime
        ? _slabTax(taxableIncome, rules.newSlabs)
        : _oldRegimeTax(taxableIncome, rules, ageKey);

    final rebateRule = rules.rebate[regimeKey];
    final rebate = rebateRule == null
        ? 0.0
        : _rebate(
            taxableIncome: taxableIncome,
            baseTax: baseTax,
            rebateRule: rebateRule,
            resident: resident,
          );
    final taxAfterRebate = math.max(0.0, baseTax - rebate);
    final surcharge = _surcharge(
      taxableIncome: taxableIncome,
      taxAfterRebate: taxAfterRebate,
      surchargeRules: rules.surcharge[regimeKey] ?? const [],
      taxAtIncome: (income) {
        final base = regime == TaxRegime.newRegime
            ? _slabTax(income, rules.newSlabs)
            : _oldRegimeTax(income, rules, ageKey);
        final r = rebateRule == null
            ? 0.0
            : _rebate(
                taxableIncome: income,
                baseTax: base,
                rebateRule: rebateRule,
                resident: resident,
              );
        return math.max(0.0, base - r);
      },
    );

    final taxPlusSurcharge = taxAfterRebate + surcharge;
    final cess = taxPlusSurcharge * rules.cessRate;
    final totalTax = taxPlusSurcharge + cess;
    final netIncome = safeSalary - totalTax;
    final effectiveRate = safeSalary > 0 ? (totalTax / safeSalary) * 100 : 0.0;

    return IncomeTaxResult(
      salary: safeSalary,
      deductionsUsed: deductionsUsed,
      taxableIncome: taxableIncome,
      standardDeduction: standardDeduction,
      baseTax: baseTax,
      rebate: rebate,
      surcharge: surcharge,
      cess: cess,
      totalTax: totalTax,
      effectiveRate: effectiveRate,
      netIncome: netIncome,
      monthlyNetIncome: netIncome / 12,
    );
  }

  static CapitalGainsResult computeCapitalGains({
    required CapitalGainsRules rules,
    required String assetType,
    required double buyValue,
    required double sellValue,
    required int holdingMonths,
  }) {
    final safeBuy = math.max(0.0, buyValue);
    final safeSell = math.max(0.0, sellValue);
    final gain = safeSell - safeBuy;
    final selectedRule = rules.assets[assetType];
    if (selectedRule == null) {
      throw ArgumentError('Unsupported asset type: $assetType');
    }

    final forceShort =
        selectedRule.alwaysShortTerm || selectedRule.ltcgMode == 'none';
    final isLong = !forceShort &&
        holdingMonths >= math.max(1, selectedRule.holdingPeriodMonths);

    if (gain <= 0) {
      return CapitalGainsResult(
        buyValue: safeBuy,
        sellValue: safeSell,
        gain: gain,
        isLongTerm: isLong,
        taxableGain: 0.0,
        tax: 0.0,
        netGain: gain,
        section: selectedRule.section,
        appliedRate: isLong ? selectedRule.ltcgRate : selectedRule.stcgRate,
        note: selectedRule.note,
      );
    }

    final appliedRate = isLong ? selectedRule.ltcgRate : selectedRule.stcgRate;
    final taxableGain =
        isLong ? math.max(0.0, gain - selectedRule.ltcgExemption) : gain;
    final tax = taxableGain * math.max(0.0, appliedRate);
    final netGain = gain - tax;

    return CapitalGainsResult(
      buyValue: safeBuy,
      sellValue: safeSell,
      gain: gain,
      isLongTerm: isLong,
      taxableGain: taxableGain,
      tax: tax,
      netGain: netGain,
      section: selectedRule.section,
      appliedRate: appliedRate,
      note: selectedRule.note,
    );
  }

  static AdvanceTaxResult computeAdvanceTax({
    required AdvanceTaxRules rules,
    required double totalLiability,
    required double paidTillNow,
    required int currentInstallmentIndex,
    required int fyStartYear,
    required DateTime paymentDate,
  }) {
    final safeLiability = math.max(0.0, totalLiability);
    final safePaid = math.max(0.0, paidTillNow);
    final rows = rules.installments.map((installment) {
      final target = safeLiability * (installment.cumulativePercent / 100);
      return AdvanceTaxInstallmentBreakdown(
        label: installment.label,
        dueDate: installment.dueDate,
        cumulativePercent: installment.cumulativePercent,
        cumulativeTarget: target,
        shortfall: math.max(0.0, target - safePaid),
      );
    }).toList(growable: false);

    final safeIndex =
        rows.isEmpty ? 0 : currentInstallmentIndex.clamp(0, rows.length - 1);
    final current = rows.isEmpty ? null : rows[safeIndex];

    var interest234c = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final due = _dueDateForFy(row.dueDate, fyStartYear);
      if (due.isAfter(paymentDate)) {
        continue;
      }
      final months = (i >= rows.length - 1) ? 1 : 3;
      interest234c += row.shortfall * rules.interestRate234c * months;
    }

    final principalDue = math.max(0.0, safeLiability - safePaid);
    var interest234b = 0.0;
    final assessmentStart = DateTime(fyStartYear + 1, 4, 1);
    final qualifies234b = principalDue > rules.interestThreshold &&
        safePaid < (safeLiability * 0.9) &&
        !paymentDate.isBefore(assessmentStart);
    if (qualifies234b) {
      final months = _monthPartsInclusive(assessmentStart, paymentDate);
      interest234b = principalDue * rules.interestRate234b * months;
    }

    final totalPayable = principalDue + interest234b + interest234c;

    return AdvanceTaxResult(
      totalLiability: safeLiability,
      paidTillNow: safePaid,
      installments: rows,
      currentTarget: current?.cumulativeTarget ?? 0.0,
      currentShortfall: current?.shortfall ?? 0.0,
      principalDue: principalDue,
      interest234b: interest234b,
      interest234c: interest234c,
      totalPayable: totalPayable,
    );
  }

  static TdsResult computeTds({
    required TdsRules rules,
    required String paymentTypeValue,
    required double amount,
    required bool panAvailable,
    required String recipient,
    String fee194jType = 'others',
  }) {
    final safeAmount = math.max(0.0, amount);
    final normalizedRecipient =
        recipient.trim().toLowerCase() == 'individual' ? 'individual' : 'other';

    final paymentType = rules.paymentTypes.firstWhere(
      (row) => row.value == paymentTypeValue,
      orElse: () {
        if (rules.paymentTypes.isNotEmpty) {
          return rules.paymentTypes.first;
        }
        throw ArgumentError('Unsupported TDS payment type: $paymentTypeValue');
      },
    );

    double appliedRate;
    if (!panAvailable) {
      appliedRate = paymentType.rateNoPan;
    } else {
      final subtype = paymentType.subTypeOptions.firstWhere(
        (row) => row.value == fee194jType,
        orElse: () => paymentType.subTypeOptions.isNotEmpty
            ? paymentType.subTypeOptions.first
            : TdsSubTypeRule(
                value: '',
                label: '',
                rateIndividual: paymentType.rateIndividual,
                rateOther: paymentType.rateOther,
                rateNoPan: paymentType.rateNoPan,
              ),
      );
      if (normalizedRecipient == 'individual') {
        appliedRate = subtype.rateIndividual;
      } else {
        appliedRate = subtype.rateOther;
      }
    }

    var threshold = paymentType.threshold;
    if (!paymentType.alwaysApply) {
      if (normalizedRecipient == 'individual' &&
          paymentType.thresholdIndividual != null) {
        threshold = paymentType.thresholdIndividual!;
      } else if (normalizedRecipient == 'other' &&
          paymentType.thresholdOther != null) {
        threshold = paymentType.thresholdOther!;
      }
    } else {
      threshold = 0.0;
    }

    final tds =
        (paymentType.alwaysApply || threshold <= 0 || safeAmount > threshold)
            ? safeAmount * appliedRate
            : 0.0;

    return TdsResult(
      paymentTypeValue: paymentType.value,
      sectionCode: paymentType.sectionCode,
      sectionLabel: paymentType.label,
      description: paymentType.description,
      amount: safeAmount,
      threshold: threshold,
      appliedRate: appliedRate,
      tdsAmount: tds,
      netAmount: safeAmount - tds,
      payerOutflow: safeAmount,
    );
  }

  static double _oldRegimeTax(
    double taxableIncome,
    IncomeTaxRules rules,
    String ageKey,
  ) {
    final basic = rules.oldBasicExemption[ageKey] ?? 250000.0;
    final slabs = <TaxSlab>[
      TaxSlab(upperLimit: basic, rate: 0.0),
      ...rules.oldSlabs,
    ];
    return _slabTax(taxableIncome, slabs);
  }

  static double _slabTax(double income, List<TaxSlab> slabs) {
    double tax = 0.0;
    double previous = 0.0;
    for (final slab in slabs) {
      if (income <= previous) break;
      final amountAtRate = math.min(income, slab.upperLimit) - previous;
      if (amountAtRate > 0) {
        tax += amountAtRate * slab.rate;
      }
      previous = slab.upperLimit;
    }
    return tax;
  }

  static double _rebate({
    required double taxableIncome,
    required double baseTax,
    required IncomeTaxRebateRule rebateRule,
    required bool resident,
  }) {
    if (baseTax <= 0) return 0.0;
    if (rebateRule.residentOnly && !resident) return 0.0;
    if (taxableIncome <= rebateRule.threshold) {
      return math.min(baseTax, rebateRule.maxRebate);
    }
    if (!rebateRule.marginalRelief) return 0.0;
    final excessIncome = taxableIncome - rebateRule.threshold;
    final maxTaxAllowed = excessIncome;
    final relief = math.max(0.0, baseTax - maxTaxAllowed);
    return math.min(rebateRule.maxRebate, relief);
  }

  static double _surcharge({
    required double taxableIncome,
    required double taxAfterRebate,
    required List<IncomeTaxSurchargeRule> surchargeRules,
    required double Function(double income) taxAtIncome,
  }) {
    if (taxAfterRebate <= 0 || surchargeRules.isEmpty) return 0.0;
    double activeRate = 0.0;
    double activeThreshold = 0.0;
    final orderedRules = [...surchargeRules]
      ..sort((a, b) => a.threshold.compareTo(b.threshold));
    for (final rule in orderedRules) {
      if (taxableIncome > rule.threshold) {
        activeRate = rule.rate;
        activeThreshold = rule.threshold;
      }
    }
    if (activeRate == 0) return 0.0;
    var surcharge = taxAfterRebate * activeRate;
    final taxWithSurcharge = taxAfterRebate + surcharge;
    final taxAtThreshold = taxAtIncome(activeThreshold);
    final maxTaxAllowed = taxAtThreshold + (taxableIncome - activeThreshold);
    if (taxWithSurcharge > maxTaxAllowed) {
      surcharge = math.max(0.0, maxTaxAllowed - taxAfterRebate);
    }
    return surcharge;
  }

  static DateTime _dueDateForFy(String dueDate, int fyStartYear) {
    final parts = dueDate.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return DateTime(fyStartYear + 1, 3, 15);
    }
    final day = int.tryParse(parts[0]) ?? 1;
    final month = switch (parts[1].toLowerCase()) {
      'jan' => 1,
      'feb' => 2,
      'mar' => 3,
      'apr' => 4,
      'may' => 5,
      'jun' => 6,
      'jul' => 7,
      'aug' => 8,
      'sep' => 9,
      'oct' => 10,
      'nov' => 11,
      'dec' => 12,
      _ => 3,
    };
    final year = month >= 4 ? fyStartYear : fyStartYear + 1;
    return DateTime(year, month, day);
  }

  static int _monthPartsInclusive(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    final months = (end.year - start.year) * 12 + (end.month - start.month);
    return months + 1;
  }
}
