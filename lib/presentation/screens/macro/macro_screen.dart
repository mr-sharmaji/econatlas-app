import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/square_badge_assets.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/institutional_flow_overview.dart';
import '../../../data/models/macro_indicator.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

// =============================================================================
// Helpers
// =============================================================================

const _indicatorOrder = ['inflation', 'gdp_growth', 'unemployment', 'repo_rate'];
const _countries = ['IN', 'US', 'EU', 'JP'];

String _countryLabel(String code) {
  switch (code.toUpperCase()) {
    case 'IN': return 'India';
    case 'US': return 'United States';
    case 'EU': return 'Europe';
    case 'JP': return 'Japan';
    default: return code;
  }
}

IconData _iconFor(String name) {
  switch (name) {
    case 'inflation_cpi':
    case 'inflation': return Icons.trending_up;
    case 'repo_rate': return Icons.account_balance;
    case 'gdp_growth': return Icons.bar_chart;
    case 'unemployment': return Icons.people_outline;
    default: return Icons.analytics;
  }
}

/// Directional color for macro values.
/// inflation/unemployment: red (higher = worse).
/// gdp_growth: green if positive, red if negative.
/// repo_rate: neutral.
Color _macroValueColor(String indicatorName, double value) {
  switch (indicatorName) {
    case 'inflation':
    case 'inflation_cpi':
      return value > 6 ? AppTheme.accentRed : (value > 4 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'unemployment':
      return value > 6 ? AppTheme.accentRed : (value > 4 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'gdp_growth':
      return value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    default:
      return Colors.white70;
  }
}

MacroIndicator? _latest(List<MacroIndicator> list, String name, String country) {
  final matches = list
      .where((i) => i.indicatorName == name && i.country == country)
      .toList();
  if (matches.isEmpty) return null;
  matches.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return matches.first;
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
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _openDetail(MacroIndicator ind) {
    context.push(
      '/macro/detail/${ind.country}/${ind.indicatorName}',
      extra: ind,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(4), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final macroAsync = ref.watch(allMacroIndicatorsProvider);
    final flowAsync = ref.watch(institutionalFlowsOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Economy'),
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
          ref.invalidate(institutionalFlowsOverviewProvider);
        },
        child: macroAsync.when(
          loading: () => const ShimmerList(itemCount: 6),
          error: (err, _) => ErrorView(
            message: friendlyErrorMessage(err),
            onRetry: () => ref.invalidate(allMacroIndicatorsProvider),
          ),
          data: (indicators) {
            final filtered = indicators
                .where((i) =>
                    i.indicatorName != 'interest_rate' &&
                    i.indicatorName != 'fii_net_cash' &&
                    i.indicatorName != 'dii_net_cash')
                .toList();

            if (filtered.isEmpty) {
              return const EmptyView(
                message: 'No macro data available',
                icon: Icons.analytics_outlined,
              );
            }

            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
              children: [
                // Section 1: India Headline
                _IndiaHeadlineCard(
                  indicators: filtered,
                  onTap: _openDetail,
                ),
                const SizedBox(height: 14),

                // Section 2: Global Snapshot (horizontal)
                _GlobalSnapshotSection(
                  indicators: filtered,
                  onTap: _openDetail,
                ),
                const SizedBox(height: 14),

                // Section 3: Per-indicator comparison cards
                ..._indicatorOrder.map((name) {
                  final items = _countries
                      .map((c) => _latest(filtered, name, c))
                      .toList();
                  if (items.every((i) => i == null)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _IndicatorComparisonCard(
                      indicatorName: name,
                      countryIndicators: Map.fromIterables(
                        _countries,
                        items,
                      ),
                      onTap: _openDetail,
                    ),
                  );
                }),

                // Section 4: FII/DII Flows
                _FlowsSection(flowAsync: flowAsync),
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
// Section 1: India Headline Card
// =============================================================================

class _IndiaHeadlineCard extends StatelessWidget {
  final List<MacroIndicator> indicators;
  final ValueChanged<MacroIndicator> onTap;

  const _IndiaHeadlineCard({required this.indicators, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _indicatorOrder
        .map((name) => _latest(indicators, name, 'IN'))
        .toList();

    if (items.every((i) => i == null)) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                SquareBadgeSvg(
                  assetPath: SquareBadgeAssets.flagPathForCountryCode('IN'),
                  size: 28,
                  borderRadius: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'India',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Key Economic Indicators',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 2×2 Grid
            Row(
              children: [
                Expanded(child: _headlineTile(theme, items[0])),
                const SizedBox(width: 10),
                Expanded(child: _headlineTile(theme, items[1])),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _headlineTile(theme, items[2])),
                const SizedBox(width: 10),
                Expanded(child: _headlineTile(theme, items[3])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headlineTile(ThemeData theme, MacroIndicator? ind) {
    if (ind == null) {
      return Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    final color = _macroValueColor(ind.indicatorName, ind.value);

    return GestureDetector(
      onTap: () => onTap(ind),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(ind.indicatorName), size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    displayName(ind.indicatorName),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              Formatters.macroValue(ind.value, ind.indicatorName),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              Formatters.relativeTime(ind.timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white38,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Section 2: Global Snapshot (Horizontal)
// =============================================================================

class _GlobalSnapshotSection extends StatelessWidget {
  final List<MacroIndicator> indicators;
  final ValueChanged<MacroIndicator> onTap;

  const _GlobalSnapshotSection({required this.indicators, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Global Snapshot',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _countries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _CountryCard(
              countryCode: _countries[i],
              indicators: indicators,
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryCard extends StatelessWidget {
  final String countryCode;
  final List<MacroIndicator> indicators;
  final ValueChanged<MacroIndicator> onTap;

  const _CountryCard({
    required this.countryCode,
    required this.indicators,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _indicatorOrder
        .map((name) => _latest(indicators, name, countryCode))
        .toList();

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: flag + name
          Row(
            children: [
              SquareBadgeSvg(
                assetPath: SquareBadgeAssets.flagPathForCountryCode(countryCode),
                size: 22,
                borderRadius: 6,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _countryLabel(countryCode),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Indicator rows
          ...List.generate(_indicatorOrder.length, (i) {
            final ind = items[i];
            return _countryCardRow(theme, _indicatorOrder[i], ind);
          }),
        ],
      ),
    );
  }

  Widget _countryCardRow(ThemeData theme, String name, MacroIndicator? ind) {
    final value = ind != null
        ? Formatters.macroValue(ind.value, ind.indicatorName)
        : '—';
    final color = ind != null
        ? _macroValueColor(ind.indicatorName, ind.value)
        : Colors.white38;

    return GestureDetector(
      onTap: ind != null ? () => onTap(ind) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayName(name),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Section 3: Per-Indicator Comparison Card
// =============================================================================

class _IndicatorComparisonCard extends StatelessWidget {
  final String indicatorName;
  final Map<String, MacroIndicator?> countryIndicators;
  final ValueChanged<MacroIndicator> onTap;

  const _IndicatorComparisonCard({
    required this.indicatorName,
    required this.countryIndicators,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(_iconFor(indicatorName), size: 18, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Text(
                  displayName(indicatorName),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Country rows
            ...countryIndicators.entries.map((entry) {
              final code = entry.key;
              final ind = entry.value;
              return _comparisonRow(theme, code, ind);
            }),
          ],
        ),
      ),
    );
  }

  Widget _comparisonRow(ThemeData theme, String code, MacroIndicator? ind) {
    final value = ind != null
        ? Formatters.macroValue(ind.value, ind.indicatorName)
        : '—';
    final color = ind != null
        ? _macroValueColor(ind.indicatorName, ind.value)
        : Colors.white38;

    return InkWell(
      onTap: ind != null ? () => onTap(ind) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            SquareBadgeSvg(
              assetPath: SquareBadgeAssets.flagPathForCountryCode(code),
              size: 18,
              borderRadius: 4,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _countryLabel(code),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (ind != null)
              Text(
                Formatters.relativeTime(ind.timestamp),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white38,
                  fontSize: 9,
                ),
              ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Section 4: FII/DII Flows
// =============================================================================

class _FlowsSection extends StatelessWidget {
  final AsyncValue<InstitutionalFlowsOverview> flowAsync;

  const _FlowsSection({required this.flowAsync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: flowAsync.when(
          loading: () => const ShimmerCard(height: 118),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (overview) {
            final fiiValue = overview.fiiValue;
            final diiValue = overview.diiValue;
            if (fiiValue == null && diiValue == null) {
              return const Text('FII/DII flow data unavailable');
            }
            final netFlow =
                overview.combinedValue ?? ((fiiValue ?? 0) + (diiValue ?? 0));
            final lastTs = overview.asOf;
            final fiiTrend = _trendSeries(overview.trend, isFii: true);
            final diiTrend = _trendSeries(overview.trend, isFii: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Institutional Flows',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (lastTs != null)
                      Text(
                        Formatters.asOfDate(lastTs),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white54),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _flowRow(context, 'Foreign (FII)', fiiValue, trendValues: fiiTrend),
                const SizedBox(height: 8),
                _flowRow(context, 'Domestic (DII)', diiValue, trendValues: diiTrend),
                const SizedBox(height: 8),
                _flowRow(context, 'Net', netFlow),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _flowRow(
    BuildContext context,
    String label,
    double? value, {
    List<double>? trendValues,
  }) {
    final theme = Theme.of(context);
    final color = (value ?? 0) >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trendValues != null && trendValues.length >= 2) ...[
          _miniSparkline(trendValues, color),
          const SizedBox(width: 8),
        ],
        Text(
          _flowValue(value),
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _flowValue(double? value) {
    if (value == null) return 'N/A';
    return '\u20B9 ${Formatters.fullPrice(value)} Cr';
  }

  List<double> _trendSeries(
    List<InstitutionalFlowTrendPoint> trend, {
    required bool isFii,
  }) {
    return trend
        .map((point) => isFii ? point.fiiValue : point.diiValue)
        .whereType<double>()
        .toList();
  }

  Widget _miniSparkline(List<double> values, Color color) {
    if (values.length < 2) return const SizedBox(width: 64, height: 18);

    final points = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final span = (maxY - minY).abs();
    final pad = span == 0 ? (maxY.abs() * 0.05 + 1) : span * 0.22;

    return SizedBox(
      width: 64,
      height: 18,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              barWidth: 1.8,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final atEnd = _rangeScrollController.offset >=
        _rangeScrollController.position.maxScrollExtent - 4;
    if (_showRangeScrollHint == atEnd) {
      setState(() => _showRangeScrollHint = !atEnd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String country = widget.initialIndicator?.country ??
        widget.countryOverride ??
        ref.watch(selectedCountryProvider);
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
            Text('Historical Data',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _chartRangeChips(context),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const ShimmerCard(height: 200),
              error: (err, _) => ErrorView(
                message: friendlyErrorMessage(err),
                onRetry: () => ref.invalidate(macroHistoryProvider(country)),
              ),
              data: (indicators) {
                final byIndicator = indicators
                    .where((i) => i.indicatorName == widget.indicatorName)
                    .toList()
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                if (byIndicator.isEmpty) {
                  return const EmptyView(message: 'No historical data');
                }
                final filtered = _filterByRange(byIndicator);
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'No data in this range',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }
                final isShortRange = _chartRange == ChartRange.oneMonth ||
                    _chartRange == ChartRange.threeMonths;
                final values = filtered.map((i) => i.value).toList();
                final open = values.first;
                final close = values.last;
                final high = values.reduce((a, b) => a > b ? a : b);
                final low = values.reduce((a, b) => a < b ? a : b);
                final avg =
                    values.fold<double>(0, (s, p) => s + p) / values.length;
                final spreadPct =
                    open != 0 ? ((high - low) / open) * 100 : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroRangeStatsCard(
                      open: open,
                      high: high,
                      low: low,
                      close: close,
                      avg: avg,
                      spreadPct: spreadPct,
                    ),
                    const SizedBox(height: 12),
                    PriceLineChart(
                      prices: values,
                      timestamps: filtered.map((i) => i.timestamp).toList(),
                      unit: 'percent',
                      isShortRange: isShortRange,
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
      final byIndicator = history
          .where((i) => i.indicatorName == widget.indicatorName)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final filtered = _filterByRange(byIndicator);
      if (filtered.length >= 2) {
        final first = filtered.first.value;
        final last = filtered.last.value;
        if (first != 0) rangePct = ((last - first) / first) * 100;
      }
    }
    final rangeLabel = _chartRange.label;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.macroValue(ind.value, ind.indicatorName),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (rangePct != null) ...[
              const SizedBox(height: 6),
              Text(
                '$rangeLabel change  ${Formatters.changeTag(rangePct)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: (rangePct >= 0)
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${_countryLabel(ind.country)} · Last updated ${Formatters.relativeTime(ind.timestamp)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
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
                ...ChartRange.values.map((r) {
                  final selected = r == _chartRange;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(r.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _chartRange = r),
                      selectedColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.4),
                      checkmarkColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }),
                const SizedBox(width: 24),
              ],
            ),
          ),
          if (_showRangeScrollHint)
            IgnorePointer(
              child: Container(
                width: 32,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 0),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroRangeStatsCard extends StatelessWidget {
  final double open;
  final double high;
  final double low;
  final double close;
  final double avg;
  final double? spreadPct;

  const _MacroRangeStatsCard({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.avg,
    this.spreadPct,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _stat(theme, 'Open',
                        Formatters.price(open, unit: 'percent'))),
                const SizedBox(width: 12),
                Expanded(
                    child: _stat(theme, 'High',
                        Formatters.price(high, unit: 'percent'))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _stat(
                        theme, 'Low', Formatters.price(low, unit: 'percent'))),
                const SizedBox(width: 12),
                Expanded(
                    child: _stat(theme, 'Close',
                        Formatters.price(close, unit: 'percent'))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _stat(
                        theme, 'Avg', Formatters.price(avg, unit: 'percent'))),
                if (spreadPct != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                      child: _stat(theme, 'High–Low',
                          Formatters.price(spreadPct!, unit: 'percent'))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
