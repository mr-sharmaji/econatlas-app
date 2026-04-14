import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/utils.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

enum TradeSegment {
  equityDelivery,
  equityIntraday,
  equityFutures,
  equityOptions,
  currencyFutures,
  currencyOptions,
  commodityFutures,
  commodityOptions,
}

enum TradeExchange { nse, bse, mcx }

class TradeChargesScreen extends ConsumerStatefulWidget {
  const TradeChargesScreen({super.key});

  @override
  ConsumerState<TradeChargesScreen> createState() => _TradeChargesScreenState();
}

class _TradeChargesScreenState extends ConsumerState<TradeChargesScreen> {
  final _buyController = TextEditingController();
  final _sellController = TextEditingController();
  final _qtyController = TextEditingController();

  TradeSegment _segment = TradeSegment.equityDelivery;
  TradeExchange _exchange = TradeExchange.nse;
  String _broker = 'Zerodha';

  bool _custom = false;
  final _customBrokeragePctController = TextEditingController(text: '0.03');
  final _customCapController = TextEditingController(text: '20');
  final _customFlatController = TextEditingController(text: '20');

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _buyController.text =
        prefs.getString(AppConstants.prefChargesBuyPrice) ?? '100';
    _sellController.text =
        prefs.getString(AppConstants.prefChargesSellPrice) ?? '102';
    _qtyController.text =
        prefs.getString(AppConstants.prefChargesQuantity) ?? '100';
    _broker = prefs.getString(AppConstants.prefChargesBroker) ?? 'Zerodha';
    _segment = TradeSegment.values.elementAt(
      (prefs.getInt(AppConstants.prefChargesSegment) ?? 0)
          .clamp(0, TradeSegment.values.length - 1),
    );
    _exchange = TradeExchange.values.elementAt(
      (prefs.getInt(AppConstants.prefChargesExchange) ?? 0)
          .clamp(0, TradeExchange.values.length - 1),
    );
    _custom = prefs.getBool(AppConstants.prefChargesCustomBroker) ?? false;
    _customBrokeragePctController.text =
        prefs.getString(AppConstants.prefChargesCustomBrokeragePct) ?? '0.03';
    _customCapController.text =
        prefs.getString(AppConstants.prefChargesCustomCap) ?? '20';

