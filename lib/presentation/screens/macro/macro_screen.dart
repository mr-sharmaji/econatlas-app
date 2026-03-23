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

// =============================================================================
// Helpers
// =============================================================================

String _countryLabel(String code) {
  switch (code) {
    case 'IN': return 'India';
    case 'US': return 'United States';
    default: return code;
  }
}

Color _valColor(String name, double v) {
  switch (name) {
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

(String, Color) _context(String n, double v, String c) {
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
      return v < 0 ? ('Trade deficit', AppTheme.accentOrange) : ('Trade surplus', AppTheme.accentGreen);
    case 'fiscal_deficit':
      return v > 5 ? ('Wide deficit', AppTheme.accentRed) : v > 3 ? ('Moderate', AppTheme.accentOrange) : ('Disciplined', AppTheme.accentGreen);
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

/// Rich value-aware explainer for bottom sheet
(String, Color) _richExplainer(String name, double value, String country) {
  final cn = _countryLabel(country);
  switch (name) {
    case 'gdp_growth':
      if (value > 6) return ('$cn GDP grew at ${value.toStringAsFixed(1)}%, indicating robust expansion. Strong domestic demand and investment activity are driving growth well above the global average.', AppTheme.accentGreen);
      if (value > 0) return ('$cn GDP growth of ${value.toStringAsFixed(1)}% shows positive but moderate expansion. The economy is growing steadily without overheating.', AppTheme.accentGreen);
      return ('$cn GDP contracted by ${value.abs().toStringAsFixed(1)}%, signaling recession. The economy is shrinking — businesses produce less, consumers spend less.', AppTheme.accentRed);
    case 'inflation':
      final t = country == 'IN' ? 4.0 : 2.0;
      if (value > t + 2) return ('Inflation at ${value.toStringAsFixed(1)}% is well above the ${t.toInt()}% target. High inflation erodes purchasing power and may trigger rate hikes.', AppTheme.accentRed);
      if (value > t) return ('Inflation at ${value.toStringAsFixed(1)}% is near the ${t.toInt()}% target. The central bank is monitoring but may hold rates steady.', AppTheme.accentOrange);
      return ('Inflation at ${value.toStringAsFixed(1)}% is below the ${t.toInt()}% target. This gives the central bank room to support growth through rate cuts.', AppTheme.accentGreen);
    case 'core_inflation':
      return ('Core inflation (ex food & fuel) at ${value.toStringAsFixed(1)}%. This shows underlying price pressure without volatile components. ${value > 4 ? "Elevated core inflation is sticky and hard to control." : "Well-contained, giving policy flexibility."}', value > 4 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'unemployment':
      return ('${value.toStringAsFixed(1)}% of the labor force is actively seeking work. ${value > 5 ? "High unemployment suggests weak labor demand and potential social stress." : "A relatively tight labor market — most job seekers can find employment."}', value > 5 ? AppTheme.accentRed : AppTheme.accentGreen);
    case 'repo_rate':
      final bank = country == 'IN' ? 'RBI' : country == 'US' ? 'Federal Reserve' : 'central bank';
      return ('Policy rate set at ${value.toStringAsFixed(2)}% by the $bank. This rate influences all borrowing costs — home loans, car loans, business credit. Higher rates slow inflation but tighten credit; lower rates stimulate growth.', Colors.white70);
    case 'pmi_manufacturing':
      return ('Manufacturing PMI at ${value.toStringAsFixed(1)}. ${value >= 50 ? "Above 50 signals expansion — factories are ramping up production and new orders are flowing." : "Below 50 signals contraction — factory output is declining."}', value >= 50 ? AppTheme.accentGreen : AppTheme.accentRed);
    case 'pmi_services':
      return ('Services PMI at ${value.toStringAsFixed(1)}. Services make up 50-70% of most economies. ${value >= 50 ? "Expansion in services means consumer spending and business activity are healthy." : "Contraction in services is a significant concern."}', value >= 50 ? AppTheme.accentGreen : AppTheme.accentRed);
    case 'iip':
      return ('Industrial production ${value >= 0 ? "grew" : "fell"} ${value.abs().toStringAsFixed(1)}% year-over-year. Tracks factory, mining, and utility output. ${value > 5 ? "Strong industrial momentum." : value > 0 ? "Positive but modest." : "Declining output — possible demand weakness."}', value > 0 ? AppTheme.accentGreen : AppTheme.accentRed);
    case 'forex_reserves':
      return ('Forex reserves at \$${(value / 1000).toStringAsFixed(0)}B. These reserves buffer against external shocks — currency crises, capital outflows, or import payment needs. Higher reserves = stronger defense.', Colors.white70);
    case 'trade_balance':
      return ('Trade ${value < 0 ? "deficit" : "surplus"} of \$${value.abs().toStringAsFixed(1)}B. ${value < 0 ? "Imports exceed exports, putting pressure on the currency and requiring capital inflows to finance." : "Exports exceed imports, strengthening the currency."}', value < 0 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'current_account_deficit':
      return ('Current account ${value < 0 ? "deficit" : "surplus"} of \$${value.abs().toStringAsFixed(1)}B. The broadest measure of external transactions — goods, services, income, and transfers. ${value < 0 ? "Net borrower from the world." : "Net lender to the world."}', value < 0 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'fiscal_deficit':
      return ('Fiscal deficit at ${value.toStringAsFixed(1)}% of GDP. Government spending exceeds revenue by this margin. ${value > 5 ? "Wide deficit may crowd out private investment." : "Manageable — gives room for spending during downturns."}', value > 5 ? AppTheme.accentRed : AppTheme.accentOrange);
    case 'bank_credit_growth':
      return ('Bank lending growing at ${value.toStringAsFixed(1)}%. Reflects credit demand from businesses and consumers. ${value > 15 ? "Rapid credit growth — watch for overheating." : "Healthy credit expansion supporting economic activity."}', Colors.white70);
    case 'gst_collection':
      return ('GST collections of ₹${value.toStringAsFixed(2)} lakh crore. Proxy for formal economy health — higher collections indicate more business activity and tax compliance.', Colors.white70);
    default:
      return ('${displayName(name)}: ${value.toStringAsFixed(2)}', Colors.white54);
  }
}

Color _instColor(String inst) {
  switch (inst) {
    case 'RBI': return AppTheme.accentOrange;
    case 'Fed': return AppTheme.accentBlue;
    default: return Colors.white54;
  }
}

/// Cards config: (title, icon, IN metrics, US metrics)
const _cards = [
  ('Growth', Icons.trending_up, ['gdp_growth', 'pmi_manufacturing', 'pmi_services', 'iip'], ['gdp_growth', 'pmi_manufacturing', 'pmi_services', 'iip']),
  ('Prices & Rates', Icons.price_change, ['inflation', 'core_inflation', 'repo_rate'], ['inflation', 'core_inflation', 'repo_rate']),
  ('Employment', Icons.people_outline, ['unemployment'], ['unemployment']),
  ('External & Fiscal', Icons.public, ['trade_balance', 'forex_reserves', 'current_account_deficit', 'fiscal_deficit', 'bank_credit_growth', 'gst_collection'], ['trade_balance']),
];

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
  int? _expanded;

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
    final (label, _) = _context(ind.indicatorName, ind.value, ind.country);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(4), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final macroAsync = ref.watch(allMacroIndicatorsProvider);
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
          ref.invalidate(macroForecastsProvider);
          ref.invalidate(econCalendarProvider);
        },
        child: macroAsync.when(
          loading: () => ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [ShimmerList(itemCount: 6)]),
          error: (err, _) => ListView(physics: const AlwaysScrollableScrollPhysics(), children: [ErrorView(message: friendlyErrorMessage(err), onRetry: () => ref.invalidate(allMacroIndicatorsProvider))]),
          data: (indicators) {
            final all = indicators.where((i) => i.indicatorName != 'fii_net_cash' && i.indicatorName != 'dii_net_cash').toList();
            if (all.isEmpty) return const EmptyView(message: 'No data', icon: Icons.analytics_outlined);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _sc,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
              children: [
                // ── Event banner (max 2) ──
                calendarAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: events.take(2).map((e) {
                          final days = e.eventDate.difference(DateTime.now()).inDays;
                          final ic = _instColor(e.institution);
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: e == events.first && events.length > 1 ? 6 : 0),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: ic.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ic.withValues(alpha: 0.15)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: ic.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                                      child: Text(e.institution, style: TextStyle(color: ic, fontWeight: FontWeight.w700, fontSize: 9)),
                                    ),
                                    const Spacer(),
                                    Text(days == 0 ? 'Today' : days == 1 ? 'Tmrw' : '${days}d', style: TextStyle(color: ic, fontWeight: FontWeight.w600, fontSize: 10)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(DateFormat('dd MMM').format(e.eventDate), style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54, fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),

                // ── India section header ──
                _SectionLabel(code: 'IN', label: 'India'),
                const SizedBox(height: 6),

                // ── India cards ──
                ..._cards.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final (title, icon, inMetrics, _) = entry.value;
                  final hasData = inMetrics.any((m) => _latest(all, m, 'IN') != null);
                  if (!hasData) return const SizedBox.shrink();
                  return _ThemeCard(
                    title: title,
                    icon: icon,
                    metrics: inMetrics,
                    country: 'IN',
                    indicators: all,
                    isExpanded: _expanded == idx,
                    onToggle: () => setState(() => _expanded = _expanded == idx ? null : idx),
                    onInfoTap: _showExplainer,
                  );
                }),

                const SizedBox(height: 14),

                // ── US section header ──
                _SectionLabel(code: 'US', label: 'United States'),
                const SizedBox(height: 6),

                // ── US cards ──
                ..._cards.asMap().entries.map((entry) {
                  final idx = entry.key + 100; // offset to avoid conflict with IN cards
                  final (title, icon, _, usMetrics) = entry.value;
                  final hasData = usMetrics.any((m) => _latest(all, m, 'US') != null);
                  if (!hasData) return const SizedBox.shrink();
                  return _ThemeCard(
                    title: title,
                    icon: icon,
                    metrics: usMetrics,
                    country: 'US',
                    indicators: all,
                    isExpanded: _expanded == idx,
                    onToggle: () => setState(() => _expanded = _expanded == idx ? null : idx),
                    onInfoTap: _showExplainer,
                  );
                }),

                const SizedBox(height: 14),

                // ── IMF Forecasts ──
                forecastAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (fcs) {
                    if (fcs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IMF Forecasts', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        _ForecastCard(forecasts: fcs),
                        const SizedBox(height: 14),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Section Label with flag
// =============================================================================

class _SectionLabel extends StatelessWidget {
  final String code;
  final String label;
  const _SectionLabel({required this.code, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SquareBadgeSvg(assetPath: SquareBadgeAssets.flagPathForCountryCode(code), size: 18, borderRadius: 4),
      const SizedBox(width: 8),
      Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

// =============================================================================
// Theme Card (accordion)
// =============================================================================

class _ThemeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> metrics;
  final String country;
  final List<MacroIndicator> indicators;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<MacroIndicator> onInfoTap;

  const _ThemeCard({
    required this.title, required this.icon, required this.metrics,
    required this.country, required this.indicators, required this.isExpanded,
    required this.onToggle, required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Get headline (first metric with data)
    MacroIndicator? headline;
    for (final m in metrics) {
      headline = _latest(indicators, m, country);
      if (headline != null) break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          // ── Header (always visible) ──
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Icon(icon, size: 18, color: AppTheme.accentBlue),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                    if (headline != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(Formatters.macroValue(headline.value, headline.indicatorName),
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: _valColor(headline.indicatorName, headline.value), fontFeatures: const [FontFeature.tabularFigures()])),
                        const SizedBox(width: 6),
                        Builder(builder: (_) {
                          final (l, c) = _context(headline!.indicatorName, headline.value, country);
                          return Text(l, style: theme.textTheme.labelSmall?.copyWith(color: c, fontSize: 10));
                        }),
                      ]),
                    ],
                  ],
                )),
                Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: Colors.white38),
              ]),
            ),
          ),
          // ── Expanded rows ──
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Column(children: metrics.map((name) {
                final ind = _latest(indicators, name, country);
                if (ind == null) return const SizedBox.shrink();
                return _MetricRow(indicator: ind, country: country, onTap: () => onInfoTap(ind));
              }).toList()),
            ),
          ],
        ]),
      ),
    );
  }
}

