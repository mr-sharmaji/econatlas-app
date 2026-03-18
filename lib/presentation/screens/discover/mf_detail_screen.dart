
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/score_bar.dart';
import 'widgets/metric_glossary.dart';
import 'widgets/position_bar.dart';
import 'widgets/radar_chart_widget.dart';
import 'widgets/grouped_bar_chart_widget.dart';
import 'widgets/stat_card.dart';

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
    // Expert mode removed — always show full details

    if (widget.initialItem != null) {
      item = widget.initialItem!;
      return _buildContent(theme, item);
    }

    final detailAsync = ref.watch(discoverMfDetailProvider(widget.schemeCode));
    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const ShimmerMfDetail(),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: Text(widget.schemeCode)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              const Text('Error loading fund details'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(
                    discoverMfDetailProvider(widget.schemeCode)),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
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

    // Use API return values for known periods (more reliable than chart calc).
    // Fall back to chart-based computation for periods without API data.
    List<double> chartPrices = [];
    List<DateTime> chartTimestamps = [];
    historyAsync.whenData((history) {
      if (history.points.length >= 2) {
        chartPrices = history.points.map((p) => p.value).toList();
        chartTimestamps = history.points.map((p) => p.date).toList();

        // Prefer API return values for known periods
        double? apiReturn;
        if (_selectedDays == 365) {
          apiReturn = item.returns1y;
        } else if (_selectedDays == 1095) {
          apiReturn = item.returns3y;
        } else if (_selectedDays == 1825) {
          apiReturn = item.returns5y;
        }
        if (apiReturn != null) {
          _periodChange = apiReturn;
        } else {
          // Compute from raw NAV history for short periods (1W, 1M, 3M, 6M)
          final first = chartPrices.first;
          final last = chartPrices.last;
          if (first > 0) _periodChange = ((last - first) / first) * 100;
        }
        // Override last chart point with live NAV for visual display only
        if (chartPrices.isNotEmpty) {
          chartPrices[chartPrices.length - 1] = item.nav;
        }
      }
    });

    final isPositive = (_periodChange ?? 0) >= 0;
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    // Determine period label for badge
    final periodLabel = _periodOptions
        .firstWhere((o) => o.days == _selectedDays,
            orElse: () => (label: '', days: 0))
        .label;

    return Scaffold(
      appBar: AppBar(title: Text(item.displayName ?? item.schemeName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Quality Badges
            if (item.qualityBadges.isNotEmpty) ...[
              _buildQualityBadges(theme),
              const SizedBox(height: 8),
            ],

            // 2. Header
            _buildHeader(theme),
            const SizedBox(height: 8),

            // 3. NAV Price + Period Change
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\u20B9 ${Formatters.fullPrice(item.nav)}',
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
                      '$periodLabel ${isPositive ? "+" : ""}${_periodChange!.toStringAsFixed(2)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Period Selector + Chart (C3)
            _buildPeriodSelector(theme),
            const SizedBox(height: 8),
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
                  pricePrefix: '\u20B9 ',
                );
              },
              loading: () => const ShimmerCard(height: 180),
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
            const SizedBox(height: 12),

            // 5. Score Card
            _buildScoreCard(theme),
            const SizedBox(height: 8),

            // 6. Fund Insights (from backend)
            if (item.fundInsights.length >= 2) ...[
              _buildFundInsightsCard(theme),
              const SizedBox(height: 8),
            ],

            // 7. Fund Ranking
            if ((item.categoryRank != null && item.categoryTotal != null) ||
                (item.subCategoryRank != null && item.subCategoryTotal != null)) ...[
              _buildCategoryRankCard(theme),
              const SizedBox(height: 8),
            ],

            // 8. Returns (with XIRR/CAGR toggle)
            _buildReturnsCard(theme),
            const SizedBox(height: 8),

            // 9. Risk & Performance
            _buildRiskPerformanceCard(theme),
            const SizedBox(height: 8),

            // 10. Portfolio / Holdings (C6)
            if (item.topHoldings != null && item.topHoldings!.isNotEmpty) ...[
              _buildHoldingsSection(theme),
              const SizedBox(height: 8),
            ],

            // 11. Key Metrics
            _buildMetricsCard(theme),
            const SizedBox(height: 8),

            // 12. Peer Comparison
            _buildPeerComparison(theme),
            const SizedBox(height: 8),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // -- Quality Badges --

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

  // -- Badge Helpers --

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

  // -- Header --

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.displayName ?? item.schemeName,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge
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
            '${item.amc!} \u00B7 Direct \u00B7 Growth',
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

  // -- Period Selector --

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

  // -- Score Card --

  Widget _buildScoreCard(ThemeData theme) {
    final breakdown = item.scoreBreakdown;
    final hasRadarData = breakdown.returnScore > 0 ||
        breakdown.riskScore > 0 ||
        breakdown.costScore > 0 ||
        breakdown.consistencyScore > 0;

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
            const SizedBox(height: 8),

            // Radar chart
            if (hasRadarData) ...[
              Center(
                child: SizedBox(
                  height: 180,
                  width: 180,
                  child: RadarChartWidget(
                  dimensions: [
                    RadarDimension(
                      label: 'Returns vs Peers',
                      value: breakdown.returnScore,
                    ),
                    RadarDimension(
                      label: 'Return Predictability',
                      value: breakdown.consistencyScore,
                    ),
                    RadarDimension(
                      label: 'Downside Protection',
                      value: breakdown.riskScore,
                    ),
                    RadarDimension(
                      label: 'Expense Efficiency',
                      value: breakdown.costScore,
                    ),
                    if (item.scoreCategoryFit != null)
                      RadarDimension(
                        label: 'Category Fit',
                        value: item.scoreCategoryFit!.toDouble(),
                      ),
                    if (breakdown.betaScore != null)
                      RadarDimension(
                        label: 'Market Shield',
                        value: breakdown.betaScore!,
                      ),
                  ],
                  fillColor: AppTheme.accentBlue,
                ),
                ),
              ),
              const SizedBox(height: 8),

              // Stat cards for each score dimension
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Returns vs Peers',
                      value: breakdown.returnScore.toStringAsFixed(1),
                      valueColor: AppTheme.accentGreen,
                      tooltip: 'How well this fund performs compared to peers in the same category.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Predictability',
                      value: breakdown.consistencyScore.toStringAsFixed(1),
                      valueColor: AppTheme.accentOrange,
                      tooltip: 'How consistent and predictable the returns are over rolling periods.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Downside Protection',
                      value: breakdown.riskScore.toStringAsFixed(1),
                      valueColor: AppTheme.accentBlue,
                      tooltip: 'How well this fund protects against drawdowns and volatility.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Expense Efficiency',
                      value: breakdown.costScore.toStringAsFixed(1),
                      valueColor: AppTheme.accentTeal,
                      tooltip: 'How cost-efficient the fund is relative to its category peers.',
                    ),
                  ),
                ],
              ),
              if (breakdown.alphaScore != null || item.scoreCategoryFit != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (breakdown.alphaScore != null)
                      Expanded(
                        child: StatCard(
                          label: 'Alpha Edge',
                          value: breakdown.alphaScore!.toStringAsFixed(1),
                          valueColor: AppTheme.accentGreen,
                          tooltip: 'Score based on the fund\'s excess return (alpha) over benchmark.',
                        ),
                      ),
                    if (breakdown.alphaScore != null && item.scoreCategoryFit != null)
                      const SizedBox(width: 8),
                    if (item.scoreCategoryFit != null)
                      Expanded(
                        child: StatCard(
                          value: item.scoreCategoryFit?.toStringAsFixed(0) ?? '-',
                          label: 'Category Mandate Fit',
                          tooltip: 'How well the fund sticks to its stated investment mandate and category objectives',
                        ),
                      ),
                    if (breakdown.alphaScore == null && item.scoreCategoryFit != null)
                      const Spacer(),
                    if (breakdown.alphaScore != null && item.scoreCategoryFit == null)
                      const Spacer(),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // -- Category Rank Card (C5: renamed to Fund Ranking) --

  Widget _buildCategoryRankCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fund Ranking', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),

            // Category rank first (broader: e.g. Equity, Debt)
            if (item.categoryRank != null && item.categoryTotal != null)
              _buildRankRow(
                theme,
                rank: item.categoryRank!,
                total: item.categoryTotal!,
                label: item.category ?? 'Category',
              ),

            // Sub-category rank second (more granular: e.g. Large Cap, Mid Cap)
            if (item.subCategoryRank != null && item.subCategoryTotal != null) ...[
              if (item.categoryRank != null) const SizedBox(height: 8),
              _buildRankRow(
                theme,
                rank: item.subCategoryRank!,
                total: item.subCategoryTotal!,
                label: item.fundClassification ?? item.subCategory ?? item.category ?? 'Sub-Category',
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
        const SizedBox(height: 8),
        PositionBar(
          min: 1,
          max: total.toDouble(),
          current: rank.toDouble(),
          minLabel: 'Best',
          maxLabel: 'Worst',
          color: isTopQuartile ? AppTheme.accentGreen : AppTheme.accentOrange,
          showNearLabel: false,
        ),
      ],
    );
  }

  // -- Returns Card (CAGR only) --

  Widget _buildReturnsCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Returns (CAGR)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _returnColumn(theme, '1Y', item.returns1y),
                ),
                Expanded(
                  child: _returnColumn(theme, '3Y', item.returns3y),
                ),
                Expanded(
                  child: _returnColumn(theme, '5Y', item.returns5y),
                ),
              ],
            ),
            // Returns vs category average (always XIRR-based from API)
            if (_hasAnyCategoryAvg()) ...[
              const SizedBox(height: 8),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 8),
              Text(
                'vs Category Average',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: GroupedBarChartWidget(
                  groups: [
                    if (item.returns1y != null || item.categoryAvgReturns1y != null)
                      BarGroup(label: '1Y', values: [
                        item.returns1y?.toDouble() ?? 0,
                        item.categoryAvgReturns1y?.toDouble() ?? 0,
                      ], colors: [AppTheme.accentBlue, Colors.white38]),
                    if (item.returns3y != null || item.categoryAvgReturns3y != null)
                      BarGroup(label: '3Y', values: [
                        item.returns3y?.toDouble() ?? 0,
                        item.categoryAvgReturns3y?.toDouble() ?? 0,
                      ], colors: [AppTheme.accentBlue, Colors.white38]),
                    if (item.returns5y != null || item.categoryAvgReturns5y != null)
                      BarGroup(label: '5Y', values: [
                        item.returns5y?.toDouble() ?? 0,
                        item.categoryAvgReturns5y?.toDouble() ?? 0,
                      ], colors: [AppTheme.accentBlue, Colors.white38]),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.accentBlue, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Fund Return', style: TextStyle(fontSize: 10, color: Colors.white54)),
                  const SizedBox(width: 12),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Category Avg', style: TextStyle(fontSize: 10, color: Colors.white54)),
                ],
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

  // -- Risk & Performance Card (C8: expert mode support) --

  Widget _buildRiskPerformanceCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risk & Performance', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            // Row 1: Sharpe, Sortino, Max Drawdown
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Sharpe',
                    value: item.sharpe?.toStringAsFixed(2) ?? '\u2014',
                    valueColor: _sharpeColor(item.sharpe),
                    tooltip: 'Sharpe ratio measures risk-adjusted returns. Higher is better — it shows how much return you earn per unit of total risk taken. Above 1.5 is excellent, below 0.5 is weak.',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Sortino',
                    value: item.sortino?.toStringAsFixed(2) ?? '\u2014',
                    valueColor: _sharpeColor(item.sortino),
                    tooltip: 'Sortino ratio is like Sharpe but only considers downside risk (losses). Higher is better. Above 2.0 is excellent — the fund protects well against losses while generating returns.',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Max DD',
                    value: item.maxDrawdown != null
                        ? '${item.maxDrawdown!.toStringAsFixed(1)}%'
                        : '\u2014',
                    valueColor: _maxDrawdownColor(item.maxDrawdown),
                    tooltip: 'Maximum Drawdown is the largest peak-to-trough decline in the fund\'s history. Lower is better — it shows the worst-case loss you could have experienced.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Alpha, Beta, Rolling Consistency
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Alpha',
                    value: item.alpha != null
                        ? '${item.alpha!.toStringAsFixed(1)}%'
                        : '\u2014',
                    valueColor: _alphaColor(item.alpha),
                    tooltip: 'Alpha measures how much the fund outperforms (or underperforms) its benchmark after adjusting for risk. Positive alpha means the fund manager is adding value beyond what the market provides.',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Beta',
                    value: item.beta?.toStringAsFixed(2) ?? '\u2014',
                    valueColor: _betaColor(item.beta),
                    tooltip: 'Beta measures the fund\'s sensitivity to market movements. Beta < 1 means the fund is defensive (moves less than the market). Beta > 1 means it\'s aggressive (amplifies market moves).',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Rolling',
                    value: item.rollingReturnConsistency != null
                        ? '${item.rollingReturnConsistency!.toStringAsFixed(1)}%'
                        : '\u2014',
                    valueColor: _rollingColor(item.rollingReturnConsistency),
                    tooltip: 'Rolling Return Consistency measures how predictable the fund\'s returns are across different time periods. Lower is better — it means returns are consistent regardless of when you invest.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -- Key Metrics Card --

  Widget _buildMetricsCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Metrics', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'AUM',
                    value: item.aumCr != null
                        ? '${NumberFormat('#,##,###', 'en_IN').format(item.aumCr!.round())} Cr'
                        : '\u2014',
                    valueColor: item.aumCr == null ? Colors.white38 : null,
                    tooltip: metricExplanations['aum'],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Expense Ratio',
                    value: item.expenseRatio != null
                        ? '${item.expenseRatio!.toStringAsFixed(2)}%'
                        : '\u2014',
                    valueColor: _expenseColor(item.expenseRatio),
                    tooltip: metricExplanations['expense_ratio'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.fundAgeYears != null)
                  Expanded(
                    child: StatCard(
                      label: 'Fund Age',
                      value: '${item.fundAgeYears!.toStringAsFixed(1)} years',
                    ),
                  ),
                if (item.fundAgeYears != null &&
                    item.stdDev != null)
                  const SizedBox(width: 8),
                if (item.stdDev != null)
                  Expanded(
                    child: StatCard(
                      value: '${item.stdDev!.toStringAsFixed(2)}%',
                      label: 'Std Deviation',
                      tooltip: metricExplanations['std_dev'],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -- Fund Insights (backend-driven, adaptive positive/negative) --

  Widget _buildFundInsightsCard(ThemeData theme) {
    final insights = item.fundInsights;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppTheme.accentOrange),
                const SizedBox(width: 8),
                Text(
                  'Key Insights',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...insights.map((insight) {
              final color = insight.isPositive
                  ? AppTheme.accentGreen
                  : insight.isNegative
                      ? AppTheme.accentRed
                      : AppTheme.accentOrange;
              final icon = insight.isPositive
                  ? Icons.check_circle_rounded
                  : insight.isNegative
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          insight.text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // -- Holdings / Portfolio Section --

  Widget _buildHoldingsSection(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio / Holdings', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),

            // Asset allocation horizontal bar
            if (item.assetAllocation != null) ...[
              Text(
                'Asset Allocation',
                style: theme.textTheme.labelMedium?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      if (item.assetAllocation!.equity > 0)
                        Expanded(
                          flex: (item.assetAllocation!.equity * 10).round(),
                          child: Container(color: AppTheme.accentBlue),
                        ),
                      if (item.assetAllocation!.debt > 0)
                        Expanded(
                          flex: (item.assetAllocation!.debt * 10).round(),
                          child: Container(color: AppTheme.accentTeal),
                        ),
                      if (item.assetAllocation!.cash > 0)
                        Expanded(
                          flex: (item.assetAllocation!.cash * 10).round(),
                          child: Container(color: AppTheme.accentOrange),
                        ),
                      if (item.assetAllocation!.other > 0)
                        Expanded(
                          flex: (item.assetAllocation!.other * 10).round(),
                          child: Container(color: AppTheme.accentGray),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (item.assetAllocation!.equity > 0)
                    _assetLegend('Equity', item.assetAllocation!.equity, AppTheme.accentBlue, theme),
                  if (item.assetAllocation!.debt > 0)
                    _assetLegend('Debt', item.assetAllocation!.debt, AppTheme.accentTeal, theme),
                  if (item.assetAllocation!.cash > 0)
                    _assetLegend('Cash', item.assetAllocation!.cash, AppTheme.accentOrange, theme),
                  if (item.assetAllocation!.other > 0)
                    _assetLegend('Other', item.assetAllocation!.other, AppTheme.accentGray, theme),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Top holdings list
            if (item.topHoldings != null && item.topHoldings!.isNotEmpty) ...[
              Text(
                'Top Holdings',
                style: theme.textTheme.labelMedium?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 6),
              ...item.topHoldings!.map((holding) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                holding.name,
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${holding.percentage.toStringAsFixed(2)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        PositionBar(
                          min: 0,
                          max: 100,
                          current: holding.percentage,
                          color: AppTheme.accentBlue,
                        ),
                      ],
                    ),
                  )),
            ],

            // Sector allocation
            if (item.sectorAllocation != null && item.sectorAllocation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Sector Allocation',
                style: theme.textTheme.labelMedium?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 6),
              ...item.sectorAllocation!.map((sector) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sector.sector,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${sector.percentage.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            // Holdings as-of date
            if (item.holdingsAsOf != null) ...[
              const SizedBox(height: 8),
              Text(
                'Holdings as of ${item.holdingsAsOf}',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetLegend(String label, double pct, Color color, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${pct.toStringAsFixed(1)}%',
          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }

  // -- Peer Comparison --

  Widget _buildPeerComparison(ThemeData theme) {
    final peersAsync = ref.watch(discoverMfPeersProvider(item.schemeCode));

    return peersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (peers) {
        if (peers.isEmpty) return const SizedBox.shrink();

        final peerLabel = item.subCategory ?? item.category ?? 'Category';
        const headerStyle = TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        );
        const cellStyle = TextStyle(fontSize: 12);

        Widget buildRow(DiscoverMutualFundItem fund,
            {bool isCurrent = false}) {
          final ret1y = fund.returns1y;
          final retColor = ret1y != null
              ? (ret1y >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
              : Colors.white38;
          final scoreColor = ScoreBar.scoreColor(fund.score);

          return InkWell(
            onTap: isCurrent
                ? null
                : () => context.push(
                      '/discover/mf/${Uri.encodeComponent(fund.schemeCode)}',
                      extra: fund,
                    ),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isCurrent
                    ? Colors.white.withValues(alpha: 0.05)
                    : null,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Fund name
                  Expanded(
                    flex: 3,
                    child: Text(
                      fund.displayName ?? fund.schemeName,
                      style: cellStyle.copyWith(
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Score badge
                  SizedBox(
                    width: 42,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ScoreBar.formatMinified(fund.score),
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 1Y Return
                  SizedBox(
                    width: 54,
                    child: Text(
                      ret1y != null
                          ? '${ret1y >= 0 ? "+" : ""}${ret1y.toStringAsFixed(1)}%'
                          : '\u2014',
                      style: cellStyle.copyWith(
                        color: retColor,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // Expense
                  SizedBox(
                    width: 48,
                    child: Text(
                      fund.expenseRatio != null
                          ? '${fund.expenseRatio!.toStringAsFixed(2)}%'
                          : '\u2014',
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // Rank (C9: prefer subCategoryRank)
                  SizedBox(
                    width: 32,
                    child: Text(
                      (fund.subCategoryRank ?? fund.categoryRank) != null
                          ? '#${fund.subCategoryRank ?? fund.categoryRank}'
                          : '\u2014',
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peers in $peerLabel',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                // Table header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 3,
                          child: Text('Fund', style: headerStyle)),
                      SizedBox(
                          width: 42,
                          child: Text('Score', style: headerStyle,
                              textAlign: TextAlign.center)),
                      SizedBox(
                          width: 54,
                          child: Text('1Y Return', style: headerStyle,
                              textAlign: TextAlign.right)),
                      SizedBox(
                          width: 48,
                          child: Text('Expense', style: headerStyle,
                              textAlign: TextAlign.right)),
                      SizedBox(
                          width: 32,
                          child: Text('Rank', style: headerStyle,
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Current fund row (highlighted)
                buildRow(item, isCurrent: true),
                // Peer rows (up to 5)
                ...peers.take(5).map((p) => buildRow(p)),
              ],
            ),
          ),
        );
      },
    );
  }

  // -- Metric Color Helpers --

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

  static Color? _maxDrawdownColor(double? dd) {
    if (dd == null) return Colors.white38;
    // Max drawdown is typically negative; more negative = worse
    if (dd > -5) return AppTheme.accentGreen;
    if (dd < -15) return AppTheme.accentRed;
    return AppTheme.accentOrange;
  }

  static Color? _alphaColor(double? alpha) {
    if (alpha == null) return Colors.white38;
    if (alpha > 0) return AppTheme.accentGreen;
    if (alpha < 0) return AppTheme.accentRed;
    return null;
  }

  static Color? _betaColor(double? beta) {
    if (beta == null) return Colors.white38;
    if (beta < 0.8) return AppTheme.accentGreen;
    if (beta > 1.2) return AppTheme.accentRed;
    return null;
  }

  static Color? _rollingColor(double? rolling) {
    if (rolling == null) return Colors.white38;
    if (rolling < 10) return AppTheme.accentGreen;
    if (rolling > 20) return AppTheme.accentRed;
    return AppTheme.accentOrange;
  }
}
