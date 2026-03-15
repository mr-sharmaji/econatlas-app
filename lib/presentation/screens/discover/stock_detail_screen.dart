import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/score_bar.dart';
import 'widgets/metric_grid.dart';
import 'widgets/position_bar.dart';
import 'widgets/radar_chart_widget.dart';
import 'widgets/stat_card.dart';
import 'widgets/tag_utils.dart';
import 'widgets/metric_glossary.dart';
import 'widgets/donut_chart_widget.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final String symbol;
  final DiscoverStockItem? initialItem;
  final int initialDays;

  const StockDetailScreen({
    super.key,
    required this.symbol,
    this.initialItem,
    this.initialDays = 90,
  });

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen>
    with SingleTickerProviderStateMixin {
  late int _selectedDays = widget.initialDays;
  double? _periodChange;
  late final TabController _tabController;
  int _tabIndex = 0;

  static const _periods = [
    (label: '1W', days: 7),
    (label: '1M', days: 30),
    (label: '3M', days: 90),
    (label: '6M', days: 180),
    (label: '1Y', days: 365),
    (label: '3Y', days: 1095),
    (label: '5Y', days: 1825),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Backend return values ─────────────────────────────────────
  double? _getBackendReturn(DiscoverStockItem item) {
    switch (_selectedDays) {
      case 7:
        return item.percentChange1w;
      case 90:
        return item.percentChange3m;
      case 365:
        return item.percentChange1y;
      case 1095:
        return item.percentChange3y;
      default:
        return null;
    }
  }

  // ── Format helpers ────────────────────────────────────────────
  static String _formatLargeNumber(double? value) {
    if (value == null) return '\u2014';
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    if (abs >= 1e7) {
      final crores = abs / 1e7;
      if (crores >= 1e5) {
        return '$sign\u20B9${(crores / 1e5).toStringAsFixed(2)} L Cr';
      }
      return '$sign\u20B9${Formatters.price(crores)} Cr';
    }
    if (abs >= 1e5) {
      return '$sign\u20B9${(abs / 1e5).toStringAsFixed(2)} L';
    }
    return '$sign\u20B9${Formatters.fullPrice(value)}';
  }

  static String _pct(double? value) {
    if (value == null) return '\u2014';
    return '${value.toStringAsFixed(1)}%';
  }

  static String _ratio(double? value, {int decimals = 2}) {
    if (value == null) return '\u2014';
    return value.toStringAsFixed(decimals);
  }

  static Color _changeColor(double? value) {
    if (value == null) return Colors.white38;
    return value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.initialItem != null) {
      return _buildContent(theme, widget.initialItem!);
    }

    final detailAsync = ref.watch(discoverStockDetailProvider(widget.symbol));
    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.symbol)),
        body: const ShimmerStockDetail(),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: Text(widget.symbol)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              const Text('Error loading stock details'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(discoverStockDetailProvider(widget.symbol)),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (item) => _buildContent(theme, item),
    );
  }

  Widget _buildContent(ThemeData theme, DiscoverStockItem item) {
    final historyAsync = ref.watch(
      discoverStockHistoryProvider((symbol: item.symbol, days: _selectedDays)),
    );

    List<double> chartPrices = [];
    List<DateTime> chartTimestamps = [];
    historyAsync.whenData((history) {
      if (history.points.length >= 2) {
        chartPrices = history.points.map((p) => p.value).toList();
        chartTimestamps = history.points.map((p) => p.date).toList();
        final first = chartPrices.first;
        final last = chartPrices.last;
        if (first > 0) _periodChange = ((last - first) / first) * 100;
        if (chartPrices.isNotEmpty) {
          chartPrices[chartPrices.length - 1] = item.lastPrice;
        }
      }
    });

    // Prefer backend return over chart-computed value
    final backendReturn = _getBackendReturn(item);
    final displayChange = backendReturn ?? _periodChange ?? item.percentChange;
    final isPositive = (displayChange ?? 0) >= 0;
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    return Scaffold(
      appBar: AppBar(title: Text(item.symbol)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Quality Verdict Banner ──
            _buildQualityBanner(theme, item),
            const SizedBox(height: 14),

            // ── Header ──
            Text(
              item.displayName,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  item.symbol,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
                if (item.sector != null && item.sector != 'Other') ...[
                  const SizedBox(width: 8),
                  _buildChipLabel(theme, item.sector!),
                ],
                if (item.industry != null) ...[
                  const SizedBox(width: 6),
                  Flexible(child: _buildChipLabel(theme, item.industry!)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'NSE \u00B7 Mkt Cap: ${_formatLargeNumber(item.marketCap != null ? item.marketCap! * 1e7 : null)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 12),

            // ── Price + Change Badge ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Formatters.fullPrice(item.lastPrice),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                if (displayChange != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${isPositive ? "+" : ""}${displayChange.toStringAsFixed(2)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Period Selector ──
            _buildPeriodSelector(theme),
            const SizedBox(height: 10),

            // ── Price Chart ──
            historyAsync.when(
              data: (history) {
                if (history.points.isEmpty) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: Text('No chart data')),
                  );
                }
                return PriceLineChart(
                  key: ValueKey('chart_$_selectedDays'),
                  prices: chartPrices,
                  timestamps: chartTimestamps,
                  isShortRange: _selectedDays <= 90,
                  pricePrefix: '\u20B9 ',
                );
              },
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(
                height: 180,
                child: Center(child: Text('Failed to load chart')),
              ),
            ),
            const SizedBox(height: 20),

            // ── 52-Week Range (outside tabs) ──
            if (item.high52w != null && item.low52w != null) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '52-Week Range',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      PositionBar(
                        min: item.low52w!,
                        max: item.high52w!,
                        current: item.lastPrice,
                        minLabel:
                            '\u20B9${Formatters.price(item.low52w!)}',
                        maxLabel:
                            '\u20B9${Formatters.price(item.high52w!)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Score Card ──
            _buildScoreCard(theme, item),
            const SizedBox(height: 14),

            // ── TabBar ──
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: theme.textTheme.labelMedium,
                tabs: const [
                  Tab(text: 'Insights'),
                  Tab(text: 'Financials'),
                  Tab(text: 'Ownership'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Tab Content (indexed, no TabBarView) ──
            _buildTabContent(theme, item),
            const SizedBox(height: 14),

            // ── Peer Comparison (always visible) ──
            _buildPeerComparison(theme, item),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Small chip label ──────────────────────────────────────────

  Widget _buildChipLabel(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Quality Verdict Banner ────────────────────────────────────

  Widget _buildQualityBanner(ThemeData theme, DiscoverStockItem item) {
    final tier = item.qualityTier?.toLowerCase() ?? '';
    final score = item.score;

    final Color bgColor;
    final String tierLabel;
    final String explanation;
    final IconData icon;

    if (score >= 80 || tier == 'strong') {
      bgColor = AppTheme.accentGreen;
      tierLabel = 'Strong';
      explanation = 'This stock has strong fundamentals across all metrics';
      icon = Icons.verified_rounded;
    } else if (score >= 60 || tier == 'good') {
      bgColor = AppTheme.accentBlue;
      tierLabel = 'Good';
      explanation = 'This stock shows good fundamentals with minor gaps';
      icon = Icons.thumb_up_alt_rounded;
    } else if (score >= 40 || tier == 'average') {
      bgColor = AppTheme.accentOrange;
      tierLabel = 'Average';
      explanation = 'This stock has mixed fundamentals worth monitoring';
      icon = Icons.info_outline_rounded;
    } else {
      bgColor = AppTheme.accentRed;
      tierLabel = 'Weak';
      explanation = 'This stock has weak fundamentals and higher risk';
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: bgColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tierLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: bgColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      explanation,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Action tag + Lynch classification
          if (item.actionTag != null || item.lynchClassification != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.actionTag != null)
                  Tooltip(
                    message: item.actionTagReasoning ?? '',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.accentTeal.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt,
                              size: 14, color: AppTheme.accentTeal),
                          const SizedBox(width: 4),
                          Text(
                            item.actionTag!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.accentTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (item.lynchClassification != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      item.lynchClassification!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Period Selector Pills ─────────────────────────────────────

  Widget _buildPeriodSelector(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map((p) {
          final isSelected = p.days == _selectedDays;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(p.label),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedDays = p.days),
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

  // ── Score Card ─────────────────────────────────────────────────

  Widget _buildScoreCard(ThemeData theme, DiscoverStockItem item) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score header (kept as-is)
            Row(
              children: [
                Text(
                  'Score',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Text(
                  ScoreBar.formatMinified(item.score),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ScoreBar.scoreColor(item.score),
                  ),
                ),
                const SizedBox(width: 8),
                // Data quality badge
                if (item.scoreBreakdown.dataQuality != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.scoreBreakdown.dataQuality == 'full'
                          ? Colors.green.withValues(alpha: 0.15)
                          : item.scoreBreakdown.dataQuality == 'partial'
                              ? Colors.orange.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.scoreBreakdown.dataQuality == 'full'
                          ? 'High Confidence'
                          : item.scoreBreakdown.dataQuality == 'partial'
                              ? 'Medium'
                              : 'Low',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: item.scoreBreakdown.dataQuality == 'full'
                            ? Colors.green
                            : item.scoreBreakdown.dataQuality == 'partial'
                                ? Colors.orange
                                : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            // Score trend badge
            if (item.previousScore != null) ...[
              const SizedBox(height: 4),
              Text(
                item.score > item.previousScore!
                    ? '\u2191 from ${item.previousScore!.toStringAsFixed(0)} last week'
                    : item.score < item.previousScore!
                        ? '\u2193 from ${item.previousScore!.toStringAsFixed(0)} last week'
                        : 'unchanged from last week',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: item.score > item.previousScore!
                      ? Colors.green
                      : item.score < item.previousScore!
                          ? Colors.red
                          : Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // 6-layer radar or fallback breakdown
            if (item.scoreBreakdown.has6LayerScores) ...[
              _build6LayerRadar(theme, item),
            ] else ...[
              // Fallback: legacy ScoreBreakdownBar
              ScoreBreakdownBar(segments: _buildLegacySegments(item)),
            ],
          ],
        ),
      ),
    );
  }

  /// Build 6-layer radar chart + stat cards grid.
  Widget _build6LayerRadar(ThemeData theme, DiscoverStockItem item) {
    final sb = item.scoreBreakdown;
    final dimensions = [
      RadarDimension(label: 'Financial Health', value: sb.quality ?? 0),
      RadarDimension(label: 'Valuation', value: sb.valuation ?? 0),
      RadarDimension(label: 'Growth', value: sb.growth),
      RadarDimension(label: 'Momentum', value: sb.momentum),
      RadarDimension(label: 'Smart Money', value: sb.institutional ?? 0),
      RadarDimension(label: 'Risk Shield', value: sb.risk ?? 0),
    ];

    final statEntries = [
      _RadarStat('Financial Health', sb.quality ?? 0, AppTheme.accentGreen),
      _RadarStat('Valuation', sb.valuation ?? 0, AppTheme.accentOrange),
      _RadarStat('Growth', sb.growth, AppTheme.accentTeal),
      _RadarStat('Momentum', sb.momentum, AppTheme.accentBlue),
      _RadarStat('Smart Money', sb.institutional ?? 0, const Color(0xFF7986CB)),
      _RadarStat('Risk Shield', sb.risk ?? 0, const Color(0xFFAB47BC)),
    ];

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: RadarChartWidget(dimensions: dimensions),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.3,
          children: statEntries
              .map((e) => StatCard(
                    label: e.label,
                    value: e.value.toStringAsFixed(0),
                    valueColor: ScoreBar.scoreColor(e.value),
                  ))
              .toList(),
        ),
      ],
    );
  }

  /// Legacy 5-segment fallback.
  List<ScoreSegment> _buildLegacySegments(DiscoverStockItem item) {
    final segments = <ScoreSegment>[
      ScoreSegment(
          label: 'Momentum',
          value: item.scoreMomentum,
          color: AppTheme.accentBlue),
      ScoreSegment(
          label: 'Liquidity',
          value: item.scoreLiquidity,
          color: AppTheme.accentTeal),
      ScoreSegment(
          label: 'Fundamentals',
          value: item.scoreFundamentals,
          color: AppTheme.accentOrange),
      ScoreSegment(
          label: 'Volatility',
          value: item.scoreVolatility,
          color: const Color(0xFFAB47BC)),
      ScoreSegment(
          label: 'Growth',
          value: item.scoreGrowth,
          color: const Color(0xFF26C6DA)),
    ];

    if (item.scoreFinancialHealth != null) {
      segments.add(ScoreSegment(
          label: 'Financial Health',
          value: item.scoreFinancialHealth!,
          color: Colors.green));
    }
    if (item.scoreOwnership != null) {
      segments.add(ScoreSegment(
          label: 'Ownership',
          value: item.scoreOwnership!,
          color: Colors.purple));
    }
    if (item.scoreValuation != null) {
      segments.add(ScoreSegment(
          label: 'Valuation',
          value: item.scoreValuation!,
          color: const Color(0xFFFFB74D)));
    }
    if (item.scoreEarningsQuality != null) {
      segments.add(ScoreSegment(
          label: 'Earnings Quality',
          value: item.scoreEarningsQuality!,
          color: const Color(0xFF4DB6AC)));
    }
    if (item.scoreSmartMoney != null) {
      segments.add(ScoreSegment(
          label: 'Smart Money',
          value: item.scoreSmartMoney!,
          color: const Color(0xFF7986CB)));
    }

    return segments;
  }

  // ── Tab Content ───────────────────────────────────────────────

  Widget _buildTabContent(ThemeData theme, DiscoverStockItem item) {
    switch (_tabIndex) {
      case 0:
        return _buildInsightsTab(theme, item);
      case 1:
        return _buildFinancialsTab(theme, item);
      case 2:
        return _buildOwnershipTab(theme, item);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── INSIGHTS TAB (was Overview) ─────────────────────────────

  Widget _buildInsightsTab(ThemeData theme, DiscoverStockItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Why Ranked (promoted to top with lightbulb icon)
        if (item.scoreBreakdown.whyNarrative != null ||
            item.whyRanked.isNotEmpty) ...[
          Card(
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
                  if (item.scoreBreakdown.whyNarrative != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.scoreBreakdown.whyNarrative!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
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
          ),
          const SizedBox(height: 14),
        ],

        // Tags (using tag_utils)
        if (item.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: item.tags.map((tag) {
              final td = getTagDisplay(tag);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: td.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: td.color.withValues(alpha: 0.3)),
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
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],

        // Key Metrics — 2x2 StatCard grid (P/E, ROE, D/E, Market Cap)
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Metrics',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: [
                    StatCard(
                      label: 'P/E Ratio',
                      value: _ratio(item.peRatio, decimals: 1),
                      valueColor: _peColor(item.peRatio),
                      tooltip: metricExplanations['pe_ratio'],
                    ),
                    StatCard(
                      label: 'ROE',
                      value: _pct(item.roe),
                      valueColor: _roeColor(item.roe),
                      tooltip: metricExplanations['roe'],
                    ),
                    StatCard(
                      label: 'D/E Ratio',
                      value: _ratio(item.debtToEquity),
                      valueColor: _deColor(item.debtToEquity),
                      tooltip: metricExplanations['debt_to_equity'],
                    ),
                    StatCard(
                      label: 'Market Cap',
                      value: item.marketCap != null
                          ? '\u20B9${Formatters.price(item.marketCap!)} Cr'
                          : '\u2014',
                      tooltip: metricExplanations['market_cap'],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── FINANCIALS TAB (was Fundamentals) ───────────────────────

  Widget _buildFinancialsTab(ThemeData theme, DiscoverStockItem item) {
    // FCF Yield = freeCashFlow / (marketCap * 1e7) * 100  (marketCap is in Cr)
    double? fcfYield;
    if (item.freeCashFlow != null &&
        item.marketCap != null &&
        item.marketCap! > 0) {
      fcfYield = (item.freeCashFlow! / (item.marketCap! * 1e7)) * 100;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profitability
        _buildMetricSection(theme, 'Profitability', [
          MetricItem(
            label: 'Gross Margin',
            value: _marginPct(item.grossMargins),
            valueColor: item.grossMargins == null ? Colors.white38 : null,
          ),
          MetricItem(
            label: 'Operating Margin',
            value: _marginPct(item.operatingMargins),
            valueColor: item.operatingMargins == null ? Colors.white38 : null,
          ),
          MetricItem(
            label: 'Profit Margin',
            value: _marginPct(item.profitMargins),
            valueColor: _marginColor(item.profitMargins),
          ),
          MetricItem(
            label: 'FCF Yield',
            value: fcfYield != null
                ? '${fcfYield.toStringAsFixed(1)}%'
                : '\u2014',
            valueColor: fcfYield == null
                ? Colors.white38
                : (fcfYield > 5 ? AppTheme.accentGreen : null),
          ),
        ]),
        const SizedBox(height: 14),

        // Growth
        _buildMetricSection(theme, 'Growth', [
          MetricItem(
            label: 'Revenue Growth',
            value: _marginPct(item.revenueGrowth),
            valueColor: _changeColor(item.revenueGrowth),
          ),
          MetricItem(
            label: 'Earnings Growth',
            value: _marginPct(item.earningsGrowth),
            valueColor: _changeColor(item.earningsGrowth),
          ),
        ]),
        const SizedBox(height: 14),

        // Growth metrics (StatCards)
        if (item.salesGrowthYoy != null ||
            item.profitGrowthYoy != null ||
            item.compoundedSalesGrowth3y != null ||
            item.compoundedProfitGrowth3y != null) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growth Metrics',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                    children: [
                      if (item.salesGrowthYoy != null)
                        StatCard(
                          label: 'Sales Growth (YoY)',
                          value: _pct(item.salesGrowthYoy),
                          valueColor: _changeColor(item.salesGrowthYoy),
                        ),
                      if (item.profitGrowthYoy != null)
                        StatCard(
                          label: 'Profit Growth (YoY)',
                          value: _pct(item.profitGrowthYoy),
                          valueColor: _changeColor(item.profitGrowthYoy),
                        ),
                      if (item.compoundedSalesGrowth3y != null)
                        StatCard(
                          label: 'Sales CAGR (3Y)',
                          value: _pct(item.compoundedSalesGrowth3y),
                          valueColor:
                              _changeColor(item.compoundedSalesGrowth3y),
                        ),
                      if (item.compoundedProfitGrowth3y != null)
                        StatCard(
                          label: 'Profit CAGR (3Y)',
                          value: _pct(item.compoundedProfitGrowth3y),
                          valueColor:
                              _changeColor(item.compoundedProfitGrowth3y),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Cash Flow Breakdown (StatCards)
        if (item.cashFromOperations != null ||
            item.cashFromInvesting != null ||
            item.cashFromFinancing != null) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash Flow Breakdown',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                    children: [
                      if (item.cashFromOperations != null)
                        StatCard(
                          label: 'Operations',
                          value:
                              _formatLargeNumber(item.cashFromOperations),
                          valueColor:
                              _changeColor(item.cashFromOperations),
                        ),
                      if (item.cashFromInvesting != null)
                        StatCard(
                          label: 'Investing',
                          value:
                              _formatLargeNumber(item.cashFromInvesting),
                          valueColor:
                              _changeColor(item.cashFromInvesting),
                        ),
                      if (item.cashFromFinancing != null)
                        StatCard(
                          label: 'Financing',
                          value:
                              _formatLargeNumber(item.cashFromFinancing),
                          valueColor:
                              _changeColor(item.cashFromFinancing),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Valuation
        _buildMetricSection(theme, 'Valuation', [
          MetricItem(
            label: 'Forward P/E',
            value: _ratio(item.forwardPe, decimals: 1),
            valueColor: _peColor(item.forwardPe),
          ),
          MetricItem(
            label: 'Trailing P/E',
            value: _ratio(item.peRatio, decimals: 1),
            valueColor: _peColor(item.peRatio),
          ),
          MetricItem(
            label: 'Price to Book',
            value: _ratio(item.priceToBook),
            valueColor: item.priceToBook == null ? Colors.white38 : null,
          ),
        ]),
        const SizedBox(height: 14),

        // Balance Sheet
        _buildMetricSection(theme, 'Balance Sheet', [
          MetricItem(
            label: 'Total Debt',
            value: _formatLargeNumber(item.totalDebt),
            valueColor: item.totalDebt == null ? Colors.white38 : null,
          ),
          MetricItem(
            label: 'Total Cash',
            value: _formatLargeNumber(item.totalCash),
            valueColor: item.totalCash == null ? Colors.white38 : null,
          ),
          MetricItem(
            label: 'Debt to Equity',
            value: _ratio(item.debtToEquity),
            valueColor: _deColor(item.debtToEquity),
          ),
          MetricItem(
            label: 'Payout Ratio',
            value: _marginPct(item.payoutRatio),
            valueColor: item.payoutRatio == null ? Colors.white38 : null,
          ),
        ]),
      ],
    );
  }

  // ── OWNERSHIP TAB ─────────────────────────────────────────────

  Widget _buildOwnershipTab(ThemeData theme, DiscoverStockItem item) {
    final hasData = item.promoterHolding != null ||
        item.fiiHolding != null ||
        item.diiHolding != null ||
        item.governmentHolding != null ||
        item.publicHolding != null;

    if (!hasData) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.pie_chart_outline,
                    size: 40, color: Colors.white24),
                const SizedBox(height: 12),
                Text(
                  'No ownership data available',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final holdings = <_HoldingEntry>[
      if (item.promoterHolding != null)
        _HoldingEntry('Promoters', item.promoterHolding!, const Color(0xFF448AFF),
            item.promoterHoldingChange),
      if (item.fiiHolding != null)
        _HoldingEntry('FII', item.fiiHolding!, const Color(0xFF64FFDA),
            item.fiiHoldingChange),
      if (item.diiHolding != null)
        _HoldingEntry('DII', item.diiHolding!, const Color(0xFFFFAB40),
            item.diiHoldingChange),
      if (item.governmentHolding != null)
        _HoldingEntry('Government', item.governmentHolding!,
            const Color(0xFFAB47BC), null),
      if (item.publicHolding != null)
        _HoldingEntry(
            'Public', item.publicHolding!, const Color(0xFF78909C), null),
    ];

    // Build donut segments
    final donutSegments = <DonutSegment>[
      if (item.promoterHolding != null)
        DonutSegment(
            label: 'Promoter',
            value: item.promoterHolding!,
            color: const Color(0xFF448AFF)),
      if (item.fiiHolding != null)
        DonutSegment(
            label: 'FII',
            value: item.fiiHolding!,
            color: const Color(0xFF64FFDA)),
      if (item.diiHolding != null)
        DonutSegment(
            label: 'DII',
            value: item.diiHolding!,
            color: const Color(0xFFFFAB40)),
      if (item.governmentHolding != null)
        DonutSegment(
            label: 'Govt',
            value: item.governmentHolding!,
            color: const Color(0xFFAB47BC)),
      if (item.publicHolding != null)
        DonutSegment(
            label: 'Public',
            value: item.publicHolding!,
            color: const Color(0xFF78909C)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Donut chart
        if (donutSegments.isNotEmpty) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shareholding Pattern',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  DonutChartWidget(segments: donutSegments),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Shareholding bars
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Holding Details',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ...holdings.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(h.label,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70)),
                              Text('${h.value.toStringAsFixed(1)}%',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (h.value / 100).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation(h.color),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        // Pledged shares warning
        if (item.pledgedPromoterPct != null &&
            item.pledgedPromoterPct! > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: item.pledgedPromoterPct! > 20
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.pledgedPromoterPct! > 20
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: item.pledgedPromoterPct! > 20
                      ? Colors.red
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Promoter Pledge: ${item.pledgedPromoterPct!.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.pledgedPromoterPct! > 20
                        ? Colors.red
                        : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        // QoQ Changes
        if (item.promoterHoldingChange != null ||
            item.fiiHoldingChange != null ||
            item.diiHoldingChange != null) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QoQ Changes',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (item.promoterHoldingChange != null)
                    _buildChangeRow(
                        theme, 'Promoters', item.promoterHoldingChange!),
                  if (item.fiiHoldingChange != null)
                    _buildChangeRow(theme, 'FII', item.fiiHoldingChange!),
                  if (item.diiHoldingChange != null)
                    _buildChangeRow(theme, 'DII', item.diiHoldingChange!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Number of shareholders
        if (item.numShareholders != null)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Number of Shareholders',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white54)),
                  Text(
                    Formatters.compactNumber(
                        item.numShareholders!.toDouble()),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChangeRow(ThemeData theme, String label, double change) {
    final isPos = change >= 0;
    final color = isPos ? AppTheme.accentGreen : AppTheme.accentRed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPos ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                '${isPos ? "+" : ""}${change.toStringAsFixed(2)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Metric Section Helper ─────────────────────────────────────

  Widget _buildMetricSection(
      ThemeData theme, String title, List<MetricItem> items) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            MetricGrid(items: items),
          ],
        ),
      ),
    );
  }

  // ── Peer Comparison ───────────────────────────────────────────

  Widget _buildPeerComparison(ThemeData theme, DiscoverStockItem item) {
    final peersAsync = ref.watch(discoverStockPeersProvider(item.symbol));

    return peersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (peers) {
        if (peers.isEmpty) return const SizedBox.shrink();

        final bodyStyle = theme.textTheme.bodySmall;
        final labelStyle =
            theme.textTheme.labelSmall?.copyWith(color: Colors.white38);

        Widget buildPeerTile(DiscoverStockItem peer) {
          final pctChange = peer.percentChange;
          final peerChangeColor = pctChange != null
              ? (pctChange >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
              : Colors.white38;

          return InkWell(
            onTap: () => context.push(
              '/discover/stock/${Uri.encodeComponent(peer.symbol)}',
              extra: peer,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          peer.displayName,
                          style: bodyStyle?.copyWith(
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ScoreBar.scoreColor(peer.score)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ScoreBar.formatMinified(peer.score),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ScoreBar.scoreColor(peer.score),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(Formatters.fullPrice(peer.lastPrice),
                          style: bodyStyle),
                      const SizedBox(width: 12),
                      if (peer.roe != null) ...[
                        Text('ROE ', style: labelStyle),
                        Text(
                          '${peer.roe!.toStringAsFixed(1)}%',
                          style: bodyStyle?.copyWith(
                              color: _roeColor(peer.roe)),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (peer.peRatio != null) ...[
                        Text('P/E ', style: labelStyle),
                        Text(peer.peRatio!.toStringAsFixed(1),
                            style: bodyStyle),
                      ],
                      const Spacer(),
                      Text(
                        pctChange != null
                            ? '${pctChange >= 0 ? "+" : ""}${pctChange.toStringAsFixed(1)}%'
                            : '\u2014',
                        style: bodyStyle?.copyWith(
                          color: peerChangeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                  'Peers in ${item.sector ?? "Sector"}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...peers.map(buildPeerTile),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Color Helpers ─────────────────────────────────────────────

  static Color? _peColor(double? pe) {
    if (pe == null) return Colors.white38;
    if (pe < 25) return AppTheme.accentGreen;
    if (pe > 40) return AppTheme.accentRed;
    return null;
  }

  static Color? _roeColor(double? roe) {
    if (roe == null) return Colors.white38;
    if (roe > 15) return AppTheme.accentGreen;
    if (roe < 10) return AppTheme.accentRed;
    return null;
  }

  static Color? _deColor(double? de) {
    if (de == null) return Colors.white38;
    if (de < 0.5) return AppTheme.accentGreen;
    if (de > 1.0) return AppTheme.accentRed;
    return null;
  }

  static Color? _marginColor(double? margin) {
    if (margin == null) return Colors.white38;
    if (margin > 0.15) return AppTheme.accentGreen;
    if (margin < 0.05) return AppTheme.accentRed;
    return null;
  }

  /// Margins from Yahoo come as decimals (0.25 = 25%). Format as percentage.
  static String _marginPct(double? value) {
    if (value == null) return '\u2014';
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}

// ── Private data holders ─────────────────────────────────────────

class _HoldingEntry {
  final String label;
  final double value;
  final Color color;
  final double? change;

  const _HoldingEntry(this.label, this.value, this.color, this.change);
}

class _RadarStat {
  final String label;
  final double value;
  final Color color;

  const _RadarStat(this.label, this.value, this.color);
}
