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

const _explainers = {
  'gdp_growth': 'Gross Domestic Product growth rate. Measures how fast the economy is expanding.',
  'inflation': 'Consumer Price Index year-over-year change. Measures how fast prices are rising.',
  'core_inflation': 'CPI excluding food and fuel. Shows underlying inflation trend.',
  'unemployment': 'Percentage of labor force actively looking for work but unable to find it.',
  'repo_rate': 'Policy rate set by the central bank. Core lever for controlling inflation.',
  'pmi_manufacturing': 'Purchasing Managers Index for manufacturing. Above 50 = expansion.',
  'pmi_services': 'Purchasing Managers Index for services. Above 50 = expansion.',
  'iip': 'Index of Industrial Production. Tracks factory output growth.',
  'forex_reserves': 'Foreign exchange reserves as an external shock buffer.',
  'trade_balance': 'Exports minus imports. Negative = trade deficit.',
  'current_account_deficit': 'Broad external balance including goods, services, transfers.',
  'fiscal_deficit': 'Government spending minus revenue as % of GDP.',
  'bank_credit_growth': 'Rate at which banks are lending to the private sector.',
  'gst_collection': 'Monthly GST collections. Proxy for formal economy activity.',
};

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

  void _showExplainer(String name) {
    final text = _explainers[name];
    if (text == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(displayName(name)),
        content: Text(text),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
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
                    onInfoTap: _showExplainer,
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
