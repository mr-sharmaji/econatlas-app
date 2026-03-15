import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/score_bar.dart';
import 'widgets/metric_glossary.dart';
import 'widgets/position_bar.dart';
import 'widgets/radar_chart_widget.dart';
import 'widgets/grouped_bar_chart_widget.dart';
import 'widgets/stat_card.dart';
import 'widgets/tag_utils.dart';

enum _ReturnMode { xirr, cagr }

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
  _ReturnMode _returnMode = _ReturnMode.xirr;

  // Cached chart data for CAGR computation
  List<double> _chartPrices = [];

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

        // Cache for CAGR computation
        _chartPrices = List.of(chartPrices);

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
            // -- Quality Badges --
            if (item.qualityBadges.isNotEmpty) ...[
              _buildQualityBadges(theme),
              const SizedBox(height: 12),
            ],

            // -- Header --
            _buildHeader(theme),
            const SizedBox(height: 12),

            // -- NAV Price + Period Change --
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
            const SizedBox(height: 16),

            // -- Period Selector + Chart --
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
            const SizedBox(height: 16),

            // -- Score --
            _buildScoreCard(theme),
            const SizedBox(height: 12),

            // -- What Makes This Fund Stand Out --
            if (_buildQualityReasons().length >= 2) ...[
              _buildQualityReasonsInline(theme),
              const SizedBox(height: 12),
            ],

            // -- Why Ranked --
            if (item.whyRanked.isNotEmpty) ...[
              _buildWhyRankedCard(theme),
              const SizedBox(height: 12),
            ],

            // Tags grouped by category
            if (item.tags.isNotEmpty) ...[
              _buildGroupedTags(theme, item.tags),
              const SizedBox(height: 12),
            ],

            // -- Category Rank --
            if ((item.categoryRank != null && item.categoryTotal != null) ||
                (item.subCategoryRank != null && item.subCategoryTotal != null)) ...[
              _buildCategoryRankCard(theme),
              const SizedBox(height: 12),
            ],

            // -- Returns (with XIRR/CAGR toggle) --
            _buildReturnsCard(theme),
            const SizedBox(height: 12),

            // -- Risk & Performance --
            _buildRiskPerformanceCard(theme),
            const SizedBox(height: 12),

            // -- Key Metrics --
            _buildMetricsCard(theme),
            const SizedBox(height: 12),

            // -- Peer Comparison --
            _buildPeerComparison(theme),
            const SizedBox(height: 12),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // -- Why Ranked --

  Widget _buildWhyRankedCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 18, color: AppTheme.accentOrange),
                const SizedBox(width: 8),
                Text(
                  'Why Ranked',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...item.whyRanked.map((reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle,
                            size: 5, color: Colors.white38),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // -- Grouped Tags --

  Widget _buildGroupedTags(ThemeData theme, List<TagV2> tags) {
    final grouped = groupTagsByCategory(tags);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tags',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...grouped.entries.map((entry) {
              final catLabel = categoryLabel(entry.key);
              final catIcon = categoryIcon(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(catIcon, size: 14, color: Colors.white38),
                        const SizedBox(width: 6),
                        Text(
                          catLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white38,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: entry.value.map((tag) {
                        final td = getTagV2Display(tag);
                        return GestureDetector(
                          onTap: tag.explanation != null
                              ? () => _showTagExplanation(theme, tag)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: td.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: td.color.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(td.icon, size: 14, color: td.color),
                                const SizedBox(width: 4),
                                Text(
                                  td.label,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: td.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (tag.explanation != null) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.info_outline,
                                      size: 12,
                                      color: td.color.withValues(alpha: 0.6)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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

  void _showTagExplanation(ThemeData theme, TagV2 tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tag.tag,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: severityColor(tag.severity),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tag.explanation!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            if (tag.confidence != null) ...[
              const SizedBox(height: 12),
              Text(
                'Confidence: ${(tag.confidence! * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white38),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // -- CAGR Helpers --

  static double? _computeCagrFromPrices(List<double> prices, double years) {
    if (prices.length < 2) return null;
    final startNAV = prices.first;
    final endNAV = prices.last;
    if (startNAV <= 0) return null;
    final cagr = (math.pow(endNAV / startNAV, 1.0 / years) - 1) * 100;
    return cagr.toDouble();
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
            const SizedBox(height: 12),

            // Radar chart
            if (hasRadarData) ...[
              SizedBox(
                height: 180,
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
                    if (breakdown.alphaScore != null)
                      RadarDimension(
                        label: 'Alpha Edge',
                        value: breakdown.alphaScore!,
                      ),
                    if (item.scoreCategoryFit != null)
                      RadarDimension(
                        label: 'Category Fit',
                        value: item.scoreCategoryFit!.toDouble(),
                      ),
                  ],
                  fillColor: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(height: 12),

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

  // -- Category Rank Card --

  Widget _buildCategoryRankCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category Rank', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),

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
              if (item.subCategoryRank != null) const SizedBox(height: 12),
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
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: Text(
            'Top $percentile%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isTopQuartile ? AppTheme.accentGreen : Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // -- Returns Card (with XIRR/CAGR toggle) --

  Widget _buildReturnsCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title + segmented toggle
            Row(
              children: [
                Text('Returns', style: theme.textTheme.titleSmall),
                const Spacer(),
                SizedBox(
                  height: 32,
                  child: SegmentedButton<_ReturnMode>(
                    segments: const [
                      ButtonSegment(
                        value: _ReturnMode.xirr,
                        label: Text('XIRR', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: _ReturnMode.cagr,
                        label: Text('CAGR', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_returnMode},
                    onSelectionChanged: (newSelection) {
                      setState(() => _returnMode = newSelection.first);
                    },
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _returnColumn(theme, '1Y',
                      _getReturnValue(item.returns1y, 365, 1)),
                ),
                Expanded(
                  child: _returnColumn(theme, '3Y',
                      _getReturnValue(item.returns3y, 1095, 3)),
                ),
                Expanded(
                  child: _returnColumn(theme, '5Y',
                      _getReturnValue(item.returns5y, 1825, 5)),
                ),
              ],
            ),
            // Returns vs category average (always XIRR-based from API)
            if (_hasAnyCategoryAvg()) ...[
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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

  /// Returns the display value for a return period based on the current mode.
  /// For XIRR: uses the API-provided value.
  /// For CAGR: computes from chart history if the current chart period matches,
  /// otherwise fetches the relevant period via provider.
  double? _getReturnValue(double? xirrValue, int days, double years) {
    if (_returnMode == _ReturnMode.xirr) return xirrValue;

    // CAGR mode: compute from chart history
    // If the currently selected period matches, use cached chart data
    if (_selectedDays == days && _chartPrices.length >= 2) {
      return _computeCagrFromPrices(_chartPrices, years);
    }

    // For periods not currently selected, try to use a separate provider watch.
    // We watch the history for each period needed.
    final historyAsync = ref.watch(
      discoverMfHistoryProvider(
        (schemeCode: item.schemeCode, days: days),
      ),
    );

    double? cagr;
    historyAsync.whenData((history) {
      if (history.points.length >= 2) {
        final prices = history.points.map((p) => p.value).toList();
        cagr = _computeCagrFromPrices(prices, years);
      }
    });
    return cagr;
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
    final modeLabel = _returnMode == _ReturnMode.xirr ? 'XIRR' : 'CAGR';
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
          '$label $modeLabel',
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

  // -- Risk & Performance Card --

  Widget _buildRiskPerformanceCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risk & Performance', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            // Row 1: Sharpe, Sortino, Max Drawdown
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Sharpe',
                    value: item.sharpe?.toStringAsFixed(2) ?? '\u2014',
                    valueColor: _sharpeColor(item.sharpe),
                    tooltip: metricExplanations['sharpe'],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Sortino',
                    value: item.sortino?.toStringAsFixed(2) ?? '\u2014',
                    valueColor: _sharpeColor(item.sortino),
                    tooltip: metricExplanations['sortino'],
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
                    tooltip: metricExplanations['max_drawdown'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Alpha, Beta
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Alpha',
                    value: item.alpha != null
                        ? '${item.alpha!.toStringAsFixed(1)}%'
                        : '\u2014',
                    valueColor: _alphaColor(item.alpha),
                    tooltip: metricExplanations['alpha'],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Beta',
                    value: item.beta?.toStringAsFixed(2) ?? '\u2014',
                    valueColor: _betaColor(item.beta),
                    tooltip: metricExplanations['beta'],
                  ),
                ),
                const Spacer(),
              ],
            ),
            if (item.rollingReturnConsistency != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (item.rollingReturnConsistency! / 100).clamp(0.0, 1.0),
                          strokeWidth: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ScoreBar.scoreColor(item.rollingReturnConsistency!.toDouble()),
                          ),
                        ),
                        Text(
                          '${item.rollingReturnConsistency!.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rolling Return Consistency',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          'How predictable the fund\'s returns have been over time',
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
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
            const SizedBox(height: 12),
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

  // -- What Makes This Fund Stand Out --

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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: AppTheme.accentOrange),
                const SizedBox(width: 8),
                Text(
                  'Why This Fund Stands Out',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...reasons.map((r) {
              final (icon, color, text) = r;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          text,
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
                  // Rank
                  SizedBox(
                    width: 32,
                    child: Text(
                      fund.categoryRank != null
                          ? '#${fund.categoryRank}'
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
}
