import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/utils.dart';
import '../../../data/models/broker_charges.dart';
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
  String _broker = 'zerodha';

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
    _broker = prefs.getString(AppConstants.prefChargesBroker) ?? 'zerodha';
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
    final chargesAsync = ref.watch(brokerChargesProvider);

    return chargesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Trade Charges')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Trade Charges')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48,
                    color: Colors.white38),
                const SizedBox(height: 12),
                Text(
                  'Could not load broker charges',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(brokerChargesProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) => _buildBody(data),
    );
  }

  Widget _buildBody(BrokerChargesResponse data) {
    final theme = Theme.of(context);

    // Ensure selected broker exists in API data
    if (!_custom && !data.brokers.containsKey(_broker)) {
      _broker = data.brokers.keys.firstOrNull ?? 'zerodha';
    }

    final broker = _selectedBroker(data);
    final breakdown = _calculate(data, broker);

    return Scaffold(
      appBar: AppBar(title: const Text('Trade Charges')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          // ── Header card ──
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
                if (data.lastUpdated.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rates updated: ${_formatDate(data.lastUpdated)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white38),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Trade setup card ──
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
                      labelText: 'Buy price (\u20b9)',
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
                      labelText: 'Sell price (\u20b9)',
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

          // ── Broker plan card ──
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
                      options: data.brokers.entries
                          .map(
                            (e) => AdaptiveSelectOption(
                              value: e.key,
                              label: e.value.name,
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
                    // Broker meta details
                    if (broker.amcYearly > 0 ||
                        broker.callTradeFee > 0 ||
                        broker.dpChargePerSellTransaction > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (broker.dpChargePerSellTransaction > 0)
                              _metaChip(
                                'DP',
                                '\u20b9${broker.dpChargePerSellTransaction.toStringAsFixed(2)}',
                              ),
                            if (broker.amcYearly > 0)
                              _metaChip(
                                'AMC/yr',
                                '\u20b9${broker.amcYearly.toStringAsFixed(0)}',
                              ),
                            if (broker.callTradeFee > 0)
                              _metaChip(
                                'Call trade',
                                '\u20b9${broker.callTradeFee.toStringAsFixed(0)}',
                              ),
                          ],
                        ),
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
                        labelText: 'Cap per order (\u20b9)',
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
                            'Flat fee per executed order (\u20b9) for options',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Charges breakdown card ──
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
                  'Total charges: \u20b9 ${Formatters.fullPrice(breakdown.totalCharges)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Net P&L after charges: \u20b9 ${Formatters.fullPrice(breakdown.netPnl)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: breakdown.netPnl >= 0
                        ? const Color(0xFF32D583)
                        : const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Break-even move: \u20b9 ${Formatters.fullPrice(breakdown.breakEven)} per unit',
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

  Widget _metaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(fontSize: 11, color: Colors.white54),
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
            '\u20b9 ${Formatters.fullPrice(amount)}',
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

  static String _segmentKey(TradeSegment segment) {
    switch (segment) {
      case TradeSegment.equityDelivery:
        return 'equity_delivery';
      case TradeSegment.equityIntraday:
        return 'equity_intraday';
      case TradeSegment.equityFutures:
        return 'equity_futures';
      case TradeSegment.equityOptions:
        return 'equity_options';
      case TradeSegment.currencyFutures:
        return 'currency_futures';
      case TradeSegment.currencyOptions:
        return 'currency_options';
      case TradeSegment.commodityFutures:
        return 'commodity_futures';
      case TradeSegment.commodityOptions:
        return 'commodity_options';
    }
  }

  static String _exchangeKey(TradeExchange exchange) {
    switch (exchange) {
      case TradeExchange.nse:
        return 'nse';
      case TradeExchange.bse:
        return 'bse';
      case TradeExchange.mcx:
        return 'mcx';
    }
  }

  _ResolvedBroker _selectedBroker(BrokerChargesResponse data) {
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
      return _ResolvedBroker.custom(
        pctPerSide: pct,
        capPerOrder: cap,
        flatPerOrder: flat,
      );
    }

    final preset = data.brokers[_broker];
    if (preset == null) {
      return _ResolvedBroker.custom(
          pctPerSide: 0, capPerOrder: 20, flatPerOrder: 20);
    }

    return _ResolvedBroker.fromPreset(preset);
  }

  _ChargeResult _calculate(
      BrokerChargesResponse data, _ResolvedBroker broker) {
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

    final segKey = _segmentKey(_segment);
    final exchKey = _exchangeKey(_exchange);

    // Get statutory rates from API data
    final statRate = data.statutory[segKey]?[exchKey];
    final sttBuyRate = statRate?.sttBuyRate ?? 0;
    final sttSellRate = statRate?.sttSellRate ?? 0;
    final exchangeTxnRate = statRate?.exchangeTxnRate ?? 0;
    final stampDutyBuyRate = statRate?.stampDutyBuyRate ?? 0;
    final ipftRate = statRate?.ipftRate ?? 0;
    final sebiFeeRate = statRate?.sebiFeeRate ?? 0.000001;

    final rule = broker.ruleForSegment(segKey);
    final brokerage = rule.sideCharge(buyValue) + rule.sideCharge(sellValue);

    final sttOrCtt = (buyValue * sttBuyRate) + (sellValue * sttSellRate);
    final exchangeTxn = turnover * exchangeTxnRate;
    final sebi = turnover * sebiFeeRate;
    final stampDuty = buyValue * stampDutyBuyRate;
    final ipft = turnover * ipftRate;

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

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return isoDate;
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
    _broker = prefs.getString(AppConstants.prefChargesBroker) ?? 'zerodha';
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
    _broker = 'zerodha';
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

// ── Internal models ──────────────────────────────────────────────────

enum _BrokerageMode { free, percentCap, flat }

class _BrokerageRule {
  final _BrokerageMode mode;
  final double pct;
  final double cap;
  final double minCharge;
  final double flatPerOrder;

  const _BrokerageRule.free()
      : mode = _BrokerageMode.free,
        pct = 0.0,
        cap = 0.0,
        minCharge = 0.0,
        flatPerOrder = 0.0;

  const _BrokerageRule.percentCap({
    required this.pct,
    required this.cap,
    this.minCharge = 0.0,
  })  : mode = _BrokerageMode.percentCap,
        flatPerOrder = 0.0;

  const _BrokerageRule.flat(this.flatPerOrder)
      : mode = _BrokerageMode.flat,
        pct = 0.0,
        cap = 0.0,
        minCharge = 0.0;

  factory _BrokerageRule.fromRate(BrokerSegmentRate rate) {
    switch (rate.mode) {
      case 'free':
        return const _BrokerageRule.free();
      case 'percent_cap':
        return _BrokerageRule.percentCap(
          pct: rate.pct,
          cap: rate.cap,
          minCharge: rate.minCharge,
        );
      case 'flat':
        return _BrokerageRule.flat(rate.flat);
      default:
        return _BrokerageRule.flat(rate.flat > 0 ? rate.flat : 20);
    }
  }

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
          charge = math.max(charge, minCharge);
        }
        return charge;
    }
  }
}

class _ResolvedBroker {
  final String name;
  final String tagline;
  final double dpChargePerSellTransaction;
  final bool dpChargeIncludesGst;
  final double amcYearly;
  final double callTradeFee;
  final Map<String, _BrokerageRule> _rules;

  _ResolvedBroker({
    required this.name,
    required this.tagline,
    required this.dpChargePerSellTransaction,
    required this.dpChargeIncludesGst,
    required this.amcYearly,
    required this.callTradeFee,
    required Map<String, _BrokerageRule> rules,
  }) : _rules = rules;

  factory _ResolvedBroker.fromPreset(BrokerPreset preset) {
    final rules = <String, _BrokerageRule>{};
    for (final entry in preset.segments.entries) {
      rules[entry.key] = _BrokerageRule.fromRate(entry.value);
    }
    return _ResolvedBroker(
      name: preset.name,
      tagline: preset.tagline,
      dpChargePerSellTransaction: preset.dpCharge,
      dpChargeIncludesGst: preset.dpIncludesGst,
      amcYearly: preset.amcYearly,
      callTradeFee: preset.callTradeFee,
      rules: rules,
    );
  }

  factory _ResolvedBroker.custom({
    required double pctPerSide,
    required double capPerOrder,
    required double flatPerOrder,
  }) {
    final pctRule = _BrokerageRule.percentCap(pct: pctPerSide, cap: capPerOrder);
    final flatRule = _BrokerageRule.flat(flatPerOrder);
    return _ResolvedBroker(
      name: 'Custom',
      tagline: 'Custom pricing model',
      dpChargePerSellTransaction: 15.93,
      dpChargeIncludesGst: true,
      amcYearly: 0,
      callTradeFee: 0,
      rules: {
        'equity_delivery': pctRule,
        'equity_intraday': pctRule,
        'equity_futures': pctRule,
        'currency_futures': pctRule,
        'commodity_futures': pctRule,
        'equity_options': flatRule,
        'currency_options': flatRule,
        'commodity_options': flatRule,
      },
    );
  }

  _BrokerageRule ruleForSegment(String segmentKey) {
    return _rules[segmentKey] ?? const _BrokerageRule.free();
  }
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
