import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/square_badge_assets.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/econ_calendar_event.dart';
import '../../../data/models/macro_forecast.dart';
import '../../../data/models/macro_indicator.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../discover/widgets/sparkline_widget.dart';

// =============================================================================
// Helpers
// =============================================================================

String _countryLabel(String c) => c == 'IN' ? 'India' : c == 'US' ? 'United States' : c;

Color _vColor(String n, double v) {
  switch (n) {
    case 'inflation': case 'core_inflation':
      return v > 6 ? AppTheme.accentRed : v > 4 ? AppTheme.accentOrange : AppTheme.accentGreen;
    case 'unemployment':
      return v > 6 ? AppTheme.accentRed : v > 4 ? AppTheme.accentOrange : AppTheme.accentGreen;
    case 'gdp_growth': case 'iip': case 'bank_credit_growth':
      return v >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    case 'pmi_manufacturing': case 'pmi_services':
      return v >= 50 ? AppTheme.accentGreen : AppTheme.accentRed;
    default: return Colors.white70;
  }
}

(String, Color) _ctx(String n, double v, String c) {
  switch (n) {
    case 'gdp_growth':
      return v > 6 ? ('Strong growth', AppTheme.accentGreen) : v > 3 ? ('Moderate', AppTheme.accentGreen) : v > 0 ? ('Slow', AppTheme.accentOrange) : ('Contraction', AppTheme.accentRed);
    case 'inflation':
      final t = c == 'IN' ? 4.0 : 2.0;
      return v > t + 2 ? ('Above target', AppTheme.accentRed) : v > t ? ('Near target', AppTheme.accentOrange) : ('Below target', AppTheme.accentGreen);
    case 'core_inflation':
      return v > 5 ? ('Sticky', AppTheme.accentRed) : v > 3 ? ('Elevated', AppTheme.accentOrange) : ('Moderate', AppTheme.accentGreen);
    case 'unemployment':
      return v > 6 ? ('High', AppTheme.accentRed) : v > 4 ? ('Moderate', AppTheme.accentOrange) : ('Low', AppTheme.accentGreen);
    case 'pmi_manufacturing': case 'pmi_services':
      return v >= 55 ? ('Strong expansion', AppTheme.accentGreen) : v >= 50 ? ('Expansion', AppTheme.accentGreen) : ('Contraction', AppTheme.accentRed);
    case 'iip':
      return v > 5 ? ('Strong output', AppTheme.accentGreen) : v > 0 ? ('Positive', AppTheme.accentGreen) : ('Declining', AppTheme.accentRed);
    case 'trade_balance':
      return v < 0 ? ('Trade deficit', AppTheme.accentOrange) : ('Surplus', AppTheme.accentGreen);
    case 'fiscal_deficit':
      return v > 5 ? ('Wide', AppTheme.accentRed) : v > 3 ? ('Moderate', AppTheme.accentOrange) : ('Disciplined', AppTheme.accentGreen);
    case 'bond_yield_10y':
      return ('10Y Yield', Colors.white54);
    default: return ('', Colors.white38);
  }
}

MacroIndicator? _latest(List<MacroIndicator> list, String name, String country) {
  MacroIndicator? best;
  for (final i in list) {
    if (i.indicatorName == name && i.country == country) {
      if (best == null || i.timestamp.isAfter(best.timestamp)) best = i;
    }
  }
  return best;
}

/// Extract last N values for sparkline from history
List<double> _sparkValues(List<MacroIndicator> history, String name, String country, {int maxPoints = 24}) {
  final series = history
      .where((i) => i.indicatorName == name && i.country == country)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (series.length < 2) return [];
  final start = series.length > maxPoints ? series.length - maxPoints : 0;
  return series.sublist(start).map((i) => i.value).toList();
}

