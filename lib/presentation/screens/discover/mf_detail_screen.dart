import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/chart_widget.dart';
import 'widgets/score_bar.dart';
import 'widgets/metric_grid.dart';

class MfDetailScreen extends ConsumerStatefulWidget {
  final String schemeCode;
  final DiscoverMutualFundItem? initialItem;

  const MfDetailScreen({super.key, required this.schemeCode, this.initialItem});

  @override
  ConsumerState<MfDetailScreen> createState() => _MfDetailScreenState();
}

class _MfDetailScreenState extends ConsumerState<MfDetailScreen> {
  int _selectedDays = 365;
  double? _periodChange; // persists across rebuilds to avoid flash

  static const _periodOptions = [
    (label: '1W', days: 7),
    (label: '1M', days: 30),
    (label: '3M', days: 90),
    (label: '6M', days: 180),
    (label: '1Y', days: 365),
    (label: '3Y', days: 1095),
    (label: '5Y', days: 1825),
  ];

  late DiscoverMutualFundItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.initialItem != null) {
      item = widget.initialItem!;
      return _buildContent(theme, item);
    }

    final detailAsync = ref.watch(discoverMfDetailProvider(widget.schemeCode));
    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Fund Detail')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Fund Detail')),
        body: const Center(child: Text('Error loading fund details')),
      ),
      data: (loadedItem) {
        item = loadedItem;
        return _buildContent(theme, loadedItem);
      },
    );
  }

  Widget _buildContent(ThemeData theme, DiscoverMutualFundItem item) {
    final historyAsync = ref.watch(
      discoverMfHistoryProvider(
        (schemeCode: item.schemeCode, days: _selectedDays),
      ),
    );

    // Compute period change % from chart data (persist to avoid flash)
    List<double> chartPrices = [];
    List<DateTime> chartTimestamps = [];
    historyAsync.whenData((history) {
      if (history.points.length >= 2) {
        chartPrices = history.points.map((p) => p.value).toList();
        chartTimestamps = history.points.map((p) => p.date).toList();
        // Override last point with live NAV so chart matches header
        if (chartPrices.isNotEmpty) {
          chartPrices[chartPrices.length - 1] = item.nav;
        }
        final first = chartPrices.first;
        final last = chartPrices.last;
        if (first > 0) _periodChange = ((last - first) / first) * 100;
      }
    });

    final isPositive = (_periodChange ?? 0) >= 0;
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    return Scaffold(
      appBar: AppBar(title: const Text('Fund Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Quality Badges ──
            if (item.qualityBadges.isNotEmpty) ...[
              _buildQualityBadges(theme),
              const SizedBox(height: 12),
            ],

            // ── Header ──
            _buildHeader(theme),
            const SizedBox(height: 12),

            // ── NAV Price + Period Change ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹ ${Formatters.fullPrice(item.nav)}',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                if (_periodChange != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${isPositive ? "+" : ""}${_periodChange!.toStringAsFixed(2)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Period Selector + Chart ──
            _buildPeriodSelector(theme),
            const SizedBox(height: 10),
            historyAsync.when(
              data: (history) {
                if (history.points.isEmpty) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: Text('No chart data')),
                  );
                }
                return PriceLineChart(
                  key: ValueKey('mf_chart_$_selectedDays'),
                  prices: chartPrices,
                  timestamps: chartTimestamps,
                  isShortRange: _selectedDays <= 90,
                  pricePrefix: '₹ ',
                );
              },
              loading: () => const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Failed to load chart',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white38),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Score ──
            _buildScoreCard(theme),
            const SizedBox(height: 12),

            // ── What Makes This Fund Stand Out ──
            if (_buildQualityReasons().length >= 2) ...[
              _buildQualityReasonsInline(theme),
              const SizedBox(height: 12),
            ],

            // ── Category Rank ──
            if ((item.categoryRank != null && item.categoryTotal != null) ||
                (item.subCategoryRank != null && item.subCategoryTotal != null)) ...[
              _buildCategoryRankCard(theme),
              const SizedBox(height: 12),
            ],

            // ── Returns ──
            _buildReturnsCard(theme),
            const SizedBox(height: 12),

            // ── Key Metrics ──
            _buildMetricsCard(theme),
            const SizedBox(height: 12),

            // ── Peer Comparison ──
            _buildPeerComparison(theme),
            const SizedBox(height: 12),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Quality Badges ──────────────────────────────────────────────────────

  Widget _buildQualityBadges(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: item.qualityBadges.map((badge) {
        final color = _badgeColor(badge);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_badgeIcon(badge), size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _badgeColor(String badge) {
    final lower = badge.toLowerCase();
    if (lower.contains('top performer')) return AppTheme.accentGreen;
    if (lower.contains('consistent')) return AppTheme.accentBlue;
    if (lower.contains('cost efficient')) return AppTheme.accentTeal;
    if (lower.contains('proven') || lower.contains('track record')) {
      return AppTheme.accentOrange;
    }
    return AppTheme.accentGray;
  }

  IconData _badgeIcon(String badge) {
    final lower = badge.toLowerCase();
    if (lower.contains('top performer')) return Icons.trending_up_rounded;
    if (lower.contains('consistent')) return Icons.show_chart_rounded;
    if (lower.contains('cost efficient')) return Icons.savings_rounded;
    if (lower.contains('proven') || lower.contains('track record')) {
      return Icons.verified_rounded;
    }
    return Icons.star_rounded;
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.displayName ?? item.schemeName,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (item.category != null) ...[
              Flexible(
                child: Text(
                  item.category!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (item.riskLevel != null) _buildRiskBadge(theme),
          ],
        ),
        if (item.amc != null) ...[
          const SizedBox(height: 4),
          Text(
            '${item.amc!} · Direct · Growth',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ],
    );
  }

  Widget _buildRiskBadge(ThemeData theme) {
    final risk = item.riskLevel!.toLowerCase();
    final Color color;
    if (risk.contains('low')) {
      color = AppTheme.accentGreen;
    } else if (risk.contains('moderate') || risk.contains('medium')) {
      color = AppTheme.accentOrange;
    } else if (risk.contains('high') || risk.contains('very high')) {
      color = AppTheme.accentRed;
    } else {
      color = AppTheme.accentGray;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.riskLevel!,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Period Selector ─────────────────────────────────────────────────────

  Widget _buildPeriodSelector(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periodOptions.map((opt) {
          final isSelected = opt.days == _selectedDays;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(opt.label),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedDays = opt.days),
              showCheckmark: false,
              selectedColor: AppTheme.accentBlue.withValues(alpha: 0.25),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.accentBlue.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? AppTheme.accentBlue : Colors.white60,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Score Card ──────────────────────────────────────────────────────────

  Widget _buildScoreCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Score',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: 10),
                Text(
                  ScoreBar.formatMinified(item.score),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ScoreBar.scoreColor(item.score),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ScoreBreakdownBar(
              segments: [
                ScoreSegment(
                  label: 'Return',
                  value: item.scoreReturn,
                  color: AppTheme.accentGreen,
                ),
                ScoreSegment(
                  label: 'Risk',
                  value: item.scoreRisk,
                  color: AppTheme.accentBlue,
                ),
                ScoreSegment(
                  label: 'Cost',
                  value: item.scoreCost,
                  color: AppTheme.accentTeal,
                ),
                ScoreSegment(
                  label: 'Consistency',
                  value: item.scoreConsistency,
                  color: AppTheme.accentOrange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Rank Card ─────────────────────────────────────────────────

  Widget _buildCategoryRankCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category Rank', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),

            // Sub-category rank (more granular: e.g. Large Cap, Mid Cap)
            if (item.subCategoryRank != null && item.subCategoryTotal != null)
              _buildRankRow(
                theme,
                rank: item.subCategoryRank!,
                total: item.subCategoryTotal!,
                label: item.subCategory ?? item.category ?? 'Sub-Category',
              ),

            // Category rank (broader: e.g. Equity, Debt)
            if (item.categoryRank != null && item.categoryTotal != null) ...[
              if (item.subCategoryRank != null) const SizedBox(height: 14),
              _buildRankRow(
                theme,
                rank: item.categoryRank!,
                total: item.categoryTotal!,
                label: item.category ?? 'Category',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRankRow(
    ThemeData theme, {
    required int rank,
    required int total,
    required String label,
  }) {
    final fraction = total > 0 ? (rank / total).clamp(0.0, 1.0) : 0.0;
    final percentile = total > 0 ? ((rank / total) * 100).round() : 0;
    final isTopQuartile = percentile <= 25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '#$rank',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isTopQuartile
                    ? AppTheme.accentGreen
                    : AppTheme.accentOrange,
              ),
            ),
            Text(
              ' of $total',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white60),
            ),
            Text(
              ' in ',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white60),
            ),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Visual position bar
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentGreen,
                          isTopQuartile
                              ? AppTheme.accentGreen
                              : AppTheme.accentOrange,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned(
                  left: (constraints.maxWidth * fraction - 6)
                      .clamp(0.0, constraints.maxWidth - 12),
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Best',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white38)),
            Text(
              'Top $percentile%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isTopQuartile ? AppTheme.accentGreen : Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text('Worst',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white38)),
          ],
        ),
      ],
    );
  }

  // ── Returns Card ────────────────────────────────────────────────────────

  Widget _buildReturnsCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Returns', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _returnColumn(theme, '1Y', item.returns1y)),
                Expanded(child: _returnColumn(theme, '3Y', item.returns3y)),
                Expanded(child: _returnColumn(theme, '5Y', item.returns5y)),
              ],
            ),
            // Returns vs category average
            if (_hasAnyCategoryAvg()) ...[
              const SizedBox(height: 14),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 10),
              Text(
                'vs Category Average',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 8),
              if (item.returns1y != null && item.categoryAvgReturns1y != null)
                _buildReturnComparison(
                  theme,
                  '1Y',
                  item.returns1y!,
                  item.categoryAvgReturns1y!,
                ),
              if (item.returns3y != null && item.categoryAvgReturns3y != null)
                _buildReturnComparison(
                  theme,
                  '3Y',
                  item.returns3y!,
                  item.categoryAvgReturns3y!,
                ),
              if (item.returns5y != null && item.categoryAvgReturns5y != null)
                _buildReturnComparison(
                  theme,
                  '5Y',
                  item.returns5y!,
                  item.categoryAvgReturns5y!,
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasAnyCategoryAvg() {
    return (item.returns1y != null && item.categoryAvgReturns1y != null) ||
        (item.returns3y != null && item.categoryAvgReturns3y != null) ||
        (item.returns5y != null && item.categoryAvgReturns5y != null);
  }

  Widget _buildReturnComparison(
    ThemeData theme,
    String period,
    double fundReturn,
    double categoryAvg,
  ) {
    final beats = fundReturn >= categoryAvg;
    final color = beats ? AppTheme.accentGreen : AppTheme.accentRed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              period,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white54, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            beats ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            'Fund: ${fundReturn.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'vs',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
          const SizedBox(width: 8),
          Text(
            'Avg: ${categoryAvg.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _returnColumn(ThemeData theme, String label, double? value) {
    final String display;
    final Color color;
    if (value != null) {
      display = '${value.toStringAsFixed(1)}%';
      color = value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    } else {
      display = '\u2014';
      color = Colors.white38;
    }

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Text(
          display,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Key Metrics Card ────────────────────────────────────────────────────

  Widget _buildMetricsCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Metrics', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            MetricGrid(
              items: [
                MetricItem(
                  label: 'AUM',
                  value: item.aumCr != null
                      ? '${NumberFormat('#,##,###', 'en_IN').format(item.aumCr!.round())} Cr'
                      : '\u2014',
                  valueColor: item.aumCr == null ? Colors.white38 : null,
                ),
                MetricItem(
                  label: 'Expense Ratio',
                  value: item.expenseRatio != null
                      ? '${item.expenseRatio!.toStringAsFixed(2)}%'
                      : '\u2014',
                  valueColor: _expenseColor(item.expenseRatio),
                ),
                MetricItem(
                  label: 'Sharpe',
                  value: item.sharpe?.toStringAsFixed(2) ?? '\u2014',
                  valueColor: _sharpeColor(item.sharpe),
                ),
                MetricItem(
                  label: 'Sortino',
                  value: item.sortino?.toStringAsFixed(2) ?? '\u2014',
                  valueColor: _sharpeColor(item.sortino),
                ),
                MetricItem(
                  label: 'Std Dev',
                  value: item.stdDev?.toStringAsFixed(2) ?? '\u2014',
                  valueColor: item.stdDev == null ? Colors.white38 : null,
                ),
                if (item.fundAgeYears != null)
                  MetricItem(
                    label: 'Fund Age',
                    value: '${item.fundAgeYears!.toStringAsFixed(1)} years',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── What Makes This Fund Good ─────────────────────────────────────────

  List<(IconData, Color, String)> _buildQualityReasons() {
    final reasons = <(IconData, Color, String)>[];

    if (item.returns3y != null &&
        item.categoryAvgReturns3y != null &&
        item.returns3y! > item.categoryAvgReturns3y!) {
      reasons.add((
        Icons.trending_up_rounded,
        AppTheme.accentGreen,
        'Outperforms category average over 3 years',
      ));
    }

    if (item.expenseRatio != null && item.expenseRatio! < 1.0) {
      reasons.add((
        Icons.savings_rounded,
        AppTheme.accentTeal,
        'Low cost with expense ratio under 1%',
      ));
    }

    if (item.fundAgeYears != null && item.fundAgeYears! >= 5) {
      reasons.add((
        Icons.verified_rounded,
        AppTheme.accentBlue,
        'Established fund with ${item.fundAgeYears!.toStringAsFixed(1)} years of track record',
      ));
    }

    if (item.subCategoryRank != null &&
        item.subCategoryTotal != null &&
        item.subCategoryTotal! > 0 &&
        item.subCategoryRank! <= (item.subCategoryTotal! * 0.2).ceil()) {
      final catName = item.subCategory ?? item.category ?? 'its category';
      reasons.add((
        Icons.emoji_events_rounded,
        AppTheme.accentOrange,
        'Ranked in top 20% of $catName',
      ));
    } else if (item.categoryRank != null &&
        item.categoryTotal != null &&
        item.categoryTotal! > 0 &&
        item.categoryRank! <= (item.categoryTotal! * 0.2).ceil()) {
      final catName = item.category ?? 'its category';
      reasons.add((
        Icons.emoji_events_rounded,
        AppTheme.accentOrange,
        'Ranked in top 20% of $catName',
      ));
    }

    return reasons;
  }

  Widget _buildQualityReasonsInline(ThemeData theme) {
    final reasons = _buildQualityReasons();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why This Fund Stands Out',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...reasons.map((r) {
          final (icon, color, text) = r;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Peer Comparison ──────────────────────────────────────────────────────

  Widget _buildPeerComparison(ThemeData theme) {
    final peersAsync = ref.watch(discoverMfPeersProvider(item.schemeCode));

    return peersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (peers) {
        if (peers.isEmpty) return const SizedBox.shrink();

        final peerLabel = item.subCategory ?? item.category ?? 'Category';
        const double nameWidth = 130;
        const double colWidth = 76;
        final headerStyle =
            theme.textTheme.labelSmall?.copyWith(color: Colors.white38);

        Widget dataCell(String text, {TextStyle? style}) => SizedBox(
              width: colWidth,
              child: Text(text,
                  textAlign: TextAlign.right,
                  style: style ?? theme.textTheme.bodySmall),
            );

        Widget headerCell(String text) =>
            dataCell(text, style: headerStyle);

        // Unified scrollable data columns
        Widget buildDataColumns() {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  headerCell('NAV'),
                  headerCell('Score'),
                  headerCell('1Y Ret'),
                  headerCell('AUM Cr'),
                  headerCell('Exp %'),
                ]),
                Divider(
                    height: 12,
                    color: Colors.white.withValues(alpha: 0.08)),
                ...peers.map((peer) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      dataCell(Formatters.fullPrice(peer.nav)),
                      dataCell(
                        ScoreBar.formatMinified(peer.score),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ScoreBar.scoreColor(peer.score),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      dataCell(
                        peer.returns1y != null
                            ? '${peer.returns1y!.toStringAsFixed(1)}%'
                            : '\u2014',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: peer.returns1y != null
                              ? (peer.returns1y! >= 0
                                  ? AppTheme.accentGreen
                                  : AppTheme.accentRed)
                              : Colors.white38,
                        ),
                      ),
                      dataCell(
                        peer.aumCr != null
                            ? Formatters.compactNumber(peer.aumCr!)
                            : '\u2014',
                      ),
                      dataCell(
                        peer.expenseRatio != null
                            ? '${peer.expenseRatio!.toStringAsFixed(2)}%'
                            : '\u2014',
                      ),
                    ]),
                  );
                }),
              ],
            ),
          );
        }

        // Fixed name column
        Widget buildNameColumn() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: nameWidth,
                child: Text('Name', style: headerStyle),
              ),
              Divider(
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.08)),
              ...peers.map((peer) => InkWell(
                    onTap: () => context.push(
                      '/discover/mf/${Uri.encodeComponent(peer.schemeCode)}',
                      extra: peer,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(
                        width: nameWidth,
                        child: Text(
                          peer.displayName ?? peer.schemeName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )),
            ],
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peers in $peerLabel',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildNameColumn(),
                    Expanded(child: buildDataColumns()),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Metric Color Helpers ─────────────────────────────────────────────────

  static Color? _expenseColor(double? expense) {
    if (expense == null) return Colors.white38;
    if (expense < 0.5) return AppTheme.accentGreen;
    if (expense > 1.5) return AppTheme.accentRed;
    return null;
  }

  static Color? _sharpeColor(double? sharpe) {
    if (sharpe == null) return Colors.white38;
    if (sharpe > 1.5) return AppTheme.accentGreen;
    if (sharpe < 0.5) return AppTheme.accentRed;
    return null;
  }
}
