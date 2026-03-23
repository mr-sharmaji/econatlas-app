import 'dart:math' as math;

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
import '../../../data/models/macro_indicator.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

// =============================================================================
// Config & Helpers
// =============================================================================

const _countries = ['IN', 'US', 'EU', 'JP'];

String _countryLabel(String code) {
  switch (code) {
    case 'IN': return 'India';
    case 'US': return 'United States';
    case 'EU': return 'Euro Area';
    case 'JP': return 'Japan';
    default: return code;
  }
}

String _countryShort(String code) {
  switch (code) {
    case 'IN': return 'India';
    case 'US': return 'US';
    case 'EU': return 'EU';
    case 'JP': return 'Japan';
    default: return code;
  }
}

Color _valueColor(String name, double value) {
  switch (name) {
    case 'inflation': case 'core_inflation':
      return value > 6 ? AppTheme.accentRed : (value > 4 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'unemployment':
      return value > 6 ? AppTheme.accentRed : (value > 4 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'gdp_growth': case 'iip': case 'bank_credit_growth':
      return value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    case 'pmi_manufacturing': case 'pmi_services':
      return value >= 50 ? AppTheme.accentGreen : AppTheme.accentRed;
    default: return Colors.white70;
  }
}

/// Contextual label for a metric value (color-coded)
(String label, Color color) _contextLabel(String name, double value, String country) {
  switch (name) {
    case 'gdp_growth':
      if (value > 6) return ('Strong growth', AppTheme.accentGreen);
      if (value > 3) return ('Moderate growth', AppTheme.accentGreen);
      if (value > 0) return ('Slow growth', AppTheme.accentOrange);
      return ('Contraction', AppTheme.accentRed);
    case 'inflation':
      final target = country == 'IN' ? 4.0 : 2.0;
      if (value > target + 2) return ('Above target', AppTheme.accentRed);
      if (value > target) return ('Near target', AppTheme.accentOrange);
      if (value < 0) return ('Deflation', AppTheme.accentRed);
      return ('Below target', AppTheme.accentGreen);
    case 'core_inflation':
      if (value > 5) return ('Sticky', AppTheme.accentRed);
      if (value > 3) return ('Elevated', AppTheme.accentOrange);
      return ('Moderate', AppTheme.accentGreen);
    case 'unemployment':
      if (value > 6) return ('High', AppTheme.accentRed);
      if (value > 4) return ('Moderate', AppTheme.accentOrange);
      return ('Low', AppTheme.accentGreen);
    case 'pmi_manufacturing': case 'pmi_services':
      if (value >= 55) return ('Strong expansion', AppTheme.accentGreen);
      if (value >= 50) return ('Expansion', AppTheme.accentGreen);
      if (value >= 48) return ('Near neutral', AppTheme.accentOrange);
      return ('Contraction', AppTheme.accentRed);
    case 'iip':
      if (value > 5) return ('Strong output', AppTheme.accentGreen);
      if (value > 0) return ('Positive', AppTheme.accentGreen);
      return ('Declining', AppTheme.accentRed);
    case 'repo_rate':
      return ('Policy rate', Colors.white54);
    case 'forex_reserves':
      return ('External buffer', Colors.white54);
    case 'trade_balance':
      return value < 0 ? ('Trade deficit', AppTheme.accentOrange) : ('Trade surplus', AppTheme.accentGreen);
    case 'fiscal_deficit':
      if (value > 5) return ('Wide deficit', AppTheme.accentRed);
      if (value > 3) return ('Moderate', AppTheme.accentOrange);
      return ('Disciplined', AppTheme.accentGreen);
    default:
      return ('', Colors.white38);
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

Color _institutionColor(String inst) {
  switch (inst) {
    case 'RBI': return AppTheme.accentOrange;
    case 'Fed': return AppTheme.accentBlue;
    case 'ECB': return AppTheme.accentTeal;
    case 'BoJ': return const Color(0xFF8A9EFF);
    default: return Colors.white54;
  }
}

/// Generate rich context explanation based on actual value + country
(String explanation, Color sentimentColor) _richExplainer(String name, double value, String country) {
  final countryName = _countryLabel(country);
  switch (name) {
    case 'gdp_growth':
      if (value > 6) return ('$countryName GDP grew at ${value.toStringAsFixed(1)}%, indicating a robustly expanding economy. This is well above the global average and suggests strong domestic demand, investment activity, and industrial output.', AppTheme.accentGreen);
      if (value > 3) return ('$countryName GDP growth of ${value.toStringAsFixed(1)}% shows a moderately growing economy. Growth is positive but not overheating — a healthy balance for sustainable expansion.', AppTheme.accentGreen);
      if (value > 0) return ('$countryName GDP growth of ${value.toStringAsFixed(1)}% indicates sluggish economic expansion. Growth is positive but weak, which may prompt central banks to consider rate cuts to stimulate activity.', AppTheme.accentOrange);
      return ('$countryName GDP contracted by ${value.abs().toStringAsFixed(1)}%, signaling an economic recession. Negative growth means the economy is shrinking — businesses are producing less, consumers are spending less.', AppTheme.accentRed);
    case 'inflation':
      final target = country == 'IN' ? 4.0 : 2.0;
      if (value > target + 2) return ('Inflation at ${value.toStringAsFixed(1)}% is significantly above the central bank\'s ${target.toStringAsFixed(0)}% target. High inflation erodes purchasing power and may trigger rate hikes. Essential goods become more expensive for consumers.', AppTheme.accentRed);
      if (value > target) return ('Inflation at ${value.toStringAsFixed(1)}% is slightly above the ${target.toStringAsFixed(0)}% target but within tolerance. The central bank is likely monitoring closely but may not act immediately.', AppTheme.accentOrange);
      if (value < 0) return ('Prices are falling (deflation) at ${value.abs().toStringAsFixed(1)}%. While this sounds good, deflation can be dangerous — it discourages spending and investment as people wait for lower prices.', AppTheme.accentRed);
      return ('Inflation at ${value.toStringAsFixed(1)}% is comfortably below the ${target.toStringAsFixed(0)}% target. This gives the central bank room to cut rates and support growth without worrying about price stability.', AppTheme.accentGreen);
    case 'core_inflation':
      if (value > 5) return ('Core inflation (excluding food and fuel) at ${value.toStringAsFixed(1)}% is sticky and elevated. This suggests broad-based price pressures beyond volatile components — harder for the central bank to control.', AppTheme.accentRed);
      if (value > 3) return ('Core inflation at ${value.toStringAsFixed(1)}% is moderately elevated. While not alarming, persistent core inflation above 3% can become entrenched and is closely watched by policymakers.', AppTheme.accentOrange);
      return ('Core inflation at ${value.toStringAsFixed(1)}% is well-contained. This indicates that underlying price pressures are manageable and the central bank has policy flexibility.', AppTheme.accentGreen);
    case 'unemployment':
      if (value > 6) return ('Unemployment at ${value.toStringAsFixed(1)}% is high. A large portion of the workforce is seeking jobs unsuccessfully. This typically leads to lower consumer spending, social stress, and pressure on the government for stimulus.', AppTheme.accentRed);
      if (value > 4) return ('Unemployment at ${value.toStringAsFixed(1)}% is moderate. The labor market has some slack but isn\'t in distress. Job seekers face competition but opportunities exist.', AppTheme.accentOrange);
      return ('Unemployment at ${value.toStringAsFixed(1)}% indicates a tight labor market. Most people who want jobs can find them. This is positive for wage growth but can contribute to inflation.', AppTheme.accentGreen);
    case 'repo_rate':
      final label = country == 'US' ? 'Fed Funds Rate' : 'Repo Rate';
      return ('The $label is set at ${value.toStringAsFixed(2)}% by the ${country == "IN" ? "RBI" : country == "US" ? "Federal Reserve" : "central bank"}. This is the rate at which the central bank lends to commercial banks. Higher rates make borrowing expensive (slows inflation), lower rates make it cheap (stimulates growth). Changes in this rate affect home loans, car loans, and business credit across the economy.', Colors.white70);
    case 'pmi_manufacturing':
      if (value >= 55) return ('Manufacturing PMI at ${value.toStringAsFixed(1)} signals strong expansion. New orders are flowing in, factories are ramping up production, and employment is likely growing. This is a leading indicator of GDP growth.', AppTheme.accentGreen);
      if (value >= 50) return ('Manufacturing PMI at ${value.toStringAsFixed(1)} indicates expansion, though modest. Factory activity is growing but at a measured pace. Above 50 means more businesses reported improvement than deterioration.', AppTheme.accentGreen);
      return ('Manufacturing PMI at ${value.toStringAsFixed(1)} signals contraction. Factory output is declining, new orders are falling, and businesses are cutting back. Below 50 is a warning sign for the broader economy.', AppTheme.accentRed);
    case 'pmi_services':
      if (value >= 55) return ('Services PMI at ${value.toStringAsFixed(1)} shows robust expansion in the services sector — which makes up 50-70% of most economies. Strong services activity means consumer spending, IT, banking, and hospitality are all growing.', AppTheme.accentGreen);
      if (value >= 50) return ('Services PMI at ${value.toStringAsFixed(1)} indicates the services sector is expanding. Business activity is positive, supporting employment and consumer confidence.', AppTheme.accentGreen);
      return ('Services PMI at ${value.toStringAsFixed(1)} signals contraction in the services sector. This is concerning as services represent the largest part of the economy.', AppTheme.accentRed);
    case 'iip':
      if (value > 5) return ('Industrial production grew ${value.toStringAsFixed(1)}% year-over-year, showing strong manufacturing and mining output. This suggests factories are running at high capacity and demand for goods is robust.', AppTheme.accentGreen);
      if (value > 0) return ('Industrial production grew ${value.toStringAsFixed(1)}% — positive but modest. Factory output is increasing at a measured pace, consistent with a steady but not booming manufacturing sector.', AppTheme.accentGreen);
      return ('Industrial production declined ${value.abs().toStringAsFixed(1)}%. Factories are producing less than a year ago, which could reflect weak demand, supply chain issues, or economic slowdown.', AppTheme.accentRed);
    case 'forex_reserves':
      return ('Foreign exchange reserves stand at \$${(value / 1000).toStringAsFixed(0)} billion. These reserves act as a buffer against external shocks — currency crises, sudden capital outflows, or import payment needs. Higher reserves give the central bank more ammunition to defend the currency.', Colors.white70);
    case 'trade_balance':
      if (value < 0) return ('Trade deficit of \$${value.abs().toStringAsFixed(1)} billion means $countryName imports more than it exports. A persistent deficit puts pressure on the currency and requires financing through capital inflows or reserve drawdowns.', AppTheme.accentOrange);
      return ('Trade surplus of \$${value.toStringAsFixed(1)} billion means $countryName exports more than it imports. This strengthens the currency and adds to foreign exchange reserves.', AppTheme.accentGreen);
    case 'current_account_deficit':
      if (value < 0) return ('Current account deficit of \$${value.abs().toStringAsFixed(1)} billion reflects the broadest measure of $countryName\'s external transactions — goods, services, income, and transfers. A deficit means the country is a net borrower from the world.', AppTheme.accentOrange);
      return ('Current account surplus of \$${value.toStringAsFixed(1)} billion means $countryName earns more from the world than it pays out. This is a sign of external strength.', AppTheme.accentGreen);
    case 'fiscal_deficit':
      if (value > 5) return ('Fiscal deficit at ${value.toStringAsFixed(1)}% of GDP is wide. The government is spending significantly more than it earns, funded by borrowing. High fiscal deficits can crowd out private investment and increase interest rates.', AppTheme.accentRed);
      if (value > 3) return ('Fiscal deficit at ${value.toStringAsFixed(1)}% of GDP is moderate. Government finances are stretched but manageable. The deficit is being financed through market borrowings.', AppTheme.accentOrange);
      return ('Fiscal deficit at ${value.toStringAsFixed(1)}% of GDP shows disciplined government spending. This gives the government room to increase spending during downturns without destabilizing finances.', AppTheme.accentGreen);
    case 'bank_credit_growth':
      return ('Bank credit is growing at ${value.toStringAsFixed(1)}%. This reflects how quickly banks are lending to businesses and individuals. Higher credit growth supports economic expansion but excessive growth can create asset bubbles.', Colors.white70);
    case 'gst_collection':
      return ('GST collections of \u20B9${value.toStringAsFixed(2)} lakh crore reflect the health of the formal economy. Higher collections indicate increased business activity and better tax compliance.', Colors.white70);
    default:
      return ('${displayName(name)}: ${value.toStringAsFixed(2)}', Colors.white54);
  }
}

/// Insight card definitions: (key, title, icon, metrics_per_country)
const _insightCards = [
  (
    key: 'growth',
    title: 'Growth & Activity',
    icon: Icons.trending_up,
    headline: 'gdp_growth',
    metrics: {
      'IN': ['gdp_growth', 'pmi_manufacturing', 'pmi_services', 'iip'],
      'US': ['gdp_growth', 'pmi_manufacturing', 'pmi_services', 'iip'],
      'EU': ['gdp_growth'],
      'JP': ['gdp_growth'],
    },
  ),
  (
    key: 'prices',
    title: 'Prices & Rates',
    icon: Icons.price_change,
    headline: 'inflation',
    metrics: {
      'IN': ['inflation', 'core_inflation', 'repo_rate'],
      'US': ['inflation', 'core_inflation', 'repo_rate'],
      'EU': ['inflation', 'repo_rate'],
      'JP': ['inflation', 'repo_rate'],
    },
  ),
  (
    key: 'jobs',
    title: 'Employment',
    icon: Icons.people_outline,
    headline: 'unemployment',
    metrics: {
      'IN': ['unemployment'],
      'US': ['unemployment'],
      'EU': ['unemployment'],
      'JP': ['unemployment'],
    },
  ),
  (
    key: 'external',
    title: 'External & Fiscal',
    icon: Icons.public,
    headline: 'trade_balance',
    metrics: {
      'IN': ['trade_balance', 'forex_reserves', 'current_account_deficit', 'fiscal_deficit', 'bank_credit_growth', 'gst_collection'],
      'US': ['trade_balance'],
      'EU': <String>[],
      'JP': <String>[],
    },
  ),
];

// =============================================================================
// MacroScreen
// =============================================================================

class MacroScreen extends ConsumerStatefulWidget {
  const MacroScreen({super.key});

  @override
  ConsumerState<MacroScreen> createState() => _MacroScreenState();
}

class _MacroScreenState extends ConsumerState<MacroScreen> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final TabController _tabController;
  int? _expandedCard; // accordion: only one open

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController = TabController(length: _countries.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _expandedCard = null);
        ref.read(selectedCountryProvider.notifier).state = _countries[_tabController.index];
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _openDetail(MacroIndicator ind) {
    context.push('/macro/detail/${ind.country}/${ind.indicatorName}', extra: ind);
  }

  void _showExplainer(String name, MacroIndicator? indicator) {
    if (indicator == null) return;
    final (explanation, sentimentColor) = _richExplainer(name, indicator.value, indicator.country);
    final value = Formatters.macroValue(indicator.value, indicator.indicatorName);
    final (label, _) = _contextLabel(name, indicator.value, indicator.country);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            // Sentiment strip
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: sentimentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Title + value
            Row(
              children: [
                Expanded(
                  child: Text(displayName(name),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sentimentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(value,
                    style: TextStyle(color: sentimentColor, fontSize: 16, fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ],
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: sentimentColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 12),
            // Explanation
            Text(explanation,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
            const SizedBox(height: 8),
            // Date
            Text('${_countryLabel(indicator.country)} · ${DateFormat("MMM yyyy").format(indicator.timestamp)}',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
    final calendarAsync = ref.watch(econCalendarProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Economy'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _countries.map((c) => Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SquareBadgeSvg(
                  assetPath: SquareBadgeAssets.flagPathForCountryCode(c),
                  size: 16,
                  borderRadius: 3,
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(_countryLabel(c), overflow: TextOverflow.ellipsis, maxLines: 1)),
              ],
            ),
          )).toList(),
          indicatorColor: AppTheme.accentBlue,
          labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: theme.textTheme.labelMedium,
          tabAlignment: TabAlignment.start,
          isScrollable: true,
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allMacroIndicatorsProvider);
          ref.invalidate(econCalendarProvider);
        },
        child: macroAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [ShimmerList(itemCount: 6)],
          ),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [ErrorView(message: friendlyErrorMessage(err), onRetry: () => ref.invalidate(allMacroIndicatorsProvider))],
          ),
          data: (indicators) {
            final country = _countries[_tabController.index];
            final filtered = indicators.where((i) => i.indicatorName != 'fii_net_cash' && i.indicatorName != 'dii_net_cash').toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              children: [
                // ── Hero: 3 key numbers ──
                _HeroRow(indicators: filtered, country: country, onTap: _openDetail),
                const SizedBox(height: 10),

                // ── Event banner ──
                calendarAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (events) {
                    final countryEvents = events.where((e) => e.country == country || (country == 'IN' && e.country == 'US')).take(2).toList();
                    if (countryEvents.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        children: countryEvents.map((e) => _EventBanner(event: e)).toList(),
                      ),
                    );
                  },
                ),

                // ── Expandable insight cards (accordion) ──
                ..._insightCards.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final card = entry.value;
                  final countryMetrics = card.metrics[country] ?? <String>[];
                  // Hide card if no data for this country
                  final hasData = countryMetrics.any((m) => _latest(filtered, m, country) != null);
                  if (!hasData) return const SizedBox.shrink();

                  return _InsightCard(
                    title: card.title,
                    icon: card.icon,
                    headlineMetric: card.headline,
                    metrics: countryMetrics,
                    country: country,
                    indicators: filtered,
                    isExpanded: _expandedCard == idx,
                    onToggle: () => setState(() => _expandedCard = _expandedCard == idx ? null : idx),
                    onMetricTap: _openDetail,
                    onInfoTap: (name) => _showExplainer(name, _latest(filtered, name, country)),
                  );
                }),

                // ── Calendar ──
                calendarAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text('Economic Calendar', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        _CalendarCard(events: events.take(6).toList()),
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
// Hero Row — 3 key numbers
// =============================================================================

class _HeroRow extends StatelessWidget {
  final List<MacroIndicator> indicators;
  final String country;
  final ValueChanged<MacroIndicator> onTap;

  const _HeroRow({required this.indicators, required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = ['gdp_growth', 'inflation', 'repo_rate'];
    final tiles = <Widget>[];

    for (final name in metrics) {
      final ind = _latest(indicators, name, country);
      if (ind == null) continue;
      tiles.add(Expanded(child: _HeroTile(indicator: ind, onTap: () => onTap(ind))));
    }

    if (tiles.isEmpty) {
      return const SizedBox(height: 60, child: Center(child: Text('No headline data', style: TextStyle(color: Colors.white38))));
    }

    return Row(
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          tiles[i],
        ],
      ],
    );
  }
}

class _HeroTile extends StatelessWidget {
  final MacroIndicator indicator;
  final VoidCallback onTap;

  const _HeroTile({required this.indicator, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = Formatters.macroValue(indicator.value, indicator.indicatorName);
    final color = _valueColor(indicator.indicatorName, indicator.value);
    final (label, labelColor) = _contextLabel(indicator.indicatorName, indicator.value, indicator.country);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName(indicator.indicatorName),
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700, color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: labelColor, fontSize: 9)),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Event Banner
// =============================================================================

class _EventBanner extends StatelessWidget {
  final EconCalendarEvent event;
  const _EventBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysAway = event.eventDate.difference(DateTime.now()).inDays;
    final dateStr = DateFormat('dd MMM').format(event.eventDate);
    final instColor = _institutionColor(event.institution);
    final dayLabel = daysAway == 0 ? 'Today' : daysAway == 1 ? 'Tomorrow' : '${daysAway}d';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: instColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: instColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.event, size: 14, color: instColor),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: instColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
            child: Text(event.institution, style: theme.textTheme.labelSmall?.copyWith(color: instColor, fontWeight: FontWeight.w700, fontSize: 9)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text('$dateStr · ${event.eventName}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(dayLabel, style: theme.textTheme.labelSmall?.copyWith(
            color: daysAway <= 7 ? AppTheme.accentGreen : Colors.white38, fontWeight: FontWeight.w600, fontSize: 10)),
        ],
      ),
    );
  }
}