// =============================================================================
// Metric Row
// =============================================================================

class _MetricRow extends StatelessWidget {
  final MacroIndicator indicator;
  final String country;
  final VoidCallback onTap;

  const _MetricRow({required this.indicator, required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = Formatters.macroValue(indicator.value, indicator.indicatorName);
    final color = _valColor(indicator.indicatorName, indicator.value);
    final (label, labelColor) = _context(indicator.indicatorName, indicator.value, country);
    final dateStr = DateFormat('MMM yy').format(indicator.timestamp);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(displayName(indicator.indicatorName), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                const Icon(Icons.info_outline, size: 12, color: Colors.white24),
              ]),
              if (label.isNotEmpty)
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: labelColor, fontSize: 9)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
            Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38, fontSize: 9)),
          ]),
        ]),
      ),
    );
  }
}

// =============================================================================
// Forecast Card
// =============================================================================

class _ForecastCard extends StatelessWidget {
  final List<MacroForecast> forecasts;
  const _ForecastCard({required this.forecasts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gdp = forecasts.where((f) => f.indicatorName == 'gdp_growth').toList();
    final cpi = forecasts.where((f) => f.indicatorName == 'inflation').toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (gdp.isNotEmpty) ...[
            Text('GDP Growth', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _table(theme, gdp),
            const SizedBox(height: 10),
          ],
          if (cpi.isNotEmpty) ...[
            Text('Inflation', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _table(theme, cpi),
          ],
          const SizedBox(height: 8),
          Text('Source: IMF World Economic Outlook', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _table(ThemeData theme, List<MacroForecast> data) {
    final years = data.map((f) => f.forecastYear).toSet().toList()..sort();
    final inD = {for (final f in data.where((f) => f.country == 'IN')) f.forecastYear: f.value};
    final usD = {for (final f in data.where((f) => f.country == 'US')) f.forecastYear: f.value};

    return Table(
      columnWidths: {0: const FlexColumnWidth(1.2), for (int i = 1; i <= years.length; i++) i: const FlexColumnWidth(1)},
      children: [
        TableRow(children: [
          const SizedBox.shrink(),
          ...years.map((y) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${y}F', textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white54)),
          )),
        ]),
        _row(theme, 'IN', 'India', years, inD),
        _row(theme, 'US', 'US', years, usD),
      ],
    );
  }

  TableRow _row(ThemeData theme, String code, String label, List<int> years, Map<int, double> data) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SquareBadgeSvg(assetPath: SquareBadgeAssets.flagPathForCountryCode(code), size: 12, borderRadius: 2),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
      ...years.map((y) {
        final v = data[y];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(v != null ? '${v.toStringAsFixed(1)}%' : '—', textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()], color: v != null && v >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)),
        );
      }),
    ]);
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
  final ScrollController _rangeScrollController = ScrollController();
  bool _showRangeScrollHint = true;

  @override
  void initState() {
    super.initState();
    _rangeScrollController.addListener(_onRangeScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRangeScroll());
  }

  @override
  void dispose() {
    _rangeScrollController.removeListener(_onRangeScroll);
    _rangeScrollController.dispose();
    super.dispose();
  }

  void _onRangeScroll() {
    if (!_rangeScrollController.hasClients) return;
    final atEnd = _rangeScrollController.offset >= _rangeScrollController.position.maxScrollExtent - 4;
    if (_showRangeScrollHint == atEnd) setState(() => _showRangeScrollHint = !atEnd);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String country = widget.initialIndicator?.country ?? widget.countryOverride ?? ref.watch(selectedCountryProvider);
    final historyAsync = ref.watch(macroHistoryProvider(country));

    return Scaffold(
      appBar: AppBar(title: Text(displayName(widget.indicatorName))),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(macroHistoryProvider(country)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.initialIndicator != null) ...[
              _buildTopCard(theme, historyAsync.valueOrNull),
              const SizedBox(height: 16),
            ],
            Text('Historical Data', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _chartRangeChips(context),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const ShimmerCard(height: 200),
              error: (err, _) => ErrorView(message: friendlyErrorMessage(err), onRetry: () => ref.invalidate(macroHistoryProvider(country))),
              data: (indicators) {
                final byIndicator = indicators.where((i) => i.indicatorName == widget.indicatorName).toList()
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                if (byIndicator.isEmpty) return const EmptyView(message: 'No historical data');
                final filtered = _filterByRange(byIndicator);
                if (filtered.isEmpty) {
                  return Padding(padding: const EdgeInsets.only(top: 24),
                    child: Center(child: Text('No data in this range', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))));
                }
                final values = filtered.map((i) => i.value).toList();
                final open = values.first; final close = values.last;
                final high = values.reduce((a, b) => a > b ? a : b);
                final low = values.reduce((a, b) => a < b ? a : b);
                final avg = values.fold<double>(0, (s, p) => s + p) / values.length;
                final spreadPct = open != 0 ? ((high - low) / open) * 100 : null;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _MacroRangeStatsCard(open: open, high: high, low: low, close: close, avg: avg, spreadPct: spreadPct),
                  const SizedBox(height: 12),
                  PriceLineChart(prices: values, timestamps: filtered.map((i) => i.timestamp).toList(), unit: 'percent', isShortRange: _chartRange == ChartRange.oneMonth || _chartRange == ChartRange.threeMonths, pricePrefix: null, chartUnitHint: '%'),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(ThemeData theme, List<MacroIndicator>? history) {
    final ind = widget.initialIndicator!;
    double? rangePct;
    if (history != null && history.isNotEmpty) {
      final byIndicator = history.where((i) => i.indicatorName == widget.indicatorName).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final filtered = _filterByRange(byIndicator);
      if (filtered.length >= 2) { final f = filtered.first.value; final l = filtered.last.value; if (f != 0) rangePct = ((l - f) / f) * 100; }
    }
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(Formatters.macroValue(ind.value, ind.indicatorName), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
      if (rangePct != null) ...[const SizedBox(height: 6), Text('${_chartRange.label} change  ${Formatters.changeTag(rangePct)}', style: theme.textTheme.titleSmall?.copyWith(color: rangePct >= 0 ? AppTheme.accentGreen : AppTheme.accentRed, fontWeight: FontWeight.w600))],
      const SizedBox(height: 4),
      Text('${_countryLabel(ind.country)} · Last updated ${Formatters.relativeTime(ind.timestamp)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
    ])));
  }

  List<MacroIndicator> _filterByRange(List<MacroIndicator> sorted) {
    if (_chartRange == ChartRange.all) return sorted;
    final cutoff = DateTime.now().subtract(_chartRange.duration);
    return sorted.where((i) => !i.timestamp.isBefore(cutoff)).toList();
  }

  Widget _chartRangeChips(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(height: 44, child: Stack(alignment: Alignment.centerRight, children: [
      SingleChildScrollView(controller: _rangeScrollController, scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: [
        ...ChartRange.values.map((r) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
          label: Text(r.label), selected: r == _chartRange, onSelected: (_) => setState(() => _chartRange = r),
          selectedColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4), checkmarkColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))),
        const SizedBox(width: 24),
      ])),
      if (_showRangeScrollHint) IgnorePointer(child: Container(width: 32, height: 40,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [theme.scaffoldBackgroundColor.withValues(alpha: 0), theme.scaffoldBackgroundColor])),
        child: Center(child: Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))))),
    ]));
  }
}

class _MacroRangeStatsCard extends StatelessWidget {
  final double open, high, low, close, avg;
  final double? spreadPct;
  const _MacroRangeStatsCard({required this.open, required this.high, required this.low, required this.close, required this.avg, this.spreadPct});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stat(String label, String value) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      const SizedBox(height: 4),
      Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
    ]);
    return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: stat('Open', Formatters.price(open, unit: 'percent'))), const SizedBox(width: 12), Expanded(child: stat('High', Formatters.price(high, unit: 'percent')))]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: stat('Low', Formatters.price(low, unit: 'percent'))), const SizedBox(width: 12), Expanded(child: stat('Close', Formatters.price(close, unit: 'percent')))]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: stat('Avg', Formatters.price(avg, unit: 'percent'))), if (spreadPct != null) ...[const SizedBox(width: 12), Expanded(child: stat('High–Low', Formatters.price(spreadPct!, unit: 'percent')))]]),
    ])));
  }
}
