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

class MfDetailScreen extends ConsumerStatefulWidget {
  final String schemeCode;
  final DiscoverMutualFundItem? initialItem;
  // Optional display name supplied by deep links (e.g. home-screen
  // widget). When the schemeCode 404s we fall back to searching
  // this name via the screener so stale codes still resolve.
  final String? fallbackName;

  const MfDetailScreen({
    super.key,
    required this.schemeCode,
    this.initialItem,
    this.fallbackName,
  });

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
    (label: '10Y', days: 3650),
    // "All" — backend /mutual-funds/history caps at 20000 days
    // (~55y). After discover_mf_nav_backfill runs with the
    // inception window, funds return their full history here.
    (label: 'All', days: 20000),
  ];

  late DiscoverMutualFundItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Expert mode removed — always show full details

    // Always fetch the full detail payload — the screener list item
    // (passed via initialItem) only carries summary fields, so fields
    // like topHoldings, assetAllocation, and holdingsAsOf are missing
    // unless we hit /detail. initialItem is used purely as a
    // placeholder during the initial load to avoid a shimmer flash.
    final hasFallback = (widget.fallbackName ?? '').trim().isNotEmpty;
    final detailAsync = hasFallback
        ? ref.watch(
            discoverMfDetailWithFallbackProvider(
              (schemeCode: widget.schemeCode, fallbackName: widget.fallbackName),
            ),
          )
        : ref.watch(discoverMfDetailProvider(widget.schemeCode));
    return detailAsync.when(
      loading: () {
        if (widget.initialItem != null) {
          item = widget.initialItem!;
          return _buildContent(theme, item);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Loading...')),
          body: const ShimmerMfDetail(),
        );
      },
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.fallbackName ?? widget.schemeCode),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              const Text('Error loading fund details'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  if (hasFallback) {
                    ref.invalidate(
                      discoverMfDetailWithFallbackProvider(
                        (
                          schemeCode: widget.schemeCode,
                          fallbackName: widget.fallbackName,
                        ),
                      ),
                    );
                  } else {
                    ref.invalidate(
                      discoverMfDetailProvider(widget.schemeCode),
                    );
                  }
                },
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

    // Header badge always shows point-to-point % change over the
    // selected window, computed from the raw NAV history. The Returns
    // card below already surfaces annualized CAGR for 1Y/3Y/5Y, so
    // reusing those API values here would just duplicate that figure
    // and hide the absolute move the chart actually depicts.
    List<double> chartPrices = [];
    List<DateTime> chartTimestamps = [];
    historyAsync.whenData((history) {
      if (history.points.length >= 2) {
        chartPrices = history.points.map((p) => p.value).toList();
        chartTimestamps = history.points.map((p) => p.date).toList();

        // Override last chart point with live NAV for visual display.
        if (chartPrices.isNotEmpty) {
          chartPrices[chartPrices.length - 1] = item.nav;
        }

        // Point-to-point change: match what the chart visually shows
        // (first raw NAV → live NAV at right edge).
        final first = chartPrices.first;
        final last = chartPrices.last;
        if (first > 0) _periodChange = ((last - first) / first) * 100;
      }
    });

    final isPositive = (_periodChange ?? 0) >= 0;
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayName ?? item.schemeName),
        actions: [
          _MfStarButton(
            schemeCode: item.schemeCode,
            displayName: item.displayName ?? item.schemeName,
            returns1y: item.returns1y,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tags (balanced: positive/cautionary/negative)
            if (item.mfTags.isNotEmpty) ...[
              _buildMfTags(theme),
              const SizedBox(height: 8),
            ] else if (item.qualityBadges.isNotEmpty) ...[
              _buildQualityBadges(theme),
              const SizedBox(height: 8),
            ],

            // 2. Header
            _buildHeader(theme),
            const SizedBox(height: 8),

            // 3. NAV Price + Period Change + 1D
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
                      '${isPositive ? "+" : ""}${_periodChange!.toStringAsFixed(2)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            // 1D change (previous trading day → latest NAV). Rendered
            // as a pill badge under the NAV row, matching the period
            // change badge above it.
            if (item.pointToPointReturns?.return1d != null) ...[
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final d = item.pointToPointReturns!.return1d!;
                final up = d >= 0;
                final c = up ? AppTheme.accentGreen : AppTheme.accentRed;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${up ? "+" : ""}${d.toStringAsFixed(2)}%  1D',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            ],
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

            // 5. Returns (with XIRR/CAGR toggle)
            _buildReturnsCard(theme),
            const SizedBox(height: 8),

            // 6. Score Card
            _buildScoreCard(theme),
            const SizedBox(height: 8),

            // 7. Fund Insights (from backend)
            if (item.fundInsights.length >= 2) ...[
              _buildFundInsightsCard(theme),
              const SizedBox(height: 8),
            ],

            // 8. Risk & Performance
            _buildRiskPerformanceCard(theme),
            const SizedBox(height: 8),

            // 9. Fund Ranking
            if ((item.categoryRank != null && item.categoryTotal != null) ||
                (item.subCategoryRank != null &&
                    item.subCategoryTotal != null)) ...[
              _buildCategoryRankCard(theme),
              const SizedBox(height: 8),
            ],

            // 10. Key Metrics
            _buildMetricsCard(theme),
            const SizedBox(height: 8),

            // 11. Peer Comparison
            _buildPeerComparison(theme),
            const SizedBox(height: 8),

            // 12. Asset Allocation
            if (item.assetAllocation != null) ...[
              _buildHoldingsSection(theme),
              const SizedBox(height: 8),
            ],

            // 13. Top Holdings
            if (item.topHoldings != null && item.topHoldings!.isNotEmpty) ...[
              _buildTopHoldingsCard(theme),
              const SizedBox(height: 8),
            ],

            // 14. Fund Manager
            if (item.fundManagers != null && item.fundManagers!.isNotEmpty) ...[
              _buildFundManagerCard(theme),
              const SizedBox(height: 8),
            ],

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

  // -- Balanced Tags (from backend) --

  Widget _buildMfTags(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: item.mfTags.map((mfTag) {
        final color = _sentimentColor(mfTag.sentiment);
        return GestureDetector(
          onTap: mfTag.preset != null
              ? () {
                  context.push('/discover/mf-screener', extra: {
                    'preset': mfTag.preset,
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              mfTag.tag,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static Color _sentimentColor(String sentiment) {
    switch (sentiment) {
      case 'positive':
        return AppTheme.accentGreen;
      case 'cautionary':
        return AppTheme.accentOrange;
      case 'negative':
        return AppTheme.accentRed;
      default:
        return AppTheme.accentGray;
    }
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
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (item.fundClassification != null ||
                item.subCategory != null) ...[
              Flexible(
                child: Text(
                  item.fundClassification ?? item.subCategory ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.category != null) ...[
                Text(
                  ' \u00B7 ',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white38),
                ),
                Text(
                  item.category!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
              const SizedBox(width: 8),
            ] else if (item.category != null) ...[
              Text(
                item.category!,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
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
    final risk = (item.riskLevel ?? '').toLowerCase();
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
        item.riskLevel ?? '',
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
    final isDebt =
        (item.fundType ?? item.category ?? '').toLowerCase() == 'debt';
    final catFit =
        breakdown.categoryFitScore ?? item.scoreCategoryFit?.toDouble();

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

            // Radar chart — 5 dimensions (hide beta for debt)
            if (hasRadarData) ...[
              Center(
                child: SizedBox(
                  height: 180,
                  width: 180,
                  child: RadarChartWidget(
                    dimensions: [
                      RadarDimension(
                          label: 'Performance', value: breakdown.returnScore),
                      RadarDimension(
                          label: 'Consistency',
                          value: breakdown.consistencyScore),
                      RadarDimension(label: 'Risk', value: breakdown.riskScore),
                      RadarDimension(label: 'Cost', value: breakdown.costScore),
                      if (catFit != null)
                        RadarDimension(label: 'Category Fit', value: catFit),
                    ],
                    fillColor: AppTheme.accentBlue,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Row 1: Performance, Consistency, Risk
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Performance',
                      value: breakdown.returnScore.toStringAsFixed(1),
                      valueColor: _scoreColor(breakdown.returnScore),
                      tooltip:
                          'How well the fund performs compared to peers. Based on blended 1Y, 3Y, and 5Y returns ranked within the same category.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Consistency',
                      value: breakdown.consistencyScore.toStringAsFixed(1),
                      valueColor: _scoreColor(breakdown.consistencyScore),
                      tooltip:
                          'How predictable and stable the returns are. Based on Sortino ratio and rolling return consistency — higher means more reliable outcomes.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Risk',
                      value: breakdown.riskScore.toStringAsFixed(1),
                      valueColor: _scoreColor(breakdown.riskScore),
                      tooltip:
                          'How well the fund manages downside risk. Based on maximum drawdown and risk level — higher score means better capital protection.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: Cost, Category Fit (+ Beta for equity)
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Cost',
                      value: breakdown.costScore.toStringAsFixed(1),
                      valueColor: _scoreColor(breakdown.costScore),
                      tooltip:
                          'How cost-efficient the fund is. Lower expense ratio relative to category peers earns a higher score.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (catFit != null)
                    Expanded(
                      child: StatCard(
                        label: 'Category Fit',
                        value: catFit.toStringAsFixed(1),
                        valueColor: _scoreColor(catFit),
                        tooltip:
                            'How well the fund fits its stated mandate. Measures category-specific quality factors like tracking error for index funds or alpha generation for active funds.',
                      ),
                    )
                  else
                    const Spacer(),
                  if (!isDebt && breakdown.betaScore != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        label: 'Beta',
                        value: breakdown.betaScore!.toStringAsFixed(1),
                        valueColor: _scoreColor(breakdown.betaScore!),
                        tooltip:
                            'Market sensitivity score. Higher means the fund is more defensive — it moves less than the market during downturns.',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    const Spacer(),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _scoreColor(double score) {
    if (score >= 70) return AppTheme.accentGreen;
    if (score >= 40) return AppTheme.accentOrange;
    return AppTheme.accentRed;
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
            if (item.subCategoryRank != null &&
                item.subCategoryTotal != null) ...[
              if (item.categoryRank != null) const SizedBox(height: 8),
              _buildRankRow(
                theme,
                rank: item.subCategoryRank!,
                total: item.subCategoryTotal!,
                label: item.fundClassification ??
                    item.subCategory ??
                    item.category ??
                    'Sub-Category',
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
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
            ),
            Text(
              ' in ',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
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
    // Single source of truth for every return figure on this screen:
    // backend-computed, history-anchored values from
    // `point_to_point_returns`. This eliminates the anchor-date drift
    // between the top period badge and this card that previously
    // confused users (ETMoney cached numbers with SEBI-style "last
    // trading day ≤ target" anchors, while the chart endpoint uses
    // "first trading day ≥ target"). ETMoney values on item.returns*
    // remain as a fallback for older backends that don't ship the
    // new field yet, and continue to feed scoring/ranking internally.
    //
    // Sub-1Y cells are absolute %; 1Y/3Y/5Y are CAGR (annualized).
    // For 1Y, CAGR == absolute by construction.
    // Long-term CAGR only — short-period absolute returns are
    // covered by the top period badge (which has its own
    // 1W/1M/3M/6M selector above the chart). Prefer the backend's
    // history-anchored cagr_Xy fields; fall back to the DB columns
    // which hold the same values after recompute_mf_returns_all.
    // cagr10y is null for funds younger than 10 years — the column
    // hides gracefully via the non-null filter below.
    final ptp = item.pointToPointReturns;
    final r1y = ptp?.cagr1y ?? item.returns1y;
    final r3y = ptp?.cagr3y ?? item.returns3y;
    final r5y = ptp?.cagr5y ?? item.returns5y;
    final r10y = ptp?.cagr10y ?? item.returns10y;

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
                for (final entry in [
                  ('1Y', r1y),
                  ('3Y', r3y),
                  ('5Y', r5y),
                  ('10Y', r10y),
                ])
                  if (entry.$2 != null)
                    Expanded(
                      child: _returnColumn(theme, entry.$1, entry.$2),
                    ),
                // If no returns at all, show a placeholder
                if ([r1y, r3y, r5y, r10y].every((v) => v == null))
                  Expanded(
                    child: _returnColumn(theme, '1Y', null),
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
                    if (item.returns1y != null ||
                        item.categoryAvgReturns1y != null)
                      BarGroup(label: '1Y', values: [
                        item.returns1y?.toDouble() ?? 0,
                        item.categoryAvgReturns1y?.toDouble() ?? 0,
                      ], colors: [
                        AppTheme.accentBlue,
                        Colors.white38
                      ]),
                    if (item.returns3y != null ||
                        item.categoryAvgReturns3y != null)
                      BarGroup(label: '3Y', values: [
                        item.returns3y?.toDouble() ?? 0,
                        item.categoryAvgReturns3y?.toDouble() ?? 0,
                      ], colors: [
                        AppTheme.accentBlue,
                        Colors.white38
                      ]),
                    if (item.returns5y != null ||
                        item.categoryAvgReturns5y != null)
                      BarGroup(label: '5Y', values: [
                        item.returns5y?.toDouble() ?? 0,
                        item.categoryAvgReturns5y?.toDouble() ?? 0,
                      ], colors: [
                        AppTheme.accentBlue,
                        Colors.white38
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: AppTheme.accentBlue,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Fund Return',
                      style: TextStyle(fontSize: 10, color: Colors.white54)),
                  const SizedBox(width: 12),
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Category Avg',
                      style: TextStyle(fontSize: 10, color: Colors.white54)),
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
                    tooltip:
                        'Sharpe ratio measures risk-adjusted returns. Higher is better — it shows how much return you earn per unit of total risk taken. Above 1.5 is excellent, below 0.5 is weak.',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Sortino',
                    value: item.sortino?.toStringAsFixed(2) ?? '\u2014',
                    valueColor: _sharpeColor(item.sortino),
                    tooltip:
                        'Sortino ratio is like Sharpe but only considers downside risk (losses). Higher is better. Above 2.0 is excellent — the fund protects well against losses while generating returns.',
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
                    tooltip:
                        'Maximum Drawdown is the largest peak-to-trough decline in the fund\'s history. Lower is better — it shows the worst-case loss you could have experienced.',
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
                    tooltip:
                        'Alpha measures how much the fund outperforms (or underperforms) its benchmark after adjusting for risk. Positive alpha means the fund manager is adding value beyond what the market provides.',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Beta',
                    value: item.beta?.toStringAsFixed(2) ?? '\u2014',
                    valueColor: _betaColor(item.beta),
                    tooltip:
                        'Beta measures the fund\'s sensitivity to market movements. Beta < 1 means the fund is defensive (moves less than the market). Beta > 1 means it\'s aggressive (amplifies market moves).',
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
                    tooltip:
                        'Rolling Return Consistency measures how predictable the fund\'s returns are across different time periods. Lower is better — it means returns are consistent regardless of when you invest.',
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
                if (item.fundAgeYears != null && item.stdDev != null)
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
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: AppTheme.accentOrange),
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
            Row(
              children: [
                Text('Asset Allocation',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (item.holdingsAsOf != null)
                  Text(
                    'As of ${_formatDate(item.holdingsAsOf!)}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.white38),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Asset allocation horizontal bar
            if (item.assetAllocation != null) ...[
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
                    _assetLegend('Equity', item.assetAllocation!.equity,
                        AppTheme.accentBlue, theme),
                  if (item.assetAllocation!.debt > 0)
                    _assetLegend('Debt', item.assetAllocation!.debt,
                        AppTheme.accentTeal, theme),
                  if (item.assetAllocation!.cash > 0)
                    _assetLegend('Cash', item.assetAllocation!.cash,
                        AppTheme.accentOrange, theme),
                  if (item.assetAllocation!.other > 0)
                    _assetLegend('Other', item.assetAllocation!.other,
                        AppTheme.accentGray, theme),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -- Top Holdings Card --

  Widget _buildTopHoldingsCard(ThemeData theme) {
    final holdings = item.topHoldings!.take(10).toList();
    final maxPct = holdings
        .map((h) => h.percentage)
        .fold<double>(0, (a, b) => b > a ? b : a);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Top Holdings',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (item.holdingsAsOf != null)
                  Text(
                    'As of ${_formatDate(item.holdingsAsOf!)}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.white38),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...holdings.map((h) {
              final frac = maxPct > 0 ? (h.percentage / maxPct) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${h.percentage.toStringAsFixed(2)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ],
                    ),
                    if (h.sector != null && h.sector!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        h.sector!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white54),
                      ),
                    ],
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.accentBlue),
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

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
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

  // -- Fund Manager Card --

  Widget _buildFundManagerCard(ThemeData theme) {
    final managers = item.fundManagers!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fund Manager', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...managers.take(2).map((fm) {
              final name = fm['name'] as String? ?? '';
              final experience = fm['experience'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppTheme.accentBlue.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: AppTheme.accentBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (experience.isNotEmpty)
                            Text(
                              experience,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                        ],
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

        Widget buildRow(DiscoverMutualFundItem fund, {bool isCurrent = false}) {
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
                color: isCurrent ? Colors.white.withValues(alpha: 0.05) : null,
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
                          flex: 3, child: Text('Fund', style: headerStyle)),
                      SizedBox(
                          width: 42,
                          child: Text('Score',
                              style: headerStyle, textAlign: TextAlign.center)),
                      SizedBox(
                          width: 54,
                          child: Text('1Y Return',
                              style: headerStyle, textAlign: TextAlign.right)),
                      SizedBox(
                          width: 48,
                          child: Text('Expense',
                              style: headerStyle, textAlign: TextAlign.right)),
                      SizedBox(
                          width: 32,
                          child: Text('Rank',
                              style: headerStyle, textAlign: TextAlign.right)),
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

class _MfStarButton extends ConsumerWidget {
  final String schemeCode;
  final String displayName;
  final double? returns1y;

  const _MfStarButton({
    required this.schemeCode,
    required this.displayName,
    this.returns1y,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starred = ref.watch(starredStocksProvider);
    final isStarred = starred.any((e) => e.type == 'mf' && e.id == schemeCode);

    return IconButton(
      icon: Icon(
        isStarred ? Icons.star_rounded : Icons.star_border_rounded,
        color: isStarred ? AppTheme.accentOrange : Colors.white54,
      ),
      tooltip: isStarred ? 'Remove from watchlist' : 'Add to watchlist',
      onPressed: () {
        ref.read(starredStocksProvider.notifier).toggle(
              type: 'mf',
              id: schemeCode,
              name: displayName,
              percentChange: returns1y,
            );
      },
    );
  }
}
