import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/error_utils.dart';
import '../../../core/square_badge_assets.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/econ_calendar_event.dart';
import '../../../data/models/economic_event.dart';
import '../../../data/models/institutional_flow_overview.dart';
import '../../../data/models/macro_indicator.dart';
import '../../../data/models/macro_linkage.dart';
import '../../../data/models/macro_regime.dart';
import '../../../data/models/macro_summary.dart';
import '../../../data/models/market_price.dart';
import '../../../data/models/news_article.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../discover/widgets/sparkline_widget.dart';

const _sceneNow = 'now';
const _sceneNext = 'next';
const _sceneRisk = 'risk';
const _sceneCompare = 'compare';
const _sceneFlows = 'flows';
const _sceneReplay = 'replay';

const _sceneOrder = [
  _sceneNow,
  _sceneNext,
  _sceneRisk,
  _sceneCompare,
  _sceneFlows,
  _sceneReplay,
];

const _countryOrder = ['IN', 'US', 'EU', 'JP'];

String _countryLabel(String code) {
  switch (code) {
    case 'IN':
      return 'India';
    case 'US':
      return 'United States';
    case 'EU':
      return 'Europe';
    case 'JP':
      return 'Japan';
    default:
      return code;
  }
}

MacroIndicator? _latestIndicator(
  List<MacroIndicator> list,
  String country,
  String indicator,
) {
  MacroIndicator? best;
  for (final row in list) {
    if (row.country != country || row.indicatorName != indicator) continue;
    if (best == null || row.timestamp.isAfter(best.timestamp)) {
      best = row;
    }
  }
  return best;
}

List<double> _seriesValues(
  List<MacroIndicator> history,
  String country,
  String indicator, {
  int maxPoints = 24,
}) {
  final series = history
      .where((e) => e.country == country && e.indicatorName == indicator)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (series.length < 2) return const [];
  final from = math.max(0, series.length - maxPoints);
  return series.sublist(from).map((e) => e.value).toList();
}

double _normalize(
  double value,
  double minValue,
  double maxValue,
) {
  if ((maxValue - minValue).abs() < 1e-9) return 0.5;
  return (value - minValue) / (maxValue - minValue);
}

class MacroDashboardScreen extends ConsumerStatefulWidget {
  const MacroDashboardScreen({super.key});

  @override
  ConsumerState<MacroDashboardScreen> createState() =>
      _MacroDashboardScreenState();
}