/// Compute change from previous value
(double? delta, String label) _deltaInfo(List<MacroIndicator> history, MacroIndicator current) {
  final series = history
      .where((i) => i.indicatorName == current.indicatorName && i.country == current.country)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (series.length < 2) return (null, '');
  final prev = series[series.length - 2];
  final delta = current.value - prev.value;
  final sign = delta >= 0 ? '+' : '';
  if (current.indicatorName.contains('pmi')) return (delta, '$sign${delta.toStringAsFixed(1)}');
  return (delta, '$sign${delta.toStringAsFixed(2)} pp');
}

Color _instColor(String i) => i == 'RBI' ? AppTheme.accentOrange : i == 'Fed' ? AppTheme.accentBlue : Colors.white54;

(String, Color) _richExplainer(String name, double value, String country) {
  final cn = _countryLabel(country);
  switch (name) {
    case 'gdp_growth':
      if (value > 6) return ('$cn GDP grew ${value.toStringAsFixed(1)}%, indicating robust expansion driven by strong domestic demand and investment.', AppTheme.accentGreen);
      if (value > 0) return ('$cn GDP growth of ${value.toStringAsFixed(1)}% — positive but moderate expansion.', AppTheme.accentGreen);
      return ('$cn GDP contracted ${value.abs().toStringAsFixed(1)}%, signaling recession.', AppTheme.accentRed);
    case 'inflation':
      final t = country == 'IN' ? 4.0 : 2.0;
      if (value > t + 2) return ('Inflation at ${value.toStringAsFixed(1)}% is well above the ${t.toInt()}% target. May trigger rate hikes.', AppTheme.accentRed);
      return ('Inflation at ${value.toStringAsFixed(1)}% — ${value <= t ? "below target, giving room for rate cuts" : "near target, central bank monitoring"}.', value <= t ? AppTheme.accentGreen : AppTheme.accentOrange);
    case 'core_inflation':
      return ('Core inflation (ex food & fuel) at ${value.toStringAsFixed(1)}%. ${value > 4 ? "Sticky and elevated." : "Well-contained."}', value > 4 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'unemployment':
      return ('${value.toStringAsFixed(1)}% unemployment. ${value > 5 ? "Weak labor demand." : "Tight labor market."}', value > 5 ? AppTheme.accentRed : AppTheme.accentGreen);
    case 'repo_rate':
      return ('Policy rate at ${value.toStringAsFixed(2)}% set by the ${country == "IN" ? "RBI" : "Fed"}. Influences all borrowing costs across the economy.', Colors.white70);
    case 'pmi_manufacturing':
      return ('Manufacturing PMI ${value.toStringAsFixed(1)}. ${value >= 50 ? "Above 50 = expansion." : "Below 50 = contraction."}', value >= 50 ? AppTheme.accentGreen : AppTheme.accentRed);
    case 'pmi_services':
      return ('Services PMI ${value.toStringAsFixed(1)}. Services = 50-70% of the economy. ${value >= 50 ? "Healthy expansion." : "Concerning contraction."}', value >= 50 ? AppTheme.accentGreen : AppTheme.accentRed);
    case 'iip':
      return ('Industrial production ${value >= 0 ? "grew" : "fell"} ${value.abs().toStringAsFixed(1)}% YoY.', value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed);
    case 'forex_reserves':
      return ('Forex reserves \$${(value / 1000).toStringAsFixed(0)}B — buffer against external shocks.', Colors.white70);
    case 'trade_balance':
      return ('Trade ${value < 0 ? "deficit" : "surplus"} \$${value.abs().toStringAsFixed(1)}B. ${value < 0 ? "Imports > exports." : "Exports > imports."}', value < 0 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'current_account_deficit':
      return ('Current account ${value < 0 ? "deficit" : "surplus"} \$${value.abs().toStringAsFixed(1)}B.', value < 0 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'fiscal_deficit':
      return ('Fiscal deficit ${value.toStringAsFixed(1)}% of GDP. ${value > 5 ? "Wide — may crowd out private investment." : "Manageable."}', value > 5 ? AppTheme.accentRed : AppTheme.accentOrange);
    case 'bank_credit_growth':
      return ('Bank lending growing ${value.toStringAsFixed(1)}%. Reflects credit demand.', Colors.white70);
    case 'bond_yield_10y':
      return ('10-year government bond yield at ${value.toStringAsFixed(2)}%. Benchmark for fixed income and mortgage rates.', Colors.white70);
    case 'bond_yield_2y':
      return ('2-year treasury yield at ${value.toStringAsFixed(2)}%. Short-term rate expectations.', Colors.white70);
    default:
      return ('${displayName(name)}: ${value.toStringAsFixed(2)}', Colors.white54);
  }
}

// =============================================================================
// MacroScreen
// =============================================================================

class MacroScreen extends ConsumerStatefulWidget {
  const MacroScreen({super.key});
  @override
  ConsumerState<MacroScreen> createState() => _MacroScreenState();
}

class _MacroScreenState extends ConsumerState<MacroScreen> {
  late final ScrollController _sc;

  @override
  void initState() { super.initState(); _sc = ScrollController(); }
  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  void _scrollToTop() {
    if (_sc.hasClients) _sc.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _showExplainer(MacroIndicator ind) {
    final (text, color) = _richExplainer(ind.indicatorName, ind.value, ind.country);
    final value = Formatters.macroValue(ind.value, ind.indicatorName);
    final (label, _) = _ctx(ind.indicatorName, ind.value, ind.country);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Container(height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(displayName(ind.indicatorName), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ]),
          if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
          const SizedBox(height: 8),
          Text('${_countryLabel(ind.country)} · ${DateFormat("MMM yyyy").format(ind.timestamp)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(4), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final latestAsync = ref.watch(allMacroIndicatorsProvider);
    final inHistAsync = ref.watch(indiaHistoryProvider);
    final usHistAsync = ref.watch(usHistoryProvider);
    final forecastAsync = ref.watch(macroForecastsProvider);
    final calendarAsync = ref.watch(econCalendarProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Economy'),
        actions: [IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined))],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allMacroIndicatorsProvider);
          ref.invalidate(indiaHistoryProvider);
          ref.invalidate(usHistoryProvider);
          ref.invalidate(macroForecastsProvider);
          ref.invalidate(econCalendarProvider);
        },
        child: latestAsync.when(
          loading: () => ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [ShimmerList(itemCount: 6)]),
          error: (err, _) => ListView(physics: const AlwaysScrollableScrollPhysics(), children: [ErrorView(message: friendlyErrorMessage(err), onRetry: () => ref.invalidate(allMacroIndicatorsProvider))]),
          data: (latest) {
            final all = latest.where((i) => i.indicatorName != 'fii_net_cash' && i.indicatorName != 'dii_net_cash').toList();
            if (all.isEmpty) return const EmptyView(message: 'No data', icon: Icons.analytics_outlined);

            final inHist = inHistAsync.valueOrNull ?? [];
            final usHist = usHistAsync.valueOrNull ?? [];
            final forecasts = forecastAsync.valueOrNull ?? [];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _sc,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
              children: [
                // ── Upcoming Events ──
                calendarAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(children: events.take(2).map((e) => _EventRow(event: e)).toList()),
                    );
                  },
                ),

                // ── India ──
                _CountryHeader(code: 'IN'),
                const SizedBox(height: 8),

                // GDP & Growth card with sparkline
                _ChartMetricCard(
                  title: 'GDP & Growth',
                  icon: Icons.trending_up,
                  chartMetric: 'gdp_growth',
                  country: 'IN',
                  latest: all,
                  history: inHist,
                  metrics: ['gdp_growth', 'pmi_manufacturing', 'pmi_services', 'iip'],
                  forecasts: forecasts,
                  onTap: _showExplainer,
                ),

                // Inflation card with sparkline
                _ChartMetricCard(
                  title: 'Inflation',
                  icon: Icons.price_change,
                  chartMetric: 'inflation',
                  country: 'IN',
                  latest: all,
                  history: inHist,
                  metrics: ['inflation', 'core_inflation', 'repo_rate'],
                  onTap: _showExplainer,
                ),

                // Bond Yields
                _ChartMetricCard(
                  title: 'Bond Yields & Rates',
                  icon: Icons.account_balance,
                  chartMetric: 'bond_yield_10y',
                  country: 'IN',
                  latest: all,
                  history: inHist,
                  metrics: ['bond_yield_10y', 'repo_rate'],
                  onTap: _showExplainer,
                ),

                // External & Fiscal
                _ChartMetricCard(
                  title: 'External & Fiscal',
                  icon: Icons.public,
                  chartMetric: 'trade_balance',
                  country: 'IN',
                  latest: all,
                  history: inHist,
                  metrics: ['trade_balance', 'forex_reserves', 'current_account_deficit', 'fiscal_deficit', 'bank_credit_growth'],
                  onTap: _showExplainer,
                ),

                const SizedBox(height: 16),

                // ── US ──
                _CountryHeader(code: 'US'),
                const SizedBox(height: 8),

                _ChartMetricCard(
                  title: 'GDP & Growth',
                  icon: Icons.trending_up,
                  chartMetric: 'gdp_growth',
                  country: 'US',
                  latest: all,
                  history: usHist,
                  metrics: ['gdp_growth', 'pmi_manufacturing', 'pmi_services', 'iip'],
                  forecasts: forecasts,
                  onTap: _showExplainer,
                ),

                _ChartMetricCard(
                  title: 'Inflation & Rates',
                  icon: Icons.price_change,
                  chartMetric: 'inflation',
                  country: 'US',
                  latest: all,
                  history: usHist,
                  metrics: ['inflation', 'core_inflation', 'repo_rate'],
                  onTap: _showExplainer,
                ),

                _ChartMetricCard(
                  title: 'Bond Yields',
                  icon: Icons.account_balance,
                  chartMetric: 'bond_yield_10y',
                  country: 'US',
                  latest: all,
                  history: usHist,
                  metrics: ['bond_yield_10y', 'bond_yield_2y'],
                  onTap: _showExplainer,
                ),

                _ChartMetricCard(
                  title: 'Trade',
                  icon: Icons.swap_horiz,
                  chartMetric: 'trade_balance',
                  country: 'US',
                  latest: all,
                  history: usHist,
                  metrics: ['trade_balance', 'unemployment'],
                  onTap: _showExplainer,
                ),

                // ── Actual vs Forecast ──
                if (forecasts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Actual vs IMF Forecast', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _ActualVsForecastCard(
                    indicatorName: 'gdp_growth',
                    label: 'GDP Growth',
                    inHistory: inHist,
                    usHistory: usHist,
                    forecasts: forecasts,
                  ),
                  _ActualVsForecastCard(
                    indicatorName: 'inflation',
                    label: 'Inflation',
                    inHistory: inHist,
                    usHistory: usHist,
                    forecasts: forecasts,
                  ),
                ],

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Event Row — full context
// =============================================================================

class _EventRow extends StatelessWidget {
  final EconCalendarEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = event.eventDate.difference(DateTime.now()).inDays;
    final ic = _instColor(event.institution);
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(event.eventDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ic.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ic.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        SquareBadgeSvg(assetPath: SquareBadgeAssets.flagPathForCountryCode(event.country), size: 18, borderRadius: 3),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.eventName, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38, fontSize: 10)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: ic.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(
            days == 0 ? 'Today' : days == 1 ? 'Tomorrow' : '${days}d',
            style: TextStyle(color: ic, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// Country Header
// =============================================================================

class _CountryHeader extends StatelessWidget {
  final String code;
  const _CountryHeader({required this.code});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SquareBadgeSvg(assetPath: SquareBadgeAssets.flagPathForCountryCode(code), size: 20, borderRadius: 4),
      const SizedBox(width: 8),
      Text(_countryLabel(code), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

// =============================================================================
// Chart Metric Card — sparkline + metric rows with deltas
// =============================================================================

class _ChartMetricCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String chartMetric; // which metric to chart
  final String country;
  final List<MacroIndicator> latest;
  final List<MacroIndicator> history;
  final List<String> metrics;
  final List<MacroForecast>? forecasts;
  final ValueChanged<MacroIndicator> onTap;

  const _ChartMetricCard({
    required this.title, required this.icon, required this.chartMetric,
    required this.country, required this.latest, required this.history,
    required this.metrics, this.forecasts, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Filter to metrics with data
    final available = metrics.where((m) => _latest(latest, m, country) != null).toList();
    if (available.isEmpty) return const SizedBox.shrink();

    // Sparkline data
    final sparkData = _sparkValues(history, chartMetric, country);
    final hasChart = sparkData.length >= 3;
    final chartColor = () {
      final ind = _latest(latest, chartMetric, country);
      return ind != null ? _vColor(chartMetric, ind.value) : AppTheme.accentBlue;
    }();

    // Forecast for headline metric
    String? forecastHint;
    if (forecasts != null) {
      final year = DateTime.now().year;
      final fc = forecasts!.where((f) => f.indicatorName == chartMetric && f.country == country && f.forecastYear == year).firstOrNull;
      if (fc != null) forecastHint = 'IMF ${fc.forecastYear}F: ${fc.value.toStringAsFixed(1)}%';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title row
            Row(children: [
              Icon(icon, size: 16, color: AppTheme.accentBlue),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
              if (forecastHint != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(forecastHint, style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.accentBlue, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),

            // Sparkline chart
            if (hasChart) ...[
              const SizedBox(height: 10),
              SparklineWidget(values: sparkData, color: chartColor, height: 48),
            ],

            const SizedBox(height: 8),
            // Metric rows
            ...available.map((name) {
              final ind = _latest(latest, name, country)!;
              final (delta, deltaLabel) = _deltaInfo(history, ind);
              final (ctxLabel, ctxColor) = _ctx(name, ind.value, country);
              final value = Formatters.macroValue(ind.value, ind.indicatorName);

              return InkWell(
                onTap: () => onTap(ind),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(displayName(name), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline, size: 11, color: Colors.white24),
                      ]),
                      Row(children: [
                        if (ctxLabel.isNotEmpty) Text(ctxLabel, style: theme.textTheme.labelSmall?.copyWith(color: ctxColor, fontSize: 9)),
                        if (ctxLabel.isNotEmpty && deltaLabel.isNotEmpty) Text(' · ', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white24, fontSize: 9)),
                        if (deltaLabel.isNotEmpty) Text(deltaLabel, style: theme.textTheme.labelSmall?.copyWith(
                          color: delta != null && delta >= 0 ? AppTheme.accentGreen : AppTheme.accentRed, fontSize: 9, fontWeight: FontWeight.w600)),
                      ]),
                    ])),
                    Text(value, style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700, color: _vColor(name, ind.value),
                      fontFeatures: const [FontFeature.tabularFigures()])),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// Actual vs Forecast Card — historical line + forecast dots
// =============================================================================

class _ActualVsForecastCard extends StatelessWidget {
  final String indicatorName;
  final String label;
  final List<MacroIndicator> inHistory;
  final List<MacroIndicator> usHistory;
  final List<MacroForecast> forecasts;

  const _ActualVsForecastCard({
    required this.indicatorName, required this.label,
    required this.inHistory, required this.usHistory, required this.forecasts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get last 10 years of actual data for India
    final now = DateTime.now();
    final cutoff = DateTime(now.year - 10);
    final inActual = inHistory
        .where((i) => i.indicatorName == indicatorName && i.country == 'IN' && i.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final inFc = forecasts.where((f) => f.indicatorName == indicatorName && f.country == 'IN').toList()
      ..sort((a, b) => a.forecastYear.compareTo(b.forecastYear));

    final usFc = forecasts.where((f) => f.indicatorName == indicatorName && f.country == 'US').toList()
      ..sort((a, b) => a.forecastYear.compareTo(b.forecastYear));

    if (inActual.isEmpty && inFc.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            // Forecast table: actual latest + projected years
            _forecastRows(theme, 'IN', 'India', inActual, inFc),
            if (usFc.isNotEmpty) ...[
              const SizedBox(height: 4),
              _forecastRows(theme, 'US', 'US', [], usFc),
            ],
            const SizedBox(height: 4),
            Text('Source: IMF WEO · Actual data from FRED', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white24, fontSize: 8)),
          ]),
        ),
      ),
    );
  }

  Widget _forecastRows(ThemeData theme, String code, String label,
      List<MacroIndicator> actuals, List<MacroForecast> fcs) {
    // Show: latest actual + next 3 forecast years
    final latestActual = actuals.isNotEmpty ? actuals.last : null;
    final nextFcs = fcs.where((f) => f.forecastYear >= DateTime.now().year).take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SquareBadgeSvg(assetPath: SquareBadgeAssets.flagPathForCountryCode(code), size: 14, borderRadius: 2),
        const SizedBox(width: 6),
        SizedBox(width: 36, child: Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600))),
        if (latestActual != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text('${latestActual.value.toStringAsFixed(1)}%', style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.accentGreen, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Text(' actual', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38, fontSize: 9)),
        ],
        const SizedBox(width: 6),
        Text('→', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white24)),
        const SizedBox(width: 6),
        ...nextFcs.map((fc) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text('${fc.value.toStringAsFixed(1)}% ${fc.forecastYear}F',
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54, fontSize: 9, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        )),
      ]),
    );
  }
}