// =============================================================================
// Expandable Insight Card (Accordion)
// =============================================================================

class _InsightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String headlineMetric;
  final List<String> metrics;
  final String country;
  final List<MacroIndicator> indicators;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<MacroIndicator> onMetricTap;
  final ValueChanged<String> onInfoTap;

  const _InsightCard({
    required this.title,
    required this.icon,
    required this.headlineMetric,
    required this.metrics,
    required this.country,
    required this.indicators,
    required this.isExpanded,
    required this.onToggle,
    required this.onMetricTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = _latest(indicators, headlineMetric, country);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            // ── Collapsed header ──
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.accentBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                          if (headline != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  Formatters.macroValue(headline.value, headline.indicatorName),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _valueColor(headline.indicatorName, headline.value),
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Builder(builder: (_) {
                                  final (label, color) = _contextLabel(headline.indicatorName, headline.value, country);
                                  return Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontSize: 10));
                                }),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded content ──
            if (isExpanded) ...[
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  children: metrics.map((name) {
                    final ind = _latest(indicators, name, country);
                    if (ind == null) return const SizedBox.shrink();
                    return _MetricRow(
                      indicator: ind,
                      country: country,
                      onTap: () => onMetricTap(ind),
                      onInfoTap: () => onInfoTap(name),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Metric Row (inside expanded card)
// =============================================================================

class _MetricRow extends StatelessWidget {
  final MacroIndicator indicator;
  final String country;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _MetricRow({required this.indicator, required this.country, required this.onTap, required this.onInfoTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = Formatters.macroValue(indicator.value, indicator.indicatorName);
    final color = _valueColor(indicator.indicatorName, indicator.value);
    final (label, labelColor) = _contextLabel(indicator.indicatorName, indicator.value, country);
    final dateStr = DateFormat('MMM yy').format(indicator.timestamp);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(displayName(indicator.indicatorName),
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onInfoTap,
                        child: const Icon(Icons.info_outline, size: 12, color: Colors.white24),
                      ),
                    ],
                  ),
                  if (label.isNotEmpty)
                    Text(label, style: theme.textTheme.labelSmall?.copyWith(color: labelColor, fontSize: 9)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700, color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
                Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Calendar Card
// =============================================================================

class _CalendarCard extends StatelessWidget {
  final List<EconCalendarEvent> events;
  const _CalendarCard({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          children: [
            for (int i = 0; i < events.length; i++) ...[
              _calendarRow(theme, events[i], now),
              if (i < events.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _calendarRow(ThemeData theme, EconCalendarEvent event, DateTime now) {
    final daysAway = event.eventDate.difference(now).inDays;
    final isThisWeek = daysAway >= 0 && daysAway <= 7;
    final dateStr = DateFormat('dd MMM').format(event.eventDate);
    final instColor = _institutionColor(event.institution);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600, color: isThisWeek ? AppTheme.accentGreen : Colors.white54))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: instColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(event.institution, style: theme.textTheme.labelSmall?.copyWith(color: instColor, fontWeight: FontWeight.w700, fontSize: 10)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(event.eventName, style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isThisWeek ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis)),
          SquareBadgeSvg(assetPath: SquareBadgeAssets.flagPathForCountryCode(event.country), size: 14, borderRadius: 2),
          const SizedBox(width: 4),
          Text(daysAway == 0 ? 'Today' : daysAway == 1 ? 'Tmrw' : '${daysAway}d',
            style: theme.textTheme.labelSmall?.copyWith(color: isThisWeek ? AppTheme.accentGreen : Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

// =============================================================================
// Detail Screen (preserved from previous implementation)
// =============================================================================

class MacroDetailScreen extends ConsumerStatefulWidget {
  final String indicatorName;
  final MacroIndicator? initialIndicator;
  final String? countryOverride;

  const MacroDetailScreen({
    super.key,
    required this.indicatorName,
    this.countryOverride,
    this.initialIndicator,
  });

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
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(child: Text('No data in this range', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))),
                  );
                }
                final values = filtered.map((i) => i.value).toList();
                final open = values.first;
                final close = values.last;
                final high = values.reduce((a, b) => a > b ? a : b);
                final low = values.reduce((a, b) => a < b ? a : b);
                final avg = values.fold<double>(0, (s, p) => s + p) / values.length;
                final spreadPct = open != 0 ? ((high - low) / open) * 100 : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroRangeStatsCard(open: open, high: high, low: low, close: close, avg: avg, spreadPct: spreadPct),
                    const SizedBox(height: 12),
                    PriceLineChart(
                      prices: values,
                      timestamps: filtered.map((i) => i.timestamp).toList(),
                      unit: 'percent',
                      isShortRange: _chartRange == ChartRange.oneMonth || _chartRange == ChartRange.threeMonths,
                      pricePrefix: null,
                      chartUnitHint: '%',
                    ),
                  ],
                );
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
      final byIndicator = history.where((i) => i.indicatorName == widget.indicatorName).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final filtered = _filterByRange(byIndicator);
      if (filtered.length >= 2) {
        final first = filtered.first.value;
        final last = filtered.last.value;
        if (first != 0) rangePct = ((last - first) / first) * 100;
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Formatters.macroValue(ind.value, ind.indicatorName),
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            if (rangePct != null) ...[
              const SizedBox(height: 6),
              Text('${_chartRange.label} change  ${Formatters.changeTag(rangePct)}',
                style: theme.textTheme.titleSmall?.copyWith(color: rangePct >= 0 ? AppTheme.accentGreen : AppTheme.accentRed, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 4),
            Text('${_countryLabel(ind.country)} · Last updated ${Formatters.relativeTime(ind.timestamp)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  List<MacroIndicator> _filterByRange(List<MacroIndicator> sorted) {
    if (_chartRange == ChartRange.all) return sorted;
    final cutoff = DateTime.now().subtract(_chartRange.duration);
    return sorted.where((i) => !i.timestamp.isBefore(cutoff)).toList();
  }

  Widget _chartRangeChips(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          SingleChildScrollView(
            controller: _rangeScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...ChartRange.values.map((r) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(r.label),
                    selected: r == _chartRange,
                    onSelected: (_) => setState(() => _chartRange = r),
                    selectedColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    checkmarkColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )),
                const SizedBox(width: 24),
              ],
            ),
          ),
          if (_showRangeScrollHint)
            IgnorePointer(
              child: Container(
                width: 32, height: 40,
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                  colors: [theme.scaffoldBackgroundColor.withValues(alpha: 0), theme.scaffoldBackgroundColor],
                )),
                child: Center(child: Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroRangeStatsCard extends StatelessWidget {
  final double open, high, low, close, avg;
  final double? spreadPct;
  const _MacroRangeStatsCard({required this.open, required this.high, required this.low, required this.close, required this.avg, this.spreadPct});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stat(String label, String value) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: stat('Open', Formatters.price(open, unit: 'percent'))),
            const SizedBox(width: 12),
            Expanded(child: stat('High', Formatters.price(high, unit: 'percent'))),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: stat('Low', Formatters.price(low, unit: 'percent'))),
            const SizedBox(width: 12),
            Expanded(child: stat('Close', Formatters.price(close, unit: 'percent'))),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: stat('Avg', Formatters.price(avg, unit: 'percent'))),
            if (spreadPct != null) ...[const SizedBox(width: 12), Expanded(child: stat('High–Low', Formatters.price(spreadPct!, unit: 'percent')))],
          ]),
        ]),
      ),
    );
  }
}