class _MacroDashboardScreenState extends ConsumerState<MacroDashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sceneKeys = {
    _sceneNow: GlobalKey(),
    _sceneNext: GlobalKey(),
    _sceneRisk: GlobalKey(),
    _sceneCompare: GlobalKey(),
    _sceneFlows: GlobalKey(),
    _sceneReplay: GlobalKey(),
  };

  String _activeScene = _sceneNow;
  String _compareCountry = 'IN';
  String _compareIndicator = 'inflation';
  double _compareBrush = 1.0;
  double _replaySlider = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    const screenTop = 220.0;
    String nearest = _activeScene;
    var bestDist = double.infinity;
    for (final scene in _sceneOrder) {
      final ctx = _sceneKeys[scene]?.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      final dist = (dy - screenTop).abs();
      if (dist < bestDist) {
        bestDist = dist;
        nearest = scene;
      }
    }
    if (nearest != _activeScene) {
      setState(() => _activeScene = nearest);
    }
  }

  Future<void> _jumpToScene(String scene) async {
    final ctx = _sceneKeys[scene]?.currentContext;
    if (ctx == null) return;
    setState(() => _activeScene = scene);
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 340),
      alignment: 0.04,
      curve: Curves.easeOutCubic,
    );
  }

  double get _scrollProgress {
    if (!_scrollController.hasClients) return 0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return 0;
    return (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
  }

  Future<void> _onRefresh() async {
    ref.invalidate(allMacroIndicatorsProvider);
    ref.invalidate(indiaHistoryProvider);
    ref.invalidate(usHistoryProvider);
    ref.invalidate(macroHistoryProvider('EU'));
    ref.invalidate(macroHistoryProvider('JP'));
    ref.invalidate(macroForecastsProvider);
    ref.invalidate(econCalendarProvider);
    ref.invalidate(econCalendarWithHistoryProvider);
    ref.invalidate(institutionalFlowsOverviewProvider);
    ref.invalidate(macroRegimeProvider);
    ref.invalidate(macroSummaryProvider);
    ref.invalidate(macroMetadataProvider);
    ref.invalidate(macroLinkagesProvider((
      country: _compareCountry,
      indicator: _compareIndicator,
      windowDays: 365,
    )));
    ref.invalidate(economicEventsProvider);
    ref.invalidate(newsProvider);
    ref.invalidate(latestMarketPricesProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(4), (prev, next) {
      if (prev == null || prev == next) return;
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });

    final regimeAsync = ref.watch(macroRegimeProvider);
    final summaryAsync = ref.watch(macroSummaryProvider);
    final latestMacroAsync = ref.watch(allMacroIndicatorsProvider);
    final inHistoryAsync = ref.watch(indiaHistoryProvider);
    final usHistoryAsync = ref.watch(usHistoryProvider);
    final euHistoryAsync = ref.watch(macroHistoryProvider('EU'));
    final jpHistoryAsync = ref.watch(macroHistoryProvider('JP'));
    final calendarAsync = ref.watch(econCalendarWithHistoryProvider);
    final latestMarketAsync = ref.watch(latestMarketPricesProvider);
    final flowsAsync = ref.watch(institutionalFlowsOverviewProvider);
    final linkagesAsync = ref.watch(
      macroLinkagesProvider((
        country: _compareCountry,
        indicator: _compareIndicator,
        windowDays: 365,
      )),
    );
    final eventsAsync = ref.watch(economicEventsProvider);
    final newsAsync = ref.watch(newsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Economy Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          _StickyNarrativeNav(
            progress: _scrollProgress,
            activeScene: _activeScene,
            onSceneTap: _jumpToScene,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
                children: [
                  _SectionShell(
                    key: _sceneKeys[_sceneNow],
                    title: 'Scene 1 · Global Pulse',
                    subtitle:
                        'Regime map + state-of-the-world strip for IN, US, EU, JP',
                    child: regimeAsync.when(
                      loading: () => const ShimmerCard(height: 250),
                      error: (err, _) => ErrorView(
                        message: friendlyErrorMessage(err),
                        onRetry: () => ref.invalidate(macroRegimeProvider),
                      ),
                      data: (regime) => _RegimeHeroCard(regime: regime),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionShell(
                    title: 'Scene 2 · Now',
                    subtitle:
                        'Compact country strip with core metrics and quick compare',
                    child: latestMacroAsync.when(
                      loading: () => const ShimmerCard(height: 280),
                      error: (err, _) => ErrorView(
                        message: friendlyErrorMessage(err),
                        onRetry: () =>
                            ref.invalidate(allMacroIndicatorsProvider),
                      ),
                      data: (latest) {
                        final histByCountry = {
                          'IN': inHistoryAsync.valueOrNull ??
                              const <MacroIndicator>[],
                          'US': usHistoryAsync.valueOrNull ??
                              const <MacroIndicator>[],
                          'EU': euHistoryAsync.valueOrNull ??
                              const <MacroIndicator>[],
                          'JP': jpHistoryAsync.valueOrNull ??
                              const <MacroIndicator>[],
                        };
                        return _NowCountryStrip(
                          latest: latest,
                          historyByCountry: histByCountry,
                          selectedCountry: _compareCountry,
                          onSelectCountry: (c) {
                            setState(() => _compareCountry = c);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionShell(
                    key: _sceneKeys[_sceneNext],
                    title: 'Scene 3 · Next',
                    subtitle: 'Policy timeline with impact tiers and countdown',
                    child: calendarAsync.when(
                      loading: () => const ShimmerCard(height: 180),
                      error: (err, _) => ErrorView(
                        message: friendlyErrorMessage(err),
                        onRetry: () =>
                            ref.invalidate(econCalendarWithHistoryProvider),
                      ),
                      data: (events) => _NextTimelineCard(
                        events: events,
                        onFocusCountry: (country) {
                          setState(() => _compareCountry = country);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionShell(
                    key: _sceneKeys[_sceneRisk],
                    title: 'Scene 4 · Risk',
                    subtitle:
                        'Stress monitor across macro, market, volatility, and freshness',
                    child: _RiskMatrixCard(
                      summaryAsync: summaryAsync,
                      latestMarketAsync: latestMarketAsync,
                      regimeAsync: regimeAsync,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionShell(
                    key: _sceneKeys[_sceneCompare],
                    title: 'Scene 5 · Compare',
                    subtitle:
                        'Macro-to-market transmission with synchronized small multiples',
                    child: _CompareCard(
                      compareCountry: _compareCountry,
                      compareIndicator: _compareIndicator,
                      brush: _compareBrush,
                      onCountryChanged: (v) =>
                          setState(() => _compareCountry = v),
                      onIndicatorChanged: (v) =>
                          setState(() => _compareIndicator = v),
                      onBrushChanged: (v) => setState(() => _compareBrush = v),
                      linkagesAsync: linkagesAsync,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionShell(
                    key: _sceneKeys[_sceneFlows],
                    title: 'India Flows Lens',
                    subtitle:
                        'Mirrored FII/DII bars, combined trend, and streak detection',
                    child: flowsAsync.when(
                      loading: () => const ShimmerCard(height: 220),
                      error: (err, _) => ErrorView(
                        message: friendlyErrorMessage(err),
                        onRetry: () =>
                            ref.invalidate(institutionalFlowsOverviewProvider),
                      ),
                      data: (flow) => _FlowsLensCard(flow: flow),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionShell(
                    key: _sceneKeys[_sceneReplay],
                    title: 'Scene 6 · Replay',
                    subtitle:
                        'Scrub through macro-linked events and market narrative snapshots',
                    child: _ReplayCard(
                      replaySlider: _replaySlider,
                      onSliderChanged: (v) => setState(() => _replaySlider = v),
                      eventsAsync: eventsAsync,
                      newsAsync: newsAsync,
                      latestMarketAsync: latestMarketAsync,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyNarrativeNav extends StatelessWidget {
  final double progress;
  final String activeScene;
  final ValueChanged<String> onSceneTap;

  const _StickyNarrativeNav({
    required this.progress,
    required this.activeScene,
    required this.onSceneTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          colors: [
            AppTheme.cardDark,
            AppTheme.cardDark.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Narrative Progress',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(AppTheme.accentBlue),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SceneChip(
                  label: 'Now',
                  icon: Icons.public,
                  selected: activeScene == _sceneNow,
                  onTap: () => onSceneTap(_sceneNow),
                ),
                _SceneChip(
                  label: 'Next',
                  icon: Icons.timeline_rounded,
                  selected: activeScene == _sceneNext,
                  onTap: () => onSceneTap(_sceneNext),
                ),
                _SceneChip(
                  label: 'Risk',
                  icon: Icons.warning_amber_rounded,
                  selected: activeScene == _sceneRisk,
                  onTap: () => onSceneTap(_sceneRisk),
                ),
                _SceneChip(
                  label: 'Compare',
                  icon: Icons.multiline_chart_rounded,
                  selected: activeScene == _sceneCompare,
                  onTap: () => onSceneTap(_sceneCompare),
                ),
                _SceneChip(
                  label: 'Flows',
                  icon: Icons.swap_vert_circle_rounded,
                  selected: activeScene == _sceneFlows,
                  onTap: () => onSceneTap(_sceneFlows),
                ),
                _SceneChip(
                  label: 'Replay',
                  icon: Icons.replay_circle_filled_rounded,
                  selected: activeScene == _sceneReplay,
                  onTap: () => onSceneTap(_sceneReplay),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SceneChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Colors.white60;
    final bg = selected
        ? AppTheme.accentBlue.withValues(alpha: 0.26)
        : Colors.white.withValues(alpha: 0.05);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? AppTheme.accentBlue : Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.03),
              Colors.transparent,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _CoveragePill extends StatelessWidget {
  final int available;
  final int expected;
  final DateTime? asOf;

  const _CoveragePill({
    required this.available,
    required this.expected,
    required this.asOf,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = expected <= 0 ? 0.0 : available / expected;
    Color c;
    if (ratio >= 0.9) {
      c = AppTheme.accentGreen;
    } else if (ratio >= 0.6) {
      c = AppTheme.accentOrange;
    } else {
      c = AppTheme.accentRed;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Coverage $available/$expected · ${asOf != null ? Formatters.relativeTime(asOf!) : "n/a"}',
        style: TextStyle(
          color: c,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _RegimeHeroCard extends StatelessWidget {
  final MacroRegimeResponse regime;

  const _RegimeHeroCard({required this.regime});

  @override
  Widget build(BuildContext context) {
    final countries = regime.countries
        .where((e) => _countryOrder.contains(e.country))
        .toList()
      ..sort((a, b) => _countryOrder
          .indexOf(a.country)
          .compareTo(_countryOrder.indexOf(b.country)));
    final asOf = regime.asOf;
    if (countries.isEmpty) {
      return const EmptyView(message: 'Regime data unavailable');
    }

    final spots = countries.map((c) {
      final growth = c.growthScore ?? 0;
      final inflation = c.inflationScore ?? 0;
      final policy = c.policyScore ?? 0;
      final confidence = c.confidence.clamp(0.0, 1.0);
      final freshness = c.freshnessHours ?? 24;
      final radius = 6 + (confidence * 6);
      final freshnessPenalty = (freshness / (24 * 45)).clamp(0.0, 1.0);
      final strokeWidth = 1.2 + (freshnessPenalty * 2.0);
      Color color;
      if (policy > 0.25) {
        color = AppTheme.accentRed;
      } else if (policy < -0.25) {
        color = AppTheme.accentGreen;
      } else {
        color = AppTheme.accentOrange;
      }
      return ScatterSpot(
        growth,
        inflation,
        dotPainter: FlDotCirclePainter(
          radius: radius,
          color: color.withValues(alpha: 0.86),
          strokeWidth: strokeWidth,
          strokeColor: Colors.white.withValues(alpha: 0.5),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _CoveragePill(available: 4, expected: 4, asOf: null),
            const SizedBox(width: 8),
            _CoveragePill(
              available: countries
                  .where((c) => (c.freshnessHours ?? 9999) < 24 * 45)
                  .length,
              expected: countries.length,
              asOf: asOf,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: ScatterChart(
            ScatterChartData(
              minX: -1.1,
              maxX: 1.1,
              minY: -1.1,
              maxY: 1.1,
              scatterSpots: spots,
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 24),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: 0.5,
                verticalInterval: 0.5,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.white.withValues(alpha: 0.07),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (v) => FlLine(
                  color: Colors.white.withValues(alpha: 0.07),
                  strokeWidth: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'X: Growth impulse · Y: Inflation pressure · Bubble color: policy stance',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: countries.map((c) {
            final scoreText =
                'G ${c.growthScore?.toStringAsFixed(2) ?? "-"} · I ${c.inflationScore?.toStringAsFixed(2) ?? "-"}';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SquareBadgeSvg(
                        assetPath:
                            SquareBadgeAssets.flagPathForCountryCode(c.country),
                        size: 14,
                        borderRadius: 2,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _countryLabel(c.country),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.regimeLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    scoreText,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _NowCountryStrip extends StatelessWidget {
  final List<MacroIndicator> latest;
  final Map<String, List<MacroIndicator>> historyByCountry;
  final String selectedCountry;
  final ValueChanged<String> onSelectCountry;

  const _NowCountryStrip({
    required this.latest,
    required this.historyByCountry,
    required this.selectedCountry,
    required this.onSelectCountry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _countryOrder.map((country) {
            final selected = selectedCountry == country;
            return ChoiceChip(
              selected: selected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SquareBadgeSvg(
                    assetPath:
                        SquareBadgeAssets.flagPathForCountryCode(country),
                    size: 14,
                    borderRadius: 2,
                  ),
                  const SizedBox(width: 6),
                  Text(_countryLabel(country)),
                ],
              ),
              onSelected: (_) => onSelectCountry(country),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _countryOrder.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final country = _countryOrder[i];
              final gdp = _latestIndicator(latest, country, 'gdp_growth');
              final inf = _latestIndicator(latest, country, 'inflation');
              final rate = _latestIndicator(latest, country, 'repo_rate');
              final unemp = _latestIndicator(latest, country, 'unemployment');
              final available =
                  [gdp, inf, rate, unemp].whereType<MacroIndicator>().length;
              final history =
                  historyByCountry[country] ?? const <MacroIndicator>[];
              final infSpark = _seriesValues(history, country, 'inflation');
              final gdpSpark = _seriesValues(history, country, 'gdp_growth');
              final chartValues = infSpark.length >= 3 ? infSpark : gdpSpark;

              final lastUpdate = [gdp, inf, rate, unemp]
                  .whereType<MacroIndicator>()
                  .map((e) => e.timestamp)
                  .fold<DateTime?>(null,
                      (acc, t) => acc == null || t.isAfter(acc) ? t : acc);

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelectCountry(country),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 250,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedCountry == country
                          ? AppTheme.accentBlue
                          : Colors.white10,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        selectedCountry == country
                            ? AppTheme.accentBlue.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SquareBadgeSvg(
                            assetPath: SquareBadgeAssets.flagPathForCountryCode(
                                country),
                            size: 16,
                            borderRadius: 3,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _countryLabel(country),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          _CoveragePill(
                              available: available,
                              expected: 4,
                              asOf: lastUpdate),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (chartValues.length >= 3)
                        SparklineWidget(
                          values: chartValues,
                          color: selectedCountry == country
                              ? AppTheme.accentBlue
                              : AppTheme.accentTeal,
                          height: 40,
                        )
                      else
                        Container(
                          height: 40,
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'Sparse history',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _MetricRow(
                          label: 'Growth',
                          value: gdp != null
                              ? Formatters.macroValue(
                                  gdp.value, gdp.indicatorName)
                              : 'n/a'),
                      _MetricRow(
                          label: 'Inflation',
                          value: inf != null
                              ? Formatters.macroValue(
                                  inf.value, inf.indicatorName)
                              : 'n/a'),
                      _MetricRow(
                          label: 'Policy',
                          value: rate != null
                              ? Formatters.macroValue(
                                  rate.value, rate.indicatorName)
                              : 'n/a'),
                      _MetricRow(
                          label: 'Unemployment',
                          value: unemp != null
                              ? Formatters.macroValue(
                                  unemp.value, unemp.indicatorName)
                              : 'n/a'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ),
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
}

class _NextTimelineCard extends StatelessWidget {
  final List<EconCalendarEvent> events;
  final ValueChanged<String> onFocusCountry;

  const _NextTimelineCard({
    required this.events,
    required this.onFocusCountry,
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = events
        .where((e) => e.eventDate
            .isAfter(DateTime.now().subtract(const Duration(days: 2))))
        .toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    if (upcoming.isEmpty) {
      return const EmptyView(message: 'No scheduled events');
    }

    final top = upcoming.take(12).toList();
    final asOf = top.isNotEmpty ? top.first.eventDate : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoveragePill(available: top.length, expected: 12, asOf: asOf),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final event = top[i];
              final days = event.eventDate.difference(DateTime.now()).inDays;
              final status = (event.status ?? '').toLowerCase();
              final importance = (event.importance ?? 'medium').toLowerCase();
              final tierColor = switch (importance) {
                'high' => AppTheme.accentRed,
                'medium' => AppTheme.accentOrange,
                _ => AppTheme.accentGreen,
              };
              final isReleased = status == 'released' || status == 'revised';
              return InkWell(
                onTap: () => onFocusCountry(event.country),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: tierColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: tierColor.withValues(alpha: 0.45),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM').format(event.eventDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SquareBadgeSvg(
                            assetPath: SquareBadgeAssets.flagPathForCountryCode(
                                event.country),
                            size: 14,
                            borderRadius: 2,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _countryLabel(event.country),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.eventName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              importance.toUpperCase(),
                              style: TextStyle(
                                color: tierColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isReleased
                                ? status.toUpperCase()
                                : (days == 0
                                    ? 'TODAY'
                                    : days > 0
                                        ? '${days}D'
                                        : 'PAST'),
                            style: TextStyle(
                              color: isReleased
                                  ? AppTheme.accentTeal
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RiskMatrixCard extends StatelessWidget {
  final AsyncValue<MacroSummaryResponse> summaryAsync;
  final AsyncValue<List<MarketPrice>> latestMarketAsync;
  final AsyncValue<MacroRegimeResponse> regimeAsync;

  const _RiskMatrixCard({
    required this.summaryAsync,
    required this.latestMarketAsync,
    required this.regimeAsync,
  });

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const ShimmerCard(height: 180),
      error: (err, _) =>
          ErrorView(message: friendlyErrorMessage(err), onRetry: null),
      data: (summary) {
        final regime = regimeAsync.valueOrNull;
        final market = latestMarketAsync.valueOrNull ?? const <MarketPrice>[];
        final byCountry = {
          for (final c in summary.countries) c.country: c,
        };
        final byRegime = {
          for (final c in regime?.countries ?? const <MacroRegimeCountry>[])
            c.country: c,
        };

        final rows = _countryOrder.map((country) {
          final s = byCountry[country];
          final macroRisk = ((s?.riskScore ?? 40) / 100).clamp(0.0, 1.0);
          final marketRisk = _marketStress(country, market);
          final volRisk = _volStress(country, market);
          final freshRisk =
              (((byRegime[country]?.freshnessHours ?? 24) / (24 * 90))
                  .clamp(0.0, 1.0));
          final avg = (macroRisk + marketRisk + volRisk + freshRisk) / 4;
          return _RiskRowData(
            country: country,
            macro: macroRisk,
            market: marketRisk,
            vol: volRisk,
            freshness: freshRisk,
            composite: avg,
          );
        }).toList();

        return Column(
          children: [
            Row(
              children: [
                _CoveragePill(
                  available: summary.countries.length,
                  expected: 4,
                  asOf: summary.asOf,
                ),
                const Spacer(),
                Text(
                  'Higher = more stress',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const _RiskHeaderRow(),
                  const SizedBox(height: 8),
                  for (final row in rows) ...[
                    _RiskDataRow(row: row),
                    if (row != rows.last) const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _marketStress(String country, List<MarketPrice> market) {
    final assets = switch (country) {
      'IN' => ['Nifty 50', 'Sensex'],
      'US' => ['S&P500', 'NASDAQ', 'Dow Jones'],
      'EU' => ['DAX', 'CAC 40', 'Euro Stoxx 50'],
      'JP' => ['Nikkei 225'],
      _ => <String>[],
    };
    final changes = market
        .where((m) => assets.contains(m.asset) && m.changePercent != null)
        .map((m) => m.changePercent!)
        .toList();
    if (changes.isEmpty) return 0.5;
    final avg = changes.reduce((a, b) => a + b) / changes.length;
    return avg >= 0 ? 0.2 : (avg.abs() / 4).clamp(0.0, 1.0);
  }

  double _volStress(String country, List<MarketPrice> market) {
    String asset;
    if (country == 'IN') {
      asset = 'India VIX';
    } else {
      asset = 'CBOE VIX';
    }
    final row = market.where((m) => m.asset == asset).firstOrNull;
    if (row == null) return 0.5;
    final price = row.price;
    return ((price - 14) / 20).clamp(0.0, 1.0);
  }
}

class _RiskHeaderRow extends StatelessWidget {
  const _RiskHeaderRow();

  @override
  Widget build(BuildContext context) {
    TextStyle s = Theme.of(context).textTheme.labelSmall!.copyWith(
          color: Colors.white54,
          fontWeight: FontWeight.w700,
        );
    return Row(
      children: [
        SizedBox(width: 66, child: Text('Country', style: s)),
        Expanded(child: Center(child: Text('Macro', style: s))),
        Expanded(child: Center(child: Text('Market', style: s))),
        Expanded(child: Center(child: Text('Vol', style: s))),
        Expanded(child: Center(child: Text('Fresh', style: s))),
        Expanded(child: Center(child: Text('Composite', style: s))),
      ],
    );
  }
}

class _RiskRowData {
  final String country;
  final double macro;
  final double market;
  final double vol;
  final double freshness;
  final double composite;

  const _RiskRowData({
    required this.country,
    required this.macro,
    required this.market,
    required this.vol,
    required this.freshness,
    required this.composite,
  });
}

class _RiskDataRow extends StatelessWidget {
  final _RiskRowData row;

  const _RiskDataRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 66,
          child: Row(
            children: [
              SquareBadgeSvg(
                assetPath:
                    SquareBadgeAssets.flagPathForCountryCode(row.country),
                size: 14,
                borderRadius: 2,
              ),
              const SizedBox(width: 6),
              Text(
                row.country,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(child: _HeatCell(value: row.macro)),
        Expanded(child: _HeatCell(value: row.market)),
        Expanded(child: _HeatCell(value: row.vol)),
        Expanded(child: _HeatCell(value: row.freshness)),
        Expanded(child: _HeatCell(value: row.composite, showNumber: true)),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  final double value;
  final bool showNumber;

  const _HeatCell({
    required this.value,
    this.showNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final color = Color.lerp(AppTheme.accentGreen, AppTheme.accentRed, v)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.48)),
        ),
        child: showNumber
            ? Text(
                '${(v * 100).round()}',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  final String compareCountry;
  final String compareIndicator;
  final double brush;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onIndicatorChanged;
  final ValueChanged<double> onBrushChanged;
  final AsyncValue<MacroLinkagesResponse> linkagesAsync;

  const _CompareCard({
    required this.compareCountry,
    required this.compareIndicator,
    required this.brush,
    required this.onCountryChanged,
    required this.onIndicatorChanged,
    required this.onBrushChanged,
    required this.linkagesAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _countryOrder.map((c) {
            return ChoiceChip(
              selected: c == compareCountry,
              label: Text(c),
              onSelected: (_) => onCountryChanged(c),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _IndicatorChip(
              label: 'Inflation',
              selected: compareIndicator == 'inflation',
              onTap: () => onIndicatorChanged('inflation'),
            ),
            _IndicatorChip(
              label: 'GDP',
              selected: compareIndicator == 'gdp_growth',
              onTap: () => onIndicatorChanged('gdp_growth'),
            ),
            _IndicatorChip(
              label: 'Policy',
              selected: compareIndicator == 'repo_rate',
              onTap: () => onIndicatorChanged('repo_rate'),
            ),
            _IndicatorChip(
              label: 'Unemployment',
              selected: compareIndicator == 'unemployment',
              onTap: () => onIndicatorChanged('unemployment'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        linkagesAsync.when(
          loading: () => const ShimmerCard(height: 220),
          error: (err, _) => ErrorView(
            message: friendlyErrorMessage(err),
            onRetry: null,
          ),
          data: (linkages) {
            final usable =
                linkages.series.where((s) => s.points.length >= 8).toList();
            if (usable.isEmpty) {
              return const EmptyView(
                  message: 'No linkage series for this combination');
            }
            final expected = math.max(1, usable.length);
            final totalPoints =
                usable.fold<int>(0, (sum, s) => sum + s.points.length);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoveragePill(
                  available: usable.length,
                  expected: expected,
                  asOf: linkages.asOf,
                ),
                const SizedBox(height: 6),
                Text(
                  'Shared Brush (${(brush * 100).round()}%) · $totalPoints points',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                Slider(
                  value: brush.clamp(0.0, 1.0),
                  onChanged: onBrushChanged,
                ),
                for (final series in usable) ...[
                  _CompareSeriesCard(series: series, brush: brush),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _IndicatorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IndicatorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentTeal.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppTheme.accentTeal : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.accentTeal : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CompareSeriesCard extends StatelessWidget {
  final MacroLinkageSeries series;
  final double brush;

  const _CompareSeriesCard({required this.series, required this.brush});

  @override
  Widget build(BuildContext context) {
    final points = [...series.points]..sort((a, b) => a.date.compareTo(b.date));
    if (points.length < 2) return const SizedBox.shrink();
    final idx =
        ((points.length - 1) * brush).round().clamp(0, points.length - 1);
    final selected = points[idx];
    final macroVals = points.map((p) => p.macroValue).toList();
    final assetVals = points.map((p) => p.assetValue).toList();
    final macroMin = macroVals.reduce(math.min);
    final macroMax = macroVals.reduce(math.max);
    final assetMin = assetVals.reduce(math.min);
    final assetMax = assetVals.reduce(math.max);
    final macroSpots = <FlSpot>[];
    final assetSpots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      macroSpots.add(FlSpot(
          i.toDouble(), _normalize(points[i].macroValue, macroMin, macroMax)));
      assetSpots.add(FlSpot(
          i.toDouble(), _normalize(points[i].assetValue, assetMin, assetMax)));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  series.asset,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'Corr ${series.correlation?.toStringAsFixed(2) ?? "n/a"}',
                style: TextStyle(
                  color: (series.correlation ?? 0) >= 0
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('dd MMM yyyy').format(selected.date)} · macro ${selected.macroValue.toStringAsFixed(2)} · asset ${selected.assetValue.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withValues(alpha: 0.06),
                      strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: macroSpots,
                    isCurved: true,
                    color: AppTheme.accentOrange,
                    barWidth: 1.8,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: assetSpots,
                    isCurved: true,
                    color: AppTheme.accentBlue,
                    barWidth: 1.8,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: idx.toDouble(),
                      color: Colors.white38,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowsLensCard extends StatelessWidget {
  final InstitutionalFlowsOverview flow;

  const _FlowsLensCard({required this.flow});

  @override
  Widget build(BuildContext context) {
    if (flow.trend.isEmpty) {
      return const EmptyView(message: 'Flow trend unavailable');
    }
    final trend = flow.trend;
    final maxAbs = trend
        .map((p) => math.max((p.fiiValue ?? 0).abs(), (p.diiValue ?? 0).abs()))
        .fold<double>(1, math.max);
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < trend.length; i++) {
      final p = trend[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 2,
          barRods: [
            BarChartRodData(
              toY: p.fiiValue ?? 0,
              color: AppTheme.accentRed.withValues(alpha: 0.8),
              width: 4,
              borderRadius: BorderRadius.circular(1),
            ),
            BarChartRodData(
              toY: p.diiValue ?? 0,
              color: AppTheme.accentGreen.withValues(alpha: 0.8),
              width: 4,
              borderRadius: BorderRadius.circular(1),
            ),
          ],
        ),
      );
    }
    final streak = _combinedStreak(trend);
    final net = flow.combinedValue ?? 0;
    final netColor = net >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CoveragePill(
              available: trend.length,
              expected: 30,
              asOf: flow.asOf,
            ),
            const Spacer(),
            Text(
              'Combined ${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)} cr',
              style: TextStyle(
                color: netColor,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Streak: ${streak >= 0 ? "Risk-on $streak sessions" : "Risk-off ${streak.abs()} sessions"}',
          style: TextStyle(
            color: streak >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              minY: -maxAbs * 1.2,
              maxY: maxAbs * 1.2,
              alignment: BarChartAlignment.spaceBetween,
              barGroups: groups,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 34),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval:
                        math.max(1, (trend.length / 6).round()).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= trend.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('dd MMM').format(trend[i].sessionDate),
                          style: const TextStyle(
                              fontSize: 8, color: Colors.white38),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxAbs / 2,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.08),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            _LegendDot(color: AppTheme.accentRed, label: 'FII'),
            SizedBox(width: 12),
            _LegendDot(color: AppTheme.accentGreen, label: 'DII'),
          ],
        ),
      ],
    );
  }

  int _combinedStreak(List<InstitutionalFlowTrendPoint> trend) {
    if (trend.isEmpty) return 0;
    final last = trend.last.combinedValue;
    final sign = last >= 0 ? 1 : -1;
    var streak = 0;
    for (var i = trend.length - 1; i >= 0; i--) {
      final s = trend[i].combinedValue >= 0 ? 1 : -1;
      if (s != sign) break;
      streak += 1;
    }
    return streak * sign;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }
}

class _ReplayCard extends StatelessWidget {
  final double replaySlider;
  final ValueChanged<double> onSliderChanged;
  final AsyncValue<List<EconomicEvent>> eventsAsync;
  final AsyncValue<List<NewsArticle>> newsAsync;
  final AsyncValue<List<MarketPrice>> latestMarketAsync;
  final ThemeData theme;

  const _ReplayCard({
    required this.replaySlider,
    required this.onSliderChanged,
    required this.eventsAsync,
    required this.newsAsync,
    required this.latestMarketAsync,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (eventsAsync.isLoading || newsAsync.isLoading) {
      return const ShimmerCard(height: 210);
    }
    if (eventsAsync.hasError) {
      return ErrorView(
        message: friendlyErrorMessage(eventsAsync.error),
        onRetry: null,
      );
    }
    if (newsAsync.hasError) {
      return ErrorView(
        message: friendlyErrorMessage(newsAsync.error),
        onRetry: null,
      );
    }

    final events = eventsAsync.valueOrNull ?? const <EconomicEvent>[];
    final news = newsAsync.valueOrNull ?? const <NewsArticle>[];
    final entries = _buildEntries(events, news);
    if (entries.isEmpty) {
      return const EmptyView(message: 'No replay entries');
    }
    final idx = ((entries.length - 1) * replaySlider)
        .round()
        .clamp(0, entries.length - 1);
    final entry = entries[idx];
    final linked = _findLinkedMarket(
        entry.entity, latestMarketAsync.valueOrNull ?? const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoveragePill(
          available: entries.length,
          expected: 60,
          asOf: entry.timestamp,
        ),
        const SizedBox(height: 8),
        Text(
          '${idx + 1}/${entries.length} · ${DateFormat('dd MMM yyyy · HH:mm').format(entry.timestamp.toLocal())}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: Colors.white54,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Slider(
          value: replaySlider.clamp(0.0, 1.0),
          onChanged: onSliderChanged,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            color: Colors.white.withValues(alpha: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.impactColor(entry.impact)
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (entry.impact.isEmpty ? 'market_signal' : entry.impact)
                          .toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.impactColor(entry.impact),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    entry.source,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                entry.subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              if (linked != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          linked.asset,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        linked.changePercent != null
                            ? Formatters.changeTag(linked.changePercent)
                            : 'n/a',
                        style: TextStyle(
                          color: (linked.changePercent ?? 0) >= 0
                              ? AppTheme.accentGreen
                              : AppTheme.accentRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<_ReplayEntry> _buildEntries(
    List<EconomicEvent> events,
    List<NewsArticle> news,
  ) {
    final out = <_ReplayEntry>[];
    for (final e in events.take(80)) {
      out.add(
        _ReplayEntry(
          timestamp: e.createdAt,
          title: 'Signal: ${e.entity.replaceAll('_', ' ')}',
          subtitle:
              '${e.eventType} · confidence ${(e.confidence * 100).round()}%',
          impact: e.impact,
          entity: e.entity,
          source: 'events',
        ),
      );
    }
    for (final n in news.take(80)) {
      final title = n.title;
      if (title.isEmpty) continue;
      out.add(
        _ReplayEntry(
          timestamp: n.timestamp,
          title: title,
          subtitle: n.summary ?? n.source,
          impact: n.impact ?? '',
          entity: n.primaryEntity ?? '',
          source: n.source,
        ),
      );
    }
    out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return out.take(120).toList();
  }

  MarketPrice? _findLinkedMarket(String entity, List<MarketPrice> market) {
    if (entity.isEmpty) return null;
    final normalized = entity.toLowerCase();
    final map = <String, List<String>>{
      'crude_oil': ['crude oil'],
      'gold': ['gold'],
      'silver': ['silver'],
      'usd_inr': ['USD/INR'],
      'us10y': ['US 10Y Treasury Yield'],
      'sp500': ['S&P500'],
      'nasdaq': ['NASDAQ', 'Nasdaq 100'],
      'dow_jones': ['Dow Jones'],
      'nifty_50': ['Nifty 50'],
      'sensex': ['Sensex'],
      'natural_gas': ['natural gas'],
      'copper': ['copper'],
    };
    final targets = map[normalized] ?? [entity.replaceAll('_', ' ')];
    for (final target in targets) {
      for (final row in market) {
        if (row.asset.toLowerCase() == target.toLowerCase()) {
          return row;
        }
      }
    }
    return null;
  }
}

class _ReplayEntry {
  final DateTime timestamp;
  final String title;
  final String subtitle;
  final String impact;
  final String entity;
  final String source;

  const _ReplayEntry({
    required this.timestamp,
    required this.title,
    required this.subtitle,
    required this.impact,
    required this.entity,
    required this.source,
  });
}