// =============================================================================
// Detail Screen (preserved)
// =============================================================================

class MacroDetailScreen extends ConsumerStatefulWidget {
  final String indicatorName;
  final MacroIndicator? initialIndicator;
  final String? countryOverride;
  const MacroDetailScreen({super.key, required this.indicatorName, this.countryOverride, this.initialIndicator});
  @override
  ConsumerState<MacroDetailScreen> createState() => _MacroDetailScreenState();
}

class _MacroDetailScreenState extends ConsumerState<MacroDetailScreen> {
  ChartRange _chartRange = ChartRange.oneYear;
  final ScrollController _rsc = ScrollController();
  bool _showHint = true;

  @override
  void initState() { super.initState(); _rsc.addListener(_onScroll); WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll()); }
  @override
  void dispose() { _rsc.removeListener(_onScroll); _rsc.dispose(); super.dispose(); }
  void _onScroll() { if (!_rsc.hasClients) return; final atEnd = _rsc.offset >= _rsc.position.maxScrollExtent - 4; if (_showHint == atEnd) setState(() => _showHint = !atEnd); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String country = widget.initialIndicator?.country ?? widget.countryOverride ?? ref.watch(selectedCountryProvider);
    final histAsync = ref.watch(macroHistoryProvider(country));

    return Scaffold(
      appBar: AppBar(title: Text(displayName(widget.indicatorName))),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(macroHistoryProvider(country)),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.initialIndicator != null) ...[_topCard(theme, histAsync.valueOrNull), const SizedBox(height: 16)],
          Text('Historical Data', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _rangeChips(context),
          const SizedBox(height: 12),
          histAsync.when(
            loading: () => const ShimmerCard(height: 200),
            error: (err, _) => ErrorView(message: friendlyErrorMessage(err), onRetry: () => ref.invalidate(macroHistoryProvider(country))),
            data: (indicators) {
              final sorted = indicators.where((i) => i.indicatorName == widget.indicatorName).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
              if (sorted.isEmpty) return const EmptyView(message: 'No historical data');
              final filtered = _filter(sorted);
              if (filtered.isEmpty) return Padding(padding: const EdgeInsets.only(top: 24), child: Center(child: Text('No data in this range', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))));
              final vals = filtered.map((i) => i.value).toList();
              final o = vals.first; final c = vals.last; final h = vals.reduce((a, b) => a > b ? a : b); final l = vals.reduce((a, b) => a < b ? a : b);
              final avg = vals.fold<double>(0, (s, p) => s + p) / vals.length;
              final sp = o != 0 ? ((h - l) / o) * 100 : null;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _StatsCard(open: o, high: h, low: l, close: c, avg: avg, spreadPct: sp),
                const SizedBox(height: 12),
                PriceLineChart(prices: vals, timestamps: filtered.map((i) => i.timestamp).toList(), unit: 'percent', isShortRange: _chartRange == ChartRange.oneMonth || _chartRange == ChartRange.threeMonths, pricePrefix: null, chartUnitHint: '%'),
              ]);
            },
          ),
        ]),
      ),
    );
  }

  Widget _topCard(ThemeData theme, List<MacroIndicator>? history) {
    final ind = widget.initialIndicator!;
    double? pct;
    if (history != null && history.isNotEmpty) {
      final s = history.where((i) => i.indicatorName == widget.indicatorName).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final f = _filter(s); if (f.length >= 2) { final a = f.first.value; final b = f.last.value; if (a != 0) pct = ((b - a) / a) * 100; }
    }
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(Formatters.macroValue(ind.value, ind.indicatorName), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
      if (pct != null) ...[const SizedBox(height: 6), Text('${_chartRange.label} change  ${Formatters.changeTag(pct)}', style: theme.textTheme.titleSmall?.copyWith(color: pct >= 0 ? AppTheme.accentGreen : AppTheme.accentRed, fontWeight: FontWeight.w600))],
      const SizedBox(height: 4),
      Text('${_countryLabel(ind.country)} · Last updated ${Formatters.relativeTime(ind.timestamp)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
    ])));
  }

  List<MacroIndicator> _filter(List<MacroIndicator> s) {
    if (_chartRange == ChartRange.all) return s;
    final cut = DateTime.now().subtract(_chartRange.duration);
    return s.where((i) => !i.timestamp.isBefore(cut)).toList();
  }

  Widget _rangeChips(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(height: 44, child: Stack(alignment: Alignment.centerRight, children: [
      SingleChildScrollView(controller: _rsc, scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: [
        ...ChartRange.values.map((r) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
          label: Text(r.label), selected: r == _chartRange, onSelected: (_) => setState(() => _chartRange = r),
          selectedColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4), checkmarkColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))),
        const SizedBox(width: 24),
      ])),
      if (_showHint) IgnorePointer(child: Container(width: 32, height: 40,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [theme.scaffoldBackgroundColor.withValues(alpha: 0), theme.scaffoldBackgroundColor])),
        child: Center(child: Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))))),
    ]));
  }
}

class _StatsCard extends StatelessWidget {
  final double open, high, low, close, avg; final double? spreadPct;
  const _StatsCard({required this.open, required this.high, required this.low, required this.close, required this.avg, this.spreadPct});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget s(String l, String v) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(l, style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: 0.6))), const SizedBox(height: 4),
      Text(v, style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
    ]);
    return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: s('Open', Formatters.price(open, unit: 'percent'))), const SizedBox(width: 12), Expanded(child: s('High', Formatters.price(high, unit: 'percent')))]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: s('Low', Formatters.price(low, unit: 'percent'))), const SizedBox(width: 12), Expanded(child: s('Close', Formatters.price(close, unit: 'percent')))]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: s('Avg', Formatters.price(avg, unit: 'percent'))), if (spreadPct != null) ...[const SizedBox(width: 12), Expanded(child: s('High–Low', Formatters.price(spreadPct!, unit: 'percent')))]]),
    ])));
  }
}