    _ensureValidExchange();
  }

  @override
  void dispose() {
    _buyController.dispose();
    _sellController.dispose();
    _qtyController.dispose();
    _customBrokeragePctController.dispose();
    _customCapController.dispose();
    _customFlatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breakdown = _calculate();
    final broker = _selectedBroker();

    return Scaffold(
      appBar: AppBar(title: const Text('Trade Charges')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2A4A), Color(0xFF11345A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Charges estimator',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Brokerage + statutory levies for Indian markets. Uses segment-wise rates and broker plan rules.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trade setup',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  AdaptiveSelectField<TradeSegment>(
                    label: 'Segment',
                    value: _segment,
                    decoration: const InputDecoration(
                      labelText: 'Segment',
                      prefixIcon: Icon(Icons.candlestick_chart),
                    ),
                    options: TradeSegment.values
                        .map(
                          (s) => AdaptiveSelectOption(
                            value: s,
                            label: _segmentLabel(s),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      _segment = value;
                      _ensureValidExchange();
                      final prefs = ref.read(sharedPreferencesProvider);
                      prefs.setInt(
                          AppConstants.prefChargesSegment, _segment.index);
                      prefs.setInt(
                        AppConstants.prefChargesExchange,
                        _exchange.index,
                      );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  AdaptiveSelectField<TradeExchange>(
                    label: 'Exchange',
                    value: _exchange,
                    decoration: const InputDecoration(
                      labelText: 'Exchange',
                      prefixIcon: Icon(Icons.hub_outlined),
                    ),
                    options: _allowedExchanges(_segment)
                        .map(
                          (e) => AdaptiveSelectOption(
                            value: e,
                            label: _exchangeLabel(e),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      _exchange = value;
                      ref.read(sharedPreferencesProvider).setInt(
                            AppConstants.prefChargesExchange,
                            _exchange.index,
                          );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _buyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Buy price (₹)',
                      prefixIcon: Icon(Icons.south_rounded),
                    ),
                    onChanged: (v) {
                      ref.read(sharedPreferencesProvider).setString(
                            AppConstants.prefChargesBuyPrice,
                            v.trim(),
                          );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sellController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Sell price (₹)',
                      prefixIcon: Icon(Icons.north_rounded),
                    ),
                    onChanged: (v) {
                      ref.read(sharedPreferencesProvider).setString(
                            AppConstants.prefChargesSellPrice,
                            v.trim(),
                          );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _qtyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Quantity / lot units',
                      prefixIcon: Icon(Icons.format_list_numbered_rounded),
                    ),
                    onChanged: (v) {
                      ref.read(sharedPreferencesProvider).setString(
                            AppConstants.prefChargesQuantity,
                            v.trim(),
                          );
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Broker plan',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    value: _custom,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use custom brokerage'),
                    subtitle: const Text(
                        'Override broker preset with your own rates'),
                    onChanged: (value) {
                      _custom = value;
                      ref.read(sharedPreferencesProvider).setBool(
                            AppConstants.prefChargesCustomBroker,
                            value,
                          );
                      setState(() {});
                    },
                  ),
                  if (!_custom) ...[
                    const SizedBox(height: 8),
                    AdaptiveSelectField<String>(
                      label: 'Broker',
                      value: _broker,
                      decoration: const InputDecoration(
                        labelText: 'Broker',
                        prefixIcon: Icon(Icons.apartment_rounded),
                      ),
                      options: _brokerPresets.keys
                          .map(
                            (b) => AdaptiveSelectOption(
                              value: b,
                              label: b,
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        _broker = value;
                        ref.read(sharedPreferencesProvider).setString(
                              AppConstants.prefChargesBroker,
                              value,
                            );
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      broker.tagline,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customBrokeragePctController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Brokerage % per side',
                        helperText: 'Example: 0.03 means 0.03% of side value',
                      ),
                      onChanged: (v) {
                        ref.read(sharedPreferencesProvider).setString(
                              AppConstants.prefChargesCustomBrokeragePct,
                              v.trim(),
                            );
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customCapController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Cap per order (₹)',
                      ),
                      onChanged: (v) {
                        ref.read(sharedPreferencesProvider).setString(
                              AppConstants.prefChargesCustomCap,
                              v.trim(),
                            );
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customFlatController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText:
                            'Flat fee per executed order (₹) for options',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Charges breakdown',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _row('Brokerage', breakdown.brokerage),
                  _row('STT / CTT', breakdown.sttOrCtt),
                  _row('Exchange transaction', breakdown.exchangeTxn),
                  _row('SEBI turnover fee', breakdown.sebi),
                  _row('Stamp duty', breakdown.stampDuty),
                  if (breakdown.ipft > 0)
                    _row('IPFT / investor fund', breakdown.ipft),
                  if (breakdown.dpCharge > 0)
                    _row('DP charge', breakdown.dpCharge),
                  _row('GST (18%)', breakdown.gst),
                  const Divider(height: 22),
                  _row('Total charges', breakdown.totalCharges, strong: true),
                  const SizedBox(height: 8),
                  Text(
                    breakdown.notes,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _restoreLast,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restore Last'),
                ),
                TextButton.icon(
                  onPressed: _resetDefaults,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: theme.colorScheme.surface.withValues(alpha: 0.96),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total charges: ₹ ${Formatters.fullPrice(breakdown.totalCharges)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Net P&L after charges: ₹ ${Formatters.fullPrice(breakdown.netPnl)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: breakdown.netPnl >= 0
                        ? const Color(0xFF32D583)
                        : const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Break-even move: ₹ ${Formatters.fullPrice(breakdown.breakEven)} per unit',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, double amount, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          Text(
            '₹ ${Formatters.fullPrice(amount)}',
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  void _ensureValidExchange() {
    final allowed = _allowedExchanges(_segment);
    if (!allowed.contains(_exchange)) {
      _exchange = allowed.first;
    }
  }

  List<TradeExchange> _allowedExchanges(TradeSegment segment) {
    switch (segment) {
      case TradeSegment.equityDelivery:
      case TradeSegment.equityIntraday:
      case TradeSegment.equityFutures:
      case TradeSegment.equityOptions:
        return const [TradeExchange.nse, TradeExchange.bse];
      case TradeSegment.currencyFutures:
      case TradeSegment.currencyOptions:
        return const [TradeExchange.nse];
      case TradeSegment.commodityFutures:
      case TradeSegment.commodityOptions:
        return const [TradeExchange.mcx];
    }
  }

  String _exchangeLabel(TradeExchange exchange) {
    switch (exchange) {
      case TradeExchange.nse:
        return 'NSE';
      case TradeExchange.bse:
        return 'BSE';
      case TradeExchange.mcx:
        return 'MCX';
    }
  }

  String _segmentLabel(TradeSegment segment) {
    switch (segment) {
      case TradeSegment.equityDelivery:
        return 'Equity Delivery';
      case TradeSegment.equityIntraday:
        return 'Equity Intraday';
      case TradeSegment.equityFutures:
        return 'Equity Futures';
      case TradeSegment.equityOptions:
        return 'Equity Options';
      case TradeSegment.currencyFutures:
        return 'Currency Futures';
      case TradeSegment.currencyOptions:
        return 'Currency Options';
      case TradeSegment.commodityFutures:
        return 'Commodity Futures';
      case TradeSegment.commodityOptions:
        return 'Commodity Options';
    }
  }

  _BrokerPreset _selectedBroker() {
    if (_custom) {
      final pct = math.max(
              0.0,
              double.tryParse(_customBrokeragePctController.text.trim()) ??
                  0.0) /
          100;
      final cap = math.max(
          0.0, double.tryParse(_customCapController.text.trim()) ?? 0.0);
      final flat = math.max(
          0.0, double.tryParse(_customFlatController.text.trim()) ?? 0.0);
      return _BrokerPreset.custom(
        pctPerSide: pct,
        capPerOrder: cap,
        flatPerOrder: flat,
      );
    }
    return _brokerPresets[_broker] ?? _brokerPresets.values.first;
  }

  _ChargeResult _calculate() {
    final buy =
        math.max(0.0, double.tryParse(_buyController.text.trim()) ?? 0.0);
    final sell =
        math.max(0.0, double.tryParse(_sellController.text.trim()) ?? 0.0);
    final qty =
        math.max(0.0, double.tryParse(_qtyController.text.trim()) ?? 0.0);

    final buyValue = buy * qty;
    final sellValue = sell * qty;
    final turnover = buyValue + sellValue;
    final grossPnl = (sell - buy) * qty;

    final broker = _selectedBroker();
    final rates = _statutoryRates(segment: _segment, exchange: _exchange);

    final brokerage = _brokerage(
      broker: broker,
      segment: _segment,
      buyValue: buyValue,
      sellValue: sellValue,
    );
    final sttOrCtt =
        (buyValue * rates.sttBuyRate) + (sellValue * rates.sttSellRate);
    final exchangeTxn = turnover * rates.exchangeTxnRate;
    final sebi = turnover * 0.000001; // 10 per crore.
    final stampDuty = buyValue * rates.stampDutyBuyRate;
    final ipft = turnover * rates.ipftRate;

    final dpCharge = _segment == TradeSegment.equityDelivery
        ? broker.dpChargePerSellTransaction
        : 0.0;
    final gstBase = brokerage +
        exchangeTxn +
        sebi +
        ipft +
        (_segment == TradeSegment.equityDelivery && !broker.dpChargeIncludesGst
            ? dpCharge
            : 0.0);
    final gst = gstBase * 0.18;

    final totalCharges = brokerage +
        sttOrCtt +
        exchangeTxn +
        sebi +
        stampDuty +
        ipft +
        dpCharge +
        gst;
    final netPnl = grossPnl - totalCharges;
    final breakEven = qty > 0 ? totalCharges / qty : 0.0;

    return _ChargeResult(
      brokerage: brokerage,
      sttOrCtt: sttOrCtt,
      exchangeTxn: exchangeTxn,
      sebi: sebi,
      stampDuty: stampDuty,
      ipft: ipft,
      dpCharge: dpCharge,
      gst: gst,
      totalCharges: totalCharges,
      netPnl: netPnl,
      breakEven: breakEven,
      notes:
          '${_exchangeLabel(_exchange)} rates. Option exercise STT is not modeled. Broker pricing can change; confirm before order.',
    );
  }

  double _brokerage({
    required _BrokerPreset broker,
    required TradeSegment segment,
    required double buyValue,
    required double sellValue,
  }) {
    final rule = broker.rules[segment] ?? const _BrokerageRule.free();
    return rule.sideCharge(buyValue) + rule.sideCharge(sellValue);
  }

  // Statutory rates updated 2025-26. Key revisions:
  // - STT on equity options: 0.0625% → 0.1% (Oct 1, 2024)
  // - STT on equity futures: 0.0125% → 0.02% (Oct 1, 2024)
  // - NSE equity options txn: slab-based → flat 0.03553% (Oct 1, 2024)
  // - SEBI fee: ₹10/Cr (18% GST applicable from Apr 2025)
  // - IPFT: ₹10/Cr equity, ₹50/Cr options premium, ₹5/Cr currency
  _StatutoryRates _statutoryRates({
    required TradeSegment segment,
    required TradeExchange exchange,
  }) {
    switch (segment) {
      case TradeSegment.equityDelivery:
        return _StatutoryRates(
          sttBuyRate: 0.001,        // 0.1% both sides
          sttSellRate: 0.001,
          exchangeTxnRate:
              exchange == TradeExchange.bse ? 0.0000375 : 0.0000307,
          stampDutyBuyRate: 0.00015, // ₹1500/Cr
          ipftRate: exchange == TradeExchange.nse ? 0.000001 : 0.0,
        );
      case TradeSegment.equityIntraday:
        return _StatutoryRates(
          sttBuyRate: 0.0,
          sttSellRate: 0.00025,     // 0.025% sell side
          exchangeTxnRate:
              exchange == TradeExchange.bse ? 0.0000375 : 0.0000307,
          stampDutyBuyRate: 0.00003, // ₹300/Cr
          ipftRate: exchange == TradeExchange.nse ? 0.000001 : 0.0,
        );
      case TradeSegment.equityFutures:
        return _StatutoryRates(
          sttBuyRate: 0.0,
          sttSellRate: 0.0002,      // 0.02% sell side (revised Oct 2024)
          exchangeTxnRate:
              exchange == TradeExchange.bse ? 0.0 : 0.0000183,
          stampDutyBuyRate: 0.00002, // ₹200/Cr
          ipftRate: exchange == TradeExchange.nse ? 0.000001 : 0.0,
        );
      case TradeSegment.equityOptions:
        return _StatutoryRates(
          sttBuyRate: 0.0,
          sttSellRate: 0.001,       // 0.1% sell side on premium (revised Oct 2024)
          exchangeTxnRate:
              exchange == TradeExchange.bse ? 0.000325 : 0.0003553,
          stampDutyBuyRate: 0.00003, // ₹300/Cr
          ipftRate: exchange == TradeExchange.nse ? 0.000005 : 0.0, // ₹50/Cr premium
        );
      case TradeSegment.currencyFutures:
        return _StatutoryRates(
          sttBuyRate: 0.0,
          sttSellRate: 0.0,         // No STT on currency
          exchangeTxnRate:
              exchange == TradeExchange.bse ? 0.0000045 : 0.0000035,
          stampDutyBuyRate: 0.000001, // ₹10/Cr
          ipftRate: exchange == TradeExchange.nse ? 0.0000005 : 0.0, // ₹5/Cr
        );
      case TradeSegment.currencyOptions:
        return _StatutoryRates(
          sttBuyRate: 0.0,
          sttSellRate: 0.0,
          exchangeTxnRate:
              exchange == TradeExchange.bse ? 0.00001 : 0.000311,
          stampDutyBuyRate: 0.000001,
          ipftRate: 0.0,
        );
      case TradeSegment.commodityFutures:
        return _StatutoryRates(
          sttBuyRate: 0.0,
          sttSellRate: 0.0001,      // 0.01% CTT sell side (non-agri)
          exchangeTxnRate:
              exchange == TradeExchange.mcx ? 0.000021 : 0.000001,
          stampDutyBuyRate: 0.00002, // ₹200/Cr
          ipftRate: 0.0,
        );
      case TradeSegment.commodityOptions:
        return _StatutoryRates(
          sttBuyRate: 0.0,
          sttSellRate: 0.0005,      // 0.05% CTT sell side
          exchangeTxnRate:
              exchange == TradeExchange.mcx ? 0.000418 : 0.000001,
          stampDutyBuyRate: 0.00003,
          ipftRate: 0.0,
        );
    }
  }

  void _restoreLast() {
    final prefs = ref.read(sharedPreferencesProvider);
    _buyController.text =
        prefs.getString(AppConstants.prefChargesBuyPrice) ?? '100';
    _sellController.text =
        prefs.getString(AppConstants.prefChargesSellPrice) ?? '102';
    _qtyController.text =
        prefs.getString(AppConstants.prefChargesQuantity) ?? '100';
    _broker = prefs.getString(AppConstants.prefChargesBroker) ?? 'Zerodha';
    _segment = TradeSegment.values.elementAt(
      (prefs.getInt(AppConstants.prefChargesSegment) ?? 0)
          .clamp(0, TradeSegment.values.length - 1),
    );
    _exchange = TradeExchange.values.elementAt(
      (prefs.getInt(AppConstants.prefChargesExchange) ?? 0)
          .clamp(0, TradeExchange.values.length - 1),
    );
    _custom = prefs.getBool(AppConstants.prefChargesCustomBroker) ?? false;
    _customBrokeragePctController.text =
        prefs.getString(AppConstants.prefChargesCustomBrokeragePct) ?? '0.03';
    _customCapController.text =
        prefs.getString(AppConstants.prefChargesCustomCap) ?? '20';
    _ensureValidExchange();
    setState(() {});
  }

  void _resetDefaults() {
    _buyController.text = '100';
    _sellController.text = '102';
    _qtyController.text = '100';
    _segment = TradeSegment.equityDelivery;
    _exchange = TradeExchange.nse;
    _broker = 'Zerodha';
    _custom = false;
    _customBrokeragePctController.text = '0.03';
    _customCapController.text = '20';
    _customFlatController.text = '20';

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(AppConstants.prefChargesBuyPrice, '100');
    prefs.setString(AppConstants.prefChargesSellPrice, '102');
    prefs.setString(AppConstants.prefChargesQuantity, '100');
    prefs.setInt(AppConstants.prefChargesSegment, _segment.index);
    prefs.setInt(AppConstants.prefChargesExchange, _exchange.index);
    prefs.setString(AppConstants.prefChargesBroker, _broker);
    prefs.setBool(AppConstants.prefChargesCustomBroker, false);
    prefs.setString(AppConstants.prefChargesCustomBrokeragePct, '0.03');
    prefs.setString(AppConstants.prefChargesCustomCap, '20');
    setState(() {});
  }
}

enum _BrokerageMode { free, percentCap, flat }

class _BrokerageRule {
  final _BrokerageMode mode;
  final double pct;
  final double cap;
  final double minCharge;
  final double minChargePercentCap;
  final double flatPerOrder;

  const _BrokerageRule.free()
      : mode = _BrokerageMode.free,
        pct = 0.0,
        cap = 0.0,
        minCharge = 0.0,
        minChargePercentCap = 0.0,
        flatPerOrder = 0.0;

  const _BrokerageRule.percentCap({
    required this.pct,
    required this.cap,
    this.minCharge = 0.0,
    this.minChargePercentCap = 0.0,
  })  : mode = _BrokerageMode.percentCap,
        flatPerOrder = 0.0;

  const _BrokerageRule.flat(this.flatPerOrder)
      : mode = _BrokerageMode.flat,
        pct = 0.0,
        cap = 0.0,
        minCharge = 0.0,
        minChargePercentCap = 0.0;

  double sideCharge(double sideValue) {
    if (sideValue <= 0) return 0.0;
    switch (mode) {
      case _BrokerageMode.free:
        return 0.0;
      case _BrokerageMode.flat:
        return flatPerOrder;
      case _BrokerageMode.percentCap:
        var charge = sideValue * pct;
        if (cap > 0) {
          charge = math.min(charge, cap);
        }
        if (minCharge > 0) {
          var minAllowed = minCharge;
          if (minChargePercentCap > 0) {
            minAllowed = math.min(minAllowed, sideValue * minChargePercentCap);
          }
          charge = math.max(charge, minAllowed);
        }
        return charge;
    }
  }
}

class _BrokerPreset {
  final String name;
  final String tagline;
  final double dpChargePerSellTransaction;
  final bool dpChargeIncludesGst;
  final Map<TradeSegment, _BrokerageRule> rules;

  const _BrokerPreset({
    required this.name,
    required this.tagline,
    required this.dpChargePerSellTransaction,
    required this.dpChargeIncludesGst,
    required this.rules,
  });

  factory _BrokerPreset.custom({
    required double pctPerSide,
    required double capPerOrder,
    required double flatPerOrder,
  }) {
    return _BrokerPreset(
      name: 'Custom',
      tagline: 'Custom pricing model',
      dpChargePerSellTransaction: 15.93,
      dpChargeIncludesGst: true,
      rules: {
        TradeSegment.equityDelivery:
            _BrokerageRule.percentCap(pct: pctPerSide, cap: capPerOrder),
        TradeSegment.equityIntraday:
            _BrokerageRule.percentCap(pct: pctPerSide, cap: capPerOrder),
        TradeSegment.equityFutures:
            _BrokerageRule.percentCap(pct: pctPerSide, cap: capPerOrder),
        TradeSegment.currencyFutures:
            _BrokerageRule.percentCap(pct: pctPerSide, cap: capPerOrder),
        TradeSegment.commodityFutures:
            _BrokerageRule.percentCap(pct: pctPerSide, cap: capPerOrder),
        TradeSegment.equityOptions: _BrokerageRule.flat(flatPerOrder),
        TradeSegment.currencyOptions: _BrokerageRule.flat(flatPerOrder),
        TradeSegment.commodityOptions: _BrokerageRule.flat(flatPerOrder),
      },
    );
  }
}

// Broker charges updated 2025-26 from official pricing pages.
// Sources: zerodha.com/charges, upstox.com/brokerage-charges,
// groww.in/pricing, angelone.in/exchange-transaction-charges
const Map<String, _BrokerPreset> _brokerPresets = {
  'Zerodha': _BrokerPreset(
    name: 'Zerodha',
    tagline: 'Delivery free · 0.05%/₹20 intraday/F&O · AMC free',
    dpChargePerSellTransaction: 15.34,
    dpChargeIncludesGst: false,
    rules: {
      TradeSegment.equityDelivery: _BrokerageRule.free(),
      TradeSegment.equityIntraday:
          _BrokerageRule.percentCap(pct: 0.0005, cap: 20),
      TradeSegment.equityFutures:
          _BrokerageRule.percentCap(pct: 0.0005, cap: 20),
      TradeSegment.currencyFutures:
          _BrokerageRule.percentCap(pct: 0.0005, cap: 20),
      TradeSegment.commodityFutures:
          _BrokerageRule.percentCap(pct: 0.0005, cap: 20),
      TradeSegment.equityOptions: _BrokerageRule.flat(20),
      TradeSegment.currencyOptions: _BrokerageRule.flat(20),
      TradeSegment.commodityOptions: _BrokerageRule.flat(20),
    },
  ),
  'Upstox': _BrokerPreset(
    name: 'Upstox',
    tagline: '₹20 delivery · 0.05% intraday/futures · AMC ₹150+GST/yr',
    dpChargePerSellTransaction: 18.50,
    dpChargeIncludesGst: false,
    rules: {
      TradeSegment.equityDelivery: _BrokerageRule.flat(20),
      TradeSegment.equityIntraday:
          _BrokerageRule.percentCap(pct: 0.0005, cap: 20),
      TradeSegment.equityFutures:
          _BrokerageRule.percentCap(pct: 0.0005, cap: 20),
      TradeSegment.currencyFutures:
          _BrokerageRule.percentCap(pct: 0.0005, cap: 20),
      TradeSegment.commodityFutures:
          _BrokerageRule.percentCap(pct: 0.0005, cap: 20),
      TradeSegment.equityOptions: _BrokerageRule.flat(20),
      TradeSegment.currencyOptions: _BrokerageRule.flat(20),
      TradeSegment.commodityOptions: _BrokerageRule.flat(20),
    },
  ),
  'Groww': _BrokerPreset(
    name: 'Groww',
    tagline: '0.1%/₹20 equity · ₹20 flat F&O · Min ₹5 · AMC free',
    dpChargePerSellTransaction: 20.0,
    dpChargeIncludesGst: false,
    rules: {
      TradeSegment.equityDelivery: _BrokerageRule.percentCap(
        pct: 0.001, cap: 20, minCharge: 5, minChargePercentCap: 0.025,
      ),
      TradeSegment.equityIntraday: _BrokerageRule.percentCap(
        pct: 0.001, cap: 20, minCharge: 5, minChargePercentCap: 0.025,
      ),
      TradeSegment.equityFutures: _BrokerageRule.percentCap(
        pct: 0.0005, cap: 20, minCharge: 5,
      ),
      TradeSegment.currencyFutures: _BrokerageRule.percentCap(
        pct: 0.0005, cap: 20, minCharge: 5,
      ),
      TradeSegment.commodityFutures: _BrokerageRule.percentCap(
        pct: 0.0005, cap: 20, minCharge: 5,
      ),
      TradeSegment.equityOptions: _BrokerageRule.flat(20),
      TradeSegment.currencyOptions: _BrokerageRule.flat(20),
      TradeSegment.commodityOptions: _BrokerageRule.flat(20),
    },
  ),
  'Angel One': _BrokerPreset(
    name: 'Angel One',
    tagline: '0.1%/₹20 equity · ₹20 flat F&O · Min ₹5 · AMC ₹240+GST/yr',
    dpChargePerSellTransaction: 25.50, // ₹20 + CDSL ₹5.50
    dpChargeIncludesGst: false,
    rules: {
      // Revised Nov 17, 2025: delivery was free → now 0.1%/₹20
      TradeSegment.equityDelivery: _BrokerageRule.percentCap(
        pct: 0.001, cap: 20, minCharge: 5, minChargePercentCap: 0.025,
      ),
      TradeSegment.equityIntraday: _BrokerageRule.percentCap(
        pct: 0.001, cap: 20, minCharge: 5, minChargePercentCap: 0.025,
      ),
      TradeSegment.equityFutures: _BrokerageRule.flat(20),
      TradeSegment.currencyFutures: _BrokerageRule.flat(20),
      TradeSegment.commodityFutures: _BrokerageRule.flat(20),
      TradeSegment.equityOptions: _BrokerageRule.flat(20),
      TradeSegment.currencyOptions: _BrokerageRule.flat(20),
      TradeSegment.commodityOptions: _BrokerageRule.flat(20),
    },
  ),
};

class _StatutoryRates {
  final double sttBuyRate;
  final double sttSellRate;
  final double exchangeTxnRate;
  final double stampDutyBuyRate;
  final double ipftRate;

  const _StatutoryRates({
    required this.sttBuyRate,
    required this.sttSellRate,
    required this.exchangeTxnRate,
    required this.stampDutyBuyRate,
    required this.ipftRate,
  });
}

class _ChargeResult {
  final double brokerage;
  final double sttOrCtt;
  final double exchangeTxn;
  final double sebi;
  final double stampDuty;
  final double ipft;
  final double dpCharge;
  final double gst;
  final double totalCharges;
  final double netPnl;
  final double breakEven;
  final String notes;

  const _ChargeResult({
    required this.brokerage,
    required this.sttOrCtt,
    required this.exchangeTxn,
    required this.sebi,
    required this.stampDuty,
    required this.ipft,
    required this.dpCharge,
    required this.gst,
    required this.totalCharges,
    required this.netPnl,
    required this.breakEven,
    required this.notes,
  });
}
