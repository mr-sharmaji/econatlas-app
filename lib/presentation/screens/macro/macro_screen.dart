import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/square_badge_assets.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
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
                // Per-indicator comparison cards
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
// Per-Indicator Comparison Card
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
