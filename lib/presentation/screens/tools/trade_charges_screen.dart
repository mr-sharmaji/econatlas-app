import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/utils.dart';
import '../../../data/models/broker_charges.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'tax/tax_ui.dart';

/// Trade segment (category × sub-type).
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

/// Accent colors used by the other tool screens (capital gains / tax).
const Color _accentGreen = Color(0xFF00E676);
const Color _accentRed = Color(0xFFFF5252);
const Color _accentAmber = Color(0xFFFFAB40);

class TradeChargesScreen extends ConsumerStatefulWidget {
  const TradeChargesScreen({super.key});

  @override
  ConsumerState<TradeChargesScreen> createState() => _TradeChargesScreenState();
}

class _TradeChargesScreenState extends ConsumerState<TradeChargesScreen> {
  final _buyController = TextEditingController();
  final _sellController = TextEditingController();
  final _qtyController = TextEditingController();
  // Lot size — only meaningful for futures/options segments. For equity
  // delivery/intraday the input is hidden and lot size is implicitly 1.
  final _lotSizeController = TextEditingController();

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
    _lotSizeController.text =
        prefs.getString(AppConstants.prefChargesLotSize) ?? '75';
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
    _lotSizeController.dispose();
    _customBrokeragePctController.dispose();
    _customCapController.dispose();
    _customFlatController.dispose();
    super.dispose();
  }

  // ── Segment-mode classification ────────────────────────────────────
  //
  // Shares-mode segments trade in raw shares (equity delivery + intraday).
  // Lot-mode segments trade in contract lots × lot size (all futures and
  // all options across equity/currency/commodity). For lot-mode segments
  // we show a separate "Lot size" input and rename Quantity → "Lots".
  bool get _isLotBased {
    switch (_segment) {
      case TradeSegment.equityDelivery:
      case TradeSegment.equityIntraday:
        return false;
      case TradeSegment.equityFutures:
      case TradeSegment.equityOptions:
      case TradeSegment.currencyFutures:
      case TradeSegment.currencyOptions:
      case TradeSegment.commodityFutures:
      case TradeSegment.commodityOptions:
        return true;
    }
  }

  bool get _isOptionsSegment {
    return _segment == TradeSegment.equityOptions ||
        _segment == TradeSegment.currencyOptions ||
        _segment == TradeSegment.commodityOptions;
  }

  /// Contextual labels — "Buy price" is wrong for futures (entry price)
  /// and options (premium paid). Terminology follows market convention.
  String get _buyLabel {
    if (_isOptionsSegment) return 'Premium paid (\u20b9)';
    if (_isLotBased) return 'Entry price (\u20b9)';
    return 'Buy price (\u20b9)';
  }

  String get _sellLabel {
    if (_isOptionsSegment) return 'Premium received (\u20b9)';
    if (_isLotBased) return 'Exit price (\u20b9)';
    return 'Sell price (\u20b9)';
  }

  String get _qtyLabel =>
      _isLotBased ? 'Number of lots' : 'Quantity (shares)';

  /// Typical lot size hint per segment — shown as helper text so users
  /// know what to put in the Lot size field. Not enforced; users can
  /// override for stock-specific F&O where lot sizes vary.
  String get _lotSizeHelper {
    switch (_segment) {
      case TradeSegment.equityFutures:
      case TradeSegment.equityOptions:
        return 'Nifty 50: 75 · Bank Nifty: 30 · Stock F&O: varies';
      case TradeSegment.currencyFutures:
      case TradeSegment.currencyOptions:
        return 'USDINR: 1000 · EURINR: 1000 · GBPINR: 1000';
      case TradeSegment.commodityFutures:
      case TradeSegment.commodityOptions:
        return 'Gold: 100g · Gold Mini: 10g · Silver: 30kg · Crude: 100 bbl';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chargesAsync = ref.watch(brokerChargesProvider);

    // Wrap the whole Scaffold in a GestureDetector so tapping any empty
    // area dismisses the keyboard AND clears focus from the TextField.
    // TextField / dropdown / button taps are consumed by their widgets
    // first and don't reach this handler.
    //
    // NB: we deliberately use this tap-outside pattern instead of
    // WidgetsBindingObserver.didChangeMetrics — the other tool screens
    // in this app removed didChangeMetrics because viewInsets.bottom
    // drops to 0 transiently during the keyboard OPEN animation, which
    // caused premature unfocus and made it impossible to type.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trade Charges'),
          actions: [
            IconButton(
              tooltip: 'Refresh rates',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(brokerChargesProvider),
            ),
          ],
        ),
        body: chargesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(14),
            child: ShimmerCard(height: 320),
          ),
          error: (err, _) => ErrorView(
            message: friendlyErrorMessage(err),
            onRetry: () => ref.invalidate(brokerChargesProvider),
          ),
          data: (data) => _buildBody(theme, data),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, BrokerChargesResponse data) {
    // Ensure selected broker exists in API data
    if (!_custom && !data.brokers.containsKey(_broker)) {
      _broker = data.brokers.keys.firstOrNull ?? 'zerodha';
    }

    final broker = _selectedBroker(data);
    final breakdown = _calculate(data, broker);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 150),
          children: [
            // ── Helper card ──
            taxHelperCard(
              theme: theme,
              title: 'How this estimator works',
              points: [
                'Broker brokerage + govt. / exchange levies on both sides.',
                'STT, stamp duty, SEBI fee & GST follow 2025-26 rates.',
                if (data.lastUpdated.isNotEmpty)
                  'Rates refreshed ${_formatDate(data.lastUpdated)}.',
              ],
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trade setup',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _resetDefaults,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AdaptiveSelectField<TradeSegment>(
                      label: 'Segment',
                      value: _segment,
                      decoration: modernTaxInputDecoration(
                        theme,
                        label: 'Segment',
                        icon: Icons.candlestick_chart_rounded,
                      ),
                      options: TradeSegment.values
                          .map(
                            (s) => AdaptiveSelectOption(
                              value: s,
                              label: _segmentLabel(s),
                              subtitle: _segmentSubtitle(s),
                              searchTokens: [
                                _segmentLabel(s),
                                _segmentCategory(s),
                              ],
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
                      decoration: modernTaxInputDecoration(
                        theme,
                        label: 'Exchange',
                        icon: Icons.hub_rounded,
                      ),
                      options: _allowedExchanges(_segment)
                          .map(
                            (e) => AdaptiveSelectOption(
                              value: e,
                              label: _exchangeLabel(e),
                              subtitle: _exchangeFullName(e),
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
                    // Buy/Entry + Sell/Exit side by side (labels depend
                    // on segment — "Premium paid/received" for options,
                    // "Entry/Exit price" for other lot-based segments).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _buyController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: _buyLabel,
                              icon: _isOptionsSegment
                                  ? Icons.call_made_rounded
                                  : Icons.south_rounded,
                            ),
                            onChanged: (v) {
                              ref.read(sharedPreferencesProvider).setString(
                                    AppConstants.prefChargesBuyPrice,
                                    v.trim(),
                                  );
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _sellController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: _sellLabel,
                              icon: _isOptionsSegment
                                  ? Icons.call_received_rounded
                                  : Icons.north_rounded,
                            ),
                            onChanged: (v) {
                              ref.read(sharedPreferencesProvider).setString(
                                    AppConstants.prefChargesSellPrice,
                                    v.trim(),
                                  );
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Lots + Lot size (for F&O segments) OR Quantity
                    // (for equity delivery/intraday).
                    if (_isLotBased)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qtyController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              decoration: modernTaxInputDecoration(
                                theme,
                                label: _qtyLabel,
                                icon: Icons.inventory_2_rounded,
                              ),
                              onChanged: (v) {
                                ref.read(sharedPreferencesProvider).setString(
                                      AppConstants.prefChargesQuantity,
                                      v.trim(),
                                    );
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _lotSizeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              decoration: modernTaxInputDecoration(
                                theme,
                                label: 'Lot size',
                                icon: Icons.view_module_rounded,
                              ),
                              onChanged: (v) {
                                ref.read(sharedPreferencesProvider).setString(
                                      AppConstants.prefChargesLotSize,
                                      v.trim(),
                                    );
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      TextField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: modernTaxInputDecoration(
                          theme,
                          label: _qtyLabel,
                          icon: Icons.format_list_numbered_rounded,
                        ),
                        onChanged: (v) {
                          ref.read(sharedPreferencesProvider).setString(
                                AppConstants.prefChargesQuantity,
                                v.trim(),
                              );
                          setState(() {});
                        },
                      ),
                    if (_isLotBased && _lotSizeHelper.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _lotSizeHelper,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
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
                    if (!_custom)
                      AdaptiveSelectField<String>(
                        label: 'Broker',
                        value: _broker,
                        decoration: modernTaxInputDecoration(
                          theme,
                          label: 'Broker',
                          icon: Icons.apartment_rounded,
                        ),
                        options: data.brokers.entries
                            .map(
                              (e) => AdaptiveSelectOption(
                                value: e.key,
                                label: e.value.name,
                                subtitle: e.value.tagline,
                                searchTokens: [e.value.name, e.value.tagline],
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
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _customBrokeragePctController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Brokerage % per side',
                              helper: '0.03 means 0.03% of side value',
                              icon: Icons.percent_rounded,
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Cap per order (\u20b9)',
                              icon: Icons.hourglass_bottom_rounded,
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Flat fee for options (\u20b9)',
                              icon: Icons.price_change_rounded,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    // Broker info strip (only when preset, not custom)
                    if (!_custom) _brokerInfoStrip(theme, broker),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      value: _custom,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Use custom brokerage'),
                      subtitle: const Text(
                          'Override with your own rate / cap / flat fee'),
                      onChanged: (value) {
                        _custom = value;
                        ref.read(sharedPreferencesProvider).setBool(
                              AppConstants.prefChargesCustomBroker,
                              value,
                            );
                        setState(() {});
                      },
                    ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Charges breakdown',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _turnoverChip(theme, breakdown.turnover),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _breakdownRow(theme, 'Brokerage', breakdown.brokerage,
                        icon: Icons.account_balance_wallet_rounded),
                    _breakdownRow(theme, 'STT / CTT', breakdown.sttOrCtt,
                        icon: Icons.receipt_long_rounded),
                    _breakdownRow(theme, 'Exchange transaction',
                        breakdown.exchangeTxn,
                        icon: Icons.swap_horiz_rounded),
                    _breakdownRow(
                        theme, 'SEBI turnover fee', breakdown.sebi,
                        icon: Icons.verified_user_rounded),
                    _breakdownRow(theme, 'Stamp duty', breakdown.stampDuty,
                        icon: Icons.approval_rounded),
                    if (breakdown.ipft > 0)
                      _breakdownRow(
                          theme, 'IPFT / investor fund', breakdown.ipft,
                          icon: Icons.shield_rounded),
                    if (breakdown.dpCharge > 0)
                      _breakdownRow(theme, 'DP charge', breakdown.dpCharge,
                          icon: Icons.savings_rounded),
                    _breakdownRow(theme, 'GST (18%)', breakdown.gst,
                        icon: Icons.policy_rounded),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    _breakdownRow(
                      theme,
                      'Total charges',
                      breakdown.totalCharges,
                      strong: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      breakdown.notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Glass result bar (bottom) ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: glassResultBar(
            theme: theme,
            bottomInset: MediaQuery.of(context).padding.bottom,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total charges',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\u20b9 ${Formatters.fullPrice(breakdown.totalCharges)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Net P&L',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _signedRupee(breakdown.netPnl),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: breakdown.netPnl >= 0
                              ? _accentGreen
                              : _accentRed,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: 14,
                    color: _accentAmber.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Break-even move: \u20b9 ${Formatters.fullPrice(breakdown.breakEven)} per unit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────

  Widget _breakdownRow(
    ThemeData theme,
    String label,
    double amount, {
    IconData? icon,
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                icon,
                size: 15,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 10),
          ] else
            const SizedBox(width: 36),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: strong ? Colors.white : Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
          Text(
            '\u20b9 ${Formatters.fullPrice(amount)}',
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontSize: strong ? 15 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _turnoverChip(ThemeData theme, double turnover) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync_alt_rounded,
              size: 12, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 5),
          Text(
            'Turnover \u20b9 ${Formatters.fullPrice(turnover)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brokerInfoStrip(ThemeData theme, _ResolvedBroker broker) {
    final chips = <Widget>[];
    if (broker.dpChargePerSellTransaction > 0) {
      chips.add(_infoChip(theme, Icons.savings_rounded, 'DP',
          '\u20b9${broker.dpChargePerSellTransaction.toStringAsFixed(2)}'));
    }
    if (broker.callTradeFee > 0) {
      chips.add(_infoChip(theme, Icons.call_rounded, 'Call trade',
          '\u20b9${broker.callTradeFee.toStringAsFixed(0)}'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          broker.tagline,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
        if (broker.amcRules.isNotEmpty || broker.amcNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          _amcDetailsBlock(theme, broker),
        ],
      ],
    );
  }

  Widget _amcDetailsBlock(ThemeData theme, _ResolvedBroker broker) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.event_repeat_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Annual Maintenance Charge',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (broker.amcNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              broker.amcNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (broker.amcRules.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...broker.amcRules.map(
              (rule) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rule,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _signedRupee(double amount) {
    final sign = amount >= 0 ? '' : '-';
    return '$sign\u20b9 ${Formatters.fullPrice(amount.abs())}';
  }

  // ── Calculation logic ──────────────────────────────────────────────

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

  String _exchangeFullName(TradeExchange exchange) {
    switch (exchange) {
      case TradeExchange.nse:
        return 'National Stock Exchange';
      case TradeExchange.bse:
        return 'Bombay Stock Exchange';
      case TradeExchange.mcx:
        return 'Multi Commodity Exchange';
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

  String _segmentCategory(TradeSegment segment) {
    switch (segment) {
      case TradeSegment.equityDelivery:
      case TradeSegment.equityIntraday:
      case TradeSegment.equityFutures:
      case TradeSegment.equityOptions:
        return 'Equity';
      case TradeSegment.currencyFutures:
      case TradeSegment.currencyOptions:
        return 'Currency';
      case TradeSegment.commodityFutures:
      case TradeSegment.commodityOptions:
        return 'Commodity';
    }
  }

  String _segmentSubtitle(TradeSegment segment) {
    switch (segment) {
      case TradeSegment.equityDelivery:
        return 'Shares, held across sessions · STT on buy + sell';
      case TradeSegment.equityIntraday:
        return 'Shares, same-day square-off · STT sell side only';
      case TradeSegment.equityFutures:
        return 'Lots × lot size (Nifty 75, BankNifty 30) · STT 0.02% sell';
      case TradeSegment.equityOptions:
        return 'Premium × lots × lot size · STT 0.1% premium sell';
      case TradeSegment.currencyFutures:
        return 'Rate × contract size (USDINR = \$1000) · no STT · NSE only';
      case TradeSegment.currencyOptions:
        return 'Premium × contract size · no STT · NSE only';
      case TradeSegment.commodityFutures:
        return 'Price × contract size (Gold 100g, Silver 30kg) · CTT 0.01% · MCX';
      case TradeSegment.commodityOptions:
        return 'Premium × contract size · CTT 0.05% premium sell · MCX';
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

    // For lot-based segments (futures/options), effective units traded
    // = number of lots × lot size. For equity delivery/intraday, lot
    // size is implicitly 1 (the user's "qty" is already share count).
    final lotSize = _isLotBased
        ? math.max(
            0.0, double.tryParse(_lotSizeController.text.trim()) ?? 0.0)
        : 1.0;
    final effectiveQty = qty * lotSize;

    final buyValue = buy * effectiveQty;
    final sellValue = sell * effectiveQty;
    final turnover = buyValue + sellValue;
    final grossPnl = (sell - buy) * effectiveQty;

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
    // Break-even move per unit — works for both modes. For F&O, this
    // is per-unit of the underlying (e.g. per share of Nifty), not
    // per lot, so the user can compare it directly to the LTP.
    final breakEven = effectiveQty > 0 ? totalCharges / effectiveQty : 0.0;

    final notes = StringBuffer(
      '${_exchangeLabel(_exchange)} rates, 2025-26. Broker pricing can '
      'change; confirm before order.',
    );
    if (_isOptionsSegment) {
      notes.write(
        ' Options exercise STT (0.125% of intrinsic value on ITM expiry) '
        'is not modeled — applies only to positions held to expiry.',
      );
    }
    if (_isLotBased) {
      notes.write(
        ' Turnover uses lots × lot size × price; verify the lot size '
        'for your specific contract before placing the order.',
      );
    }

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
      turnover: turnover,
      notes: notes.toString(),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  void _resetDefaults() {
    _buyController.text = '100';
    _sellController.text = '102';
    _qtyController.text = '100';
    _lotSizeController.text = '75';
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
    prefs.setString(AppConstants.prefChargesLotSize, '75');
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
  final String amcNote;
  final List<String> amcRules;
  final double callTradeFee;
  final Map<String, _BrokerageRule> _rules;

  _ResolvedBroker({
    required this.name,
    required this.tagline,
    required this.dpChargePerSellTransaction,
    required this.dpChargeIncludesGst,
    required this.amcYearly,
    required this.amcNote,
    required this.amcRules,
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
      amcNote: preset.amcNote,
      amcRules: preset.amcRules,
      callTradeFee: preset.callTradeFee,
      rules: rules,
    );
  }

  factory _ResolvedBroker.custom({
    required double pctPerSide,
    required double capPerOrder,
    required double flatPerOrder,
  }) {
    final pctRule =
        _BrokerageRule.percentCap(pct: pctPerSide, cap: capPerOrder);
    final flatRule = _BrokerageRule.flat(flatPerOrder);
    return _ResolvedBroker(
      name: 'Custom',
      tagline: 'Custom pricing model',
      dpChargePerSellTransaction: 15.93,
      dpChargeIncludesGst: true,
      amcYearly: 0,
      amcNote: '',
      amcRules: const [],
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
  final double turnover;
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
    required this.turnover,
    required this.notes,
  });
}
