import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/shimmer_loading.dart';
import '../../providers/settings_providers.dart';
import 'widgets/score_bar.dart';
import 'widgets/score_fingerprint.dart';
import 'widgets/position_bar.dart';
import 'widgets/radar_chart_widget.dart';
import 'widgets/stat_card.dart';
import 'widgets/tag_utils.dart';
import 'widgets/metric_glossary.dart';
import 'widgets/donut_chart_widget.dart';
import 'widgets/grouped_bar_chart_widget.dart';

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
    // Watch expert mode to trigger rebuild when toggled
    ref.watch(expertModeProvider);
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
            // ── Action Verdict Banner ──
            _buildTopVerdictCard(theme, item),
            const SizedBox(height: 8),

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
            const SizedBox(height: 16),

            // ── Period Selector ──
            _buildPeriodSelector(theme),
            const SizedBox(height: 8),

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
            const SizedBox(height: 12),

            // ── 52-Week Range (outside tabs) ──
            if (item.high52w != null && item.low52w != null) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '52-Week Range',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      PositionBar(
                        min: item.low52w!,
                        max: item.high52w!,
                        current: item.lastPrice,
                        minLabel:
                            '\u20B9${Formatters.price(item.low52w!)}',
                        maxLabel:
                            '\u20B9${Formatters.price(item.high52w!)}',
                      ),
                      Builder(builder: (context) {
                        final range = item.high52w! - item.low52w!;
                        if (range <= 0) return const SizedBox.shrink();
                        final pct = (item.lastPrice - item.low52w!) / range;
                        if (pct >= 0.95) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Near 52W High', style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                          );
                        } else if (pct <= 0.05) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Near 52W Low', style: TextStyle(color: AppTheme.accentRed, fontSize: 11, fontWeight: FontWeight.w600)),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Score Card ──
            _buildScoreCard(theme, item),
            const SizedBox(height: 8),

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
            const SizedBox(height: 8),

            // ── Tab Content (indexed, no TabBarView) ──
            _buildTabContent(theme, item),
            const SizedBox(height: 8),

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

  // ── Top-level Action Verdict Card ─────────────────────────────

  Widget _buildTopVerdictCard(ThemeData theme, DiscoverStockItem item) {
    final storyAsync = ref.watch(discoverStockStoryProvider(item.symbol));
    return storyAsync.when(
      loading: () => _buildVerdictShimmer(),
      error: (_, __) => _buildVerdictFromItem(theme, item),
      data: (story) => _buildVerdictFromStory(theme, item, story),
    );
  }

  // ── Action Tag Helpers ──────────────────────────────────────────

  static Color _actionTagColor(String tag) {
    switch (tag) {
      case 'Strong Outperformer':
        return AppTheme.accentGreen;
      case 'Outperformer':
      case 'Accumulate':
        return AppTheme.accentTeal;
      case 'Watchlist':
      case 'Hold':
      case 'Hold — Low Data':
      case 'Neutral':
        return AppTheme.accentOrange;
      case 'Momentum Only':
        return AppTheme.accentBlue;
      case 'Deteriorating':
      case 'Underperformer':
      case 'Avoid':
        return AppTheme.accentRed;
      default:
        return AppTheme.accentTeal;
    }
  }

  static IconData _actionTagIcon(String tag) {
    switch (tag) {
      case 'Strong Outperformer':
        return Icons.rocket_launch_rounded;
      case 'Outperformer':
        return Icons.trending_up_rounded;
      case 'Accumulate':
        return Icons.add_circle_outline_rounded;
      case 'Watchlist':
        return Icons.visibility_rounded;
      case 'Hold':
      case 'Hold — Low Data':
      case 'Neutral':
        return Icons.pause_circle_outline_rounded;
      case 'Momentum Only':
        return Icons.speed_rounded;
      case 'Deteriorating':
      case 'Underperformer':
        return Icons.trending_down_rounded;
      case 'Avoid':
        return Icons.block_rounded;
      default:
        return Icons.bolt;
    }
  }

  static String _formatActionTag(String tag) {
    return tag
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
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
        padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 8),

            // 6-layer radar or fallback breakdown
            if (item.scoreBreakdown.has6LayerScores) ...[
              if (ref.read(expertModeProvider))
                _build6LayerRadar(theme, item)
              else
                // Compact: just show score fingerprint + tier text
                _buildCompactScoreSection(theme, item),
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
          height: 180,
          child: RadarChartWidget(dimensions: dimensions),
        ),
        const SizedBox(height: 8),
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
        // Why Ranked
        if (item.whyRanked.isNotEmpty) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
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
          ),
          const SizedBox(height: 8),
        ],

        // Tags grouped by category (filter DMA trend — shown in verdict card)
        if (item.tags.isNotEmpty) ...[
          _buildGroupedTags(theme, item.tags
              .where((t) => t.tag != 'Bullish Trend' && t.tag != 'Bearish Trend')
              .toList()),
          const SizedBox(height: 8),
        ],

        // Key Metrics — 2x2 StatCard grid (P/E, ROE, D/E, Market Cap)
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Highlights',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: [
                    StatCard(
                      label: item.sectorPercentile != null
                          ? 'P/E Ratio (${item.sectorPercentile!.toStringAsFixed(0)}th %ile)'
                          : 'P/E Ratio',
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

  // ── Action Verdict Helpers ──────────────────────────────────

  Widget _buildVerdictShimmer() {
    return const ShimmerCard(height: 120);
  }

  /// Fallback when Story endpoint fails — uses data already on the item model.
  Widget _buildVerdictFromItem(ThemeData theme, DiscoverStockItem item) {
    final actionTag = item.actionTag;
    final narrative = item.scoreBreakdown.whyNarrative;
    if (actionTag == null && narrative == null) return const SizedBox.shrink();

    final color = actionTag != null
        ? _actionTagColor(actionTag)
        : Colors.white54;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (actionTag != null)
            Row(
              children: [
                Icon(_actionTagIcon(actionTag), size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  _formatActionTag(actionTag),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          if (narrative != null) ...[
            if (actionTag != null) const SizedBox(height: 8),
            Text(
              narrative,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Full verdict card with Story endpoint data.
  Widget _buildVerdictFromStory(
      ThemeData theme, DiscoverStockItem item, StockStory story) {
    final actionTag = story.actionTag ?? item.actionTag;
    final verdict = story.verdict;
    final narrative = story.whyNarrative ?? item.scoreBreakdown.whyNarrative;
    final reasoning = story.actionTagReasoning;

    if (actionTag == null && verdict == null && narrative == null) {
      return const SizedBox.shrink();
    }

    final color = actionTag != null
        ? _actionTagColor(actionTag)
        : Colors.white54;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action tag header
          if (actionTag != null)
            Row(
              children: [
                Icon(_actionTagIcon(actionTag), size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  _formatActionTag(actionTag),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),

          // Verdict
          if (verdict != null) ...[
            const SizedBox(height: 8),
            Text(
              verdict,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Narrative
          if (narrative != null) ...[
            const SizedBox(height: 6),
            Text(
              narrative,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],

          // Action tag reasoning
          if (reasoning != null) ...[
            const SizedBox(height: 6),
            Text(
              reasoning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],

          // Signal chips
          _buildVerdictSignals(theme, story, item.tags),
        ],
      ),
    );
  }

  Widget _buildVerdictSignals(ThemeData theme, StockStory story, List<TagV2>? tags) {
    final chips = <Widget>[];
    if (story.lynchClassification != null) {
      chips.add(_storyChip(theme, Icons.category,
          _formatActionTag(story.lynchClassification!), AppTheme.accentBlue,
          explanation: 'Peter Lynch classification based on growth & earnings profile'));
    }
    if (story.trendAlignment != null) {
      final tColor = story.trendAlignment == 'aligned'
          ? AppTheme.accentGreen
          : story.trendAlignment == 'conflicting'
              ? AppTheme.accentRed
              : Colors.amber;
      final icon = story.trendAlignment == 'aligned'
          ? Icons.check_circle_outline
          : story.trendAlignment == 'conflicting'
              ? Icons.cancel_outlined
              : Icons.warning_amber_rounded;
      final tTooltip = story.trendAlignment == 'aligned'
          ? 'Fundamental and technical signals agree'
          : story.trendAlignment == 'conflicting'
              ? 'Fundamental and technical signals disagree'
              : 'Mixed signals between fundamentals and technicals';
      chips.add(_storyChip(
          theme, icon, 'Trend: ${_capitalize(story.trendAlignment!)}', tColor,
          explanation: tTooltip));
    }
    if (story.breakoutSignal != null && story.breakoutSignal != 'none') {
      chips.add(_storyChip(theme, Icons.flash_on,
          _formatActionTag(story.breakoutSignal!), AppTheme.accentTeal,
          explanation: 'Price breakout signal based on 52-week range & volume'));
    }

    // Bullish/Bearish Trend from DMA data
    if (tags != null) {
      final dmaTag = tags.cast<TagV2?>().firstWhere(
          (t) => t!.tag == 'Bullish Trend' || t.tag == 'Bearish Trend',
          orElse: () => null);
      if (dmaTag != null) {
        final isBullish = dmaTag.tag == 'Bullish Trend';
        chips.add(_storyChip(
          theme,
          isBullish ? Icons.trending_up : Icons.trending_down,
          dmaTag.tag,
          isBullish ? AppTheme.accentGreen : AppTheme.accentRed,
          explanation: dmaTag.explanation ?? 'Based on 50-DMA and 200-DMA alignment',
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
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
        // Profitability & Growth (merged)
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profitability & Growth',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
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
                      label: 'Gross Margin',
                      value: _marginPct(item.grossMargins),
                      valueColor: item.grossMargins == null ? Colors.white38 : null,
                      tooltip: metricExplanations['gross_margin'],
                    ),
                    StatCard(
                      label: 'Operating Margin',
                      value: _marginPct(item.operatingMargins),
                      valueColor: item.operatingMargins == null
                          ? Colors.white38
                          : null,
                      tooltip: metricExplanations['operating_margin'],
                    ),
                    StatCard(
                      label: 'Net Margin',
                      value: _marginPct(item.profitMargins),
                      valueColor: _marginColor(item.profitMargins),
                      tooltip: metricExplanations['profit_margin'],
                    ),
                    StatCard(
                      label: 'FCF Yield',
                      value: fcfYield != null
                          ? '${fcfYield.toStringAsFixed(1)}%'
                          : '\u2014',
                      valueColor: fcfYield == null
                          ? Colors.white38
                          : (fcfYield > 5 ? AppTheme.accentGreen : null),
                      tooltip: metricExplanations['fcf_yield'],
                    ),
                    StatCard(
                      label: 'Revenue Growth',
                      value: _marginPct(item.revenueGrowth),
                      valueColor: _changeColor(item.revenueGrowth),
                    ),
                    StatCard(
                      label: 'Earnings Growth',
                      value: _marginPct(item.earningsGrowth),
                      valueColor: _changeColor(item.earningsGrowth),
                    ),
                    if (item.opmChange != null)
                      StatCard(
                        label: 'OPM Change',
                        value: '${item.opmChange! >= 0 ? '+' : ''}${item.opmChange!.toStringAsFixed(1)}%',
                        valueColor: _changeColor(item.opmChange),
                        tooltip: 'Change in operating profit margin vs previous year.',
                      ),
                  ],
                ),
                // Margin trend from plAnnual if available
                if (item.plAnnual != null && item.plAnnual!.isNotEmpty)
                  ..._buildMarginTrendSection(item.plAnnual!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Revenue & Profit Trend (from P&L JSONB)
        Builder(builder: (_) {
          if (item.plAnnual == null || item.plAnnual!.isEmpty) return const SizedBox.shrink();
          final groups = _buildPlTrendGroups(item.plAnnual!);
          if (groups.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Revenue & Profit Trend'),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: GroupedBarChartWidget(
                  groups: groups,
                  barColors: [AppTheme.accentBlue, AppTheme.accentGreen],
                  legendLabels: const ['Revenue', 'Profit'],
                  yAxisLabel: '₹ Cr',
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }),

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
          const SizedBox(height: 12),
        ],

        // Cash Flow Breakdown (GroupedBarChart)
        Builder(builder: (_) {
          if (item.cfAnnual == null || item.cfAnnual!.isEmpty) return const SizedBox.shrink();
          final groups = _buildCfGroups(item.cfAnnual!);
          if (groups.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Cash Flow Breakdown'),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: GroupedBarChartWidget(
                  groups: groups,
                  barColors: [AppTheme.accentGreen, AppTheme.accentOrange, AppTheme.accentBlue],
                  legendLabels: const ['Operating', 'Investing', 'Financing'],
                  yAxisLabel: '₹ Cr',
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }),

        // Valuation & Balance Sheet (merged)
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valuation & Balance Sheet',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                // Valuation metrics
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: [
                    StatCard(
                      label: 'Trailing P/E',
                      value: _ratio(item.peRatio, decimals: 1),
                      valueColor: _peColor(item.peRatio),
                      tooltip: metricExplanations['pe_ratio'],
                    ),
                    StatCard(
                      label: 'Forward P/E',
                      value: _ratio(item.forwardPe, decimals: 1),
                      valueColor: _peColor(item.forwardPe),
                      tooltip: metricExplanations['forward_pe'],
                    ),
                    StatCard(
                      label: 'Price to Book',
                      value: _ratio(item.priceToBook),
                      valueColor: item.priceToBook == null ? Colors.white38 : null,
                      tooltip: metricExplanations['price_to_book'],
                    ),
                    if (item.pegRatio != null)
                      StatCard(
                        label: 'PEG Ratio',
                        value: item.pegRatio!.toStringAsFixed(2),
                        tooltip: metricExplanations['peg_ratio'],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),
                // Balance sheet metrics
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: [
                    StatCard(
                      label: 'Total Debt',
                      value: _formatLargeNumber(item.totalDebt),
                      valueColor: item.totalDebt == null ? Colors.white38 : null,
                      tooltip: metricExplanations['total_debt'],
                    ),
                    StatCard(
                      label: 'Total Cash',
                      value: _formatLargeNumber(item.totalCash),
                      valueColor: item.totalCash == null ? Colors.white38 : null,
                    ),
                    StatCard(
                      label: 'D/E Ratio',
                      value: _ratio(item.debtToEquity),
                      valueColor: _deColor(item.debtToEquity),
                      tooltip: metricExplanations['debt_to_equity'],
                    ),
                    StatCard(
                      label: 'Payout Ratio',
                      value: _marginPct(item.payoutRatio),
                      valueColor: item.payoutRatio == null ? Colors.white38 : null,
                      tooltip: metricExplanations['payout_ratio'],
                    ),
                    if (item.interestCoverage != null)
                      StatCard(
                        label: 'Interest Coverage',
                        value: '${item.interestCoverage!.toStringAsFixed(1)}x',
                        valueColor: item.interestCoverage! < 1.5
                            ? AppTheme.accentRed
                            : (item.interestCoverage! > 3
                                ? AppTheme.accentGreen
                                : null),
                        tooltip: metricExplanations['interest_coverage'],
                      ),
                  ],
                ),
                // Equity vs Debt trend embedded
                if (item.bsAnnual != null && item.bsAnnual!.isNotEmpty)
                  Builder(builder: (_) {
                    final groups = _buildBsGroups(item.bsAnnual!);
                    if (groups.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 8),
                        Text('Equity vs Debt Trend',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white54)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 160,
                          child: GroupedBarChartWidget(
                            groups: groups,
                            barColors: [AppTheme.accentGreen, AppTheme.accentRed],
                            legendLabels: const ['Equity', 'Debt'],
                            yAxisLabel: '₹ Cr',
                          ),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
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

    // Compute QoQ + YoY changes from shareholdingQuarterly JSONB
    final changes = _computeHoldingChanges(item.shareholdingQuarterly);

    final holders = <_OwnershipRow>[
      if (item.promoterHolding != null)
        _OwnershipRow('Promoters', item.promoterHolding!, const Color(0xFF448AFF),
            item.promoterHoldingChange ?? changes['promoter']?['qoq'],
            changes['promoter']?['yoy']),
      if (item.fiiHolding != null)
        _OwnershipRow('FII', item.fiiHolding!, const Color(0xFF64FFDA),
            item.fiiHoldingChange ?? changes['fii']?['qoq'],
            changes['fii']?['yoy']),
      if (item.diiHolding != null)
        _OwnershipRow('DII', item.diiHolding!, const Color(0xFFFFAB40),
            item.diiHoldingChange ?? changes['dii']?['qoq'],
            changes['dii']?['yoy']),
      if (item.governmentHolding != null)
        _OwnershipRow('Government', item.governmentHolding!,
            const Color(0xFFAB47BC),
            changes['government']?['qoq'], changes['government']?['yoy']),
      if (item.publicHolding != null)
        _OwnershipRow('Public', item.publicHolding!, const Color(0xFF78909C),
            changes['public']?['qoq'], changes['public']?['yoy']),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Shareholding card: holder rows with QoQ + YoY ---
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shareholding Pattern',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                // Holder rows with inline QoQ + YoY changes
                ...holders.map((h) => _buildOwnershipRow(theme, h)),
              ],
            ),
          ),
        ),

        // Pledged shares warning
        if (item.pledgedPromoterPct != null &&
            item.pledgedPromoterPct! > 0) ...[
          const SizedBox(height: 8),
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
                Icon(Icons.warning_amber_rounded, size: 16,
                    color: item.pledgedPromoterPct! > 20
                        ? Colors.red : Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Promoter Pledge: ${item.pledgedPromoterPct!.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.pledgedPromoterPct! > 20
                        ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],

        // --- Shareholding Trend (yearly absolute bar chart) ---
        Builder(builder: (_) {
          if (item.shareholdingQuarterly == null ||
              item.shareholdingQuarterly!.isEmpty) {
            return const SizedBox.shrink();
          }
          final sh = item.shareholdingQuarterly!;
          final trendResult = _buildYearlyShareholdingTrend(sh);
          final yearlyGroups = trendResult.$1;
          final activeColors = trendResult.$2;
          final activeLabels = trendResult.$3;
          if (yearlyGroups.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shareholding Trend',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 160,
                        child: GroupedBarChartWidget(
                          groups: yearlyGroups,
                          barColors: activeColors,
                          legendLabels: activeLabels,
                          smartMinY: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),

      ],
    );
  }

  // Single ownership holder row: colored dot + name + holding% + QoQ/YoY pills
  Widget _buildOwnershipRow(ThemeData theme, _OwnershipRow h) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: h.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(h.label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white70)),
          ),
          Text('${h.value.toStringAsFixed(1)}%',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (h.qoqChange != null) ...[
            const SizedBox(width: 8),
            _buildChangePill(theme, 'QoQ', h.qoqChange!),
          ],
          if (h.yoyChange != null) ...[
            const SizedBox(width: 4),
            _buildChangePill(theme, 'YoY', h.yoyChange!),
          ],
        ],
      ),
    );
  }

  // Compact change pill: "QoQ +0.44%" in green/red
  Widget _buildChangePill(ThemeData theme, String period, double change) {
    final isPos = change >= 0;
    final color = isPos ? AppTheme.accentGreen : AppTheme.accentRed;
    final sign = isPos ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPos ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 10, color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$period $sign${change.toStringAsFixed(2)}%',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Yearly absolute shareholding trend ────────────────────────

  /// Build BarGroups showing absolute holding % per year.
  /// Returns (groups, activeColors, activeLabels) — holders with 0% across
  /// all years are excluded to avoid clutter.
  (List<BarGroup>, List<Color>, List<String>) _buildYearlyShareholdingTrend(
      Map<String, dynamic> sh) {
    final years = sh['years'] as List<dynamic>? ?? [];
    if (years.isEmpty) return ([], [], []);

    // All holder series — same colors as Shareholding Pattern card
    final allHolders = <(String, List<dynamic>?, Color)>[
      ('Promoter', (sh['promoter_holding'] ?? sh['promoters']) as List<dynamic>?,
          const Color(0xFF448AFF)),   // blue
      ('FII', (sh['fii_dii'] ?? sh['fiis'] ?? sh['fii']) as List<dynamic>?,
          const Color(0xFF64FFDA)),   // cyan
      ('DII', (sh['diis'] ?? sh['dii']) as List<dynamic>?,
          const Color(0xFFFFAB40)),   // orange
      ('Govt', sh['government'] as List<dynamic>?,
          const Color(0xFFAB47BC)),   // purple
      ('Public', sh['public'] as List<dynamic>?,
          const Color(0xFF78909C)),   // grey
    ];

    // Group indices by year: prefer March for past years, latest quarter
    // for the most recent year.
    final marchMap = <String, int>{};
    final latestMap = <String, int>{};
    for (var i = 0; i < years.length; i++) {
      final label = years[i].toString();
      final match = RegExp(r'(\d{4})').firstMatch(label);
      if (match == null) continue;
      final yr = match.group(1)!;
      latestMap[yr] = i;
      if (label.startsWith('Mar')) marchMap[yr] = i;
    }

    final sortedYears = latestMap.keys.toList()..sort();
    final lastYear = sortedYears.isNotEmpty ? sortedYears.last : '';
    final yearIndices = <String, int>{};
    for (final yr in sortedYears) {
      yearIndices[yr] = yr == lastYear
          ? latestMap[yr]!
          : (marchMap[yr] ?? latestMap[yr]!);
    }

    final display = sortedYears.length > 4
        ? sortedYears.sublist(sortedYears.length - 4)
        : sortedYears;

    // Determine which holders have meaningful data (> 0 in at least one year)
    final activeIndices = <int>[];
    for (var h = 0; h < allHolders.length; h++) {
      final arr = allHolders[h].$2;
      final hasData = display.any((yr) {
        final val = _valAt(arr, yearIndices[yr]!);
        return val > 0.1; // ignore negligible holdings
      });
      if (hasData) activeIndices.add(h);
    }
    if (activeIndices.isEmpty) return ([], [], []);

    // Build groups with only active holders
    final groups = <BarGroup>[];
    for (final yr in display) {
      final i = yearIndices[yr]!;
      groups.add(BarGroup(
        label: yr,
        values: activeIndices.map((h) => _valAt(allHolders[h].$2, i)).toList(),
      ));
    }

    final activeColors = activeIndices.map((h) => allHolders[h].$3).toList();
    final activeLabels = activeIndices.map((h) => allHolders[h].$1).toList();

    return (groups, activeColors, activeLabels);
  }

  Widget _storyChip(
      ThemeData theme, IconData icon, String label, Color color,
      {String? explanation}) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
          if (explanation != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 12,
                color: color.withValues(alpha: 0.6)),
          ],
        ],
      ),
    );
    if (explanation != null) {
      return GestureDetector(
        onTap: () => _showChipExplanation(theme, label, explanation, color),
        child: chip,
      );
    }
    return chip;
  }

  void _showChipExplanation(
      ThemeData theme, String title, String explanation, Color color) {
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
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  // ── Peer Comparison ───────────────────────────────────────────

  Widget _buildPeerComparison(ThemeData theme, DiscoverStockItem item) {
    final peersAsync = ref.watch(discoverStockPeersProvider(item.symbol));

    return peersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (peers) {
        if (peers.isEmpty) return const SizedBox.shrink();
        const headerStyle = TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        );
        const cellStyle = TextStyle(fontSize: 12, color: Colors.white);

        Widget buildScoreBadge(double score) {
          final color = score >= 70
              ? AppTheme.accentGreen
              : score >= 40
                  ? AppTheme.accentOrange
                  : AppTheme.accentRed;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ScoreBar.formatMinified(score),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        String fmtChange(double? v) {
          if (v == null) return '\u2014';
          return '${v >= 0 ? "+" : ""}${v.toStringAsFixed(1)}%';
        }

        Color changeColor(double? v) {
          if (v == null) return Colors.white38;
          return v >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
        }

        Widget buildRow(DiscoverStockItem stock, {bool highlight = false}) {
          return InkWell(
            onTap: highlight
                ? null
                : () => context.push(
                      '/discover/stock/${Uri.encodeComponent(stock.symbol)}',
                      extra: stock,
                    ),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: highlight
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      stock.symbol,
                      style: cellStyle.copyWith(
                        fontWeight:
                            highlight ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: buildScoreBadge(stock.score),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      stock.peRatio?.toStringAsFixed(1) ?? '\u2014',
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      stock.roe != null
                          ? '${stock.roe!.toStringAsFixed(1)}%'
                          : '\u2014',
                      style: cellStyle.copyWith(color: _roeColor(stock.roe)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      stock.debtToEquity?.toStringAsFixed(1) ?? '\u2014',
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      fmtChange(stock.percentChange),
                      style: cellStyle.copyWith(
                        color: changeColor(stock.percentChange),
                        fontWeight: FontWeight.w600,
                      ),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peers in ${item.sector ?? "Sector"}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 3,
                          child: Text('Stock', style: headerStyle)),
                      SizedBox(
                          width: 42,
                          child: Text('Score',
                              style: headerStyle,
                              textAlign: TextAlign.center)),
                      SizedBox(
                          width: 42,
                          child: Text('P/E',
                              style: headerStyle,
                              textAlign: TextAlign.right)),
                      SizedBox(
                          width: 42,
                          child: Text('ROE',
                              style: headerStyle,
                              textAlign: TextAlign.right)),
                      SizedBox(
                          width: 36,
                          child: Text('D/E',
                              style: headerStyle,
                              textAlign: TextAlign.right)),
                      SizedBox(
                          width: 52,
                          child: Text('Change',
                              style: headerStyle,
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                buildRow(item, highlight: true),
                ...peers.take(5).map((peer) => buildRow(peer)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Section Title Helper ─────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  // ── Safe JSONB value converter ─────────────────────────────
  static double _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  // ── JSONB helpers ──────────────────────────────────────────
  //
  // JSONB from backend has columnar format:
  //   {"years": ["Mar 2020", ...], "sales": [100, 200, ...], "net_profit": [10, 20, ...]}
  // We need to pivot this into BarGroup rows for the chart.

  /// Extract a year label from "Mar 2024" → "'24" or return as-is if short.
  static String _shortYear(String yearLabel) {
    final match = RegExp(r'(\d{4})').firstMatch(yearLabel);
    if (match != null) return "'${match.group(1)!.substring(2)}";
    return yearLabel.length > 6 ? yearLabel.substring(yearLabel.length - 4) : yearLabel;
  }

  /// Safely read a value from a List<dynamic> at index.
  static double _valAt(List<dynamic>? list, int i) {
    if (list == null || i >= list.length) return 0;
    return _toNum(list[i]);
  }

  // ── Margin Trend from plAnnual ─────────────────────────────
  List<Widget> _buildMarginTrendSection(Map<String, dynamic> pl) {
    final opmList = (pl['operating_profit_margin_pct'] ?? pl['opm']) as List<dynamic>?;
    final npmList = (pl['net_profit_margin_pct'] ?? pl['npm']) as List<dynamic>?;
    if (opmList == null && npmList == null) return [];

    final years = pl['years'] as List<dynamic>? ?? [];
    final len = years.length;
    final start = len > 5 ? len - 5 : 0;
    final groups = <BarGroup>[];
    for (var i = start; i < len; i++) {
      groups.add(BarGroup(
        label: _shortYear(years[i].toString()),
        values: [_valAt(opmList as List?, i), _valAt(npmList as List?, i)],
      ));
    }
    if (groups.isEmpty) return [];

    return [
      const SizedBox(height: 12),
      const Text('Margin Trend',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
      const SizedBox(height: 8),
      SizedBox(
        height: 160,
        child: GroupedBarChartWidget(
          groups: groups,
          barColors: [AppTheme.accentOrange, AppTheme.accentGreen],
          legendLabels: const ['OPM %', 'NPM %'],
        ),
      ),
    ];
  }

  // ── Chart Data Helpers ──────────────────────────────────────

  List<BarGroup> _buildPlTrendGroups(Map<String, dynamic> pl) {
    final years = pl['years'] as List<dynamic>? ?? [];
    final sales = pl['sales'] as List<dynamic>?;
    final profit = pl['net_profit'] as List<dynamic>?;
    if (years.isEmpty || (sales == null && profit == null)) return [];

    final len = years.length;
    final start = len > 5 ? len - 5 : 0;
    final groups = <BarGroup>[];
    for (var i = start; i < len; i++) {
      groups.add(BarGroup(
        label: _shortYear(years[i].toString()),
        values: [_valAt(sales, i) / 100, _valAt(profit, i) / 100],
      ));
    }
    return groups;
  }

  List<BarGroup> _buildCfGroups(Map<String, dynamic> cf) {
    final years = cf['years'] as List<dynamic>? ?? [];
    final ops = (cf['cash_from_operating_activity'] ?? cf['cash_from_operations']) as List<dynamic>?;
    final inv = (cf['cash_from_investing_activity'] ?? cf['cash_from_investing']) as List<dynamic>?;
    final fin = (cf['cash_from_financing_activity'] ?? cf['cash_from_financing']) as List<dynamic>?;
    if (years.isEmpty) return [];

    final len = years.length;
    final start = len > 5 ? len - 5 : 0;
    final groups = <BarGroup>[];
    for (var i = start; i < len; i++) {
      groups.add(BarGroup(
        label: _shortYear(years[i].toString()),
        values: [
          _valAt(ops as List?, i) / 100,
          _valAt(inv as List?, i) / 100,
          _valAt(fin as List?, i) / 100,
        ],
      ));
    }
    return groups;
  }

  List<BarGroup> _buildBsGroups(Map<String, dynamic> bs) {
    final years = bs['years'] as List<dynamic>? ?? [];
    final equity = (bs['shareholders_equity'] ?? bs['shareholder_equity'] ?? bs['total_equity']) as List<dynamic>?;
    final debt = (bs['borrowings'] ?? bs['total_debt']) as List<dynamic>?;
    if (years.isEmpty || (equity == null && debt == null)) return [];

    final len = years.length;
    final start = len > 5 ? len - 5 : 0;
    final groups = <BarGroup>[];
    for (var i = start; i < len; i++) {
      groups.add(BarGroup(
        label: _shortYear(years[i].toString()),
        values: [
          _valAt(equity as List?, i) / 100,
          _valAt(debt as List?, i) / 100,
        ],
      ));
    }
    return groups;
  }

  /// Compute YoY holding changes from shareholdingQuarterly JSONB.
  /// Compares the latest quarter with the quarter 4 entries ago.
  /// Compute QoQ and YoY holding changes from shareholdingQuarterly JSONB.
  /// Returns {'promoter': {qoq, yoy}, 'fii': {qoq, yoy}, ...}
  Map<String, Map<String, double?>> _computeHoldingChanges(Map<String, dynamic>? sh) {
    if (sh == null || sh.isEmpty) return {};

    Map<String, double?> _changes(List<dynamic>? arr) {
      if (arr == null || arr.length < 2) return {'qoq': null, 'yoy': null};
      final latest = (arr.last as num?)?.toDouble();
      final prev = (arr[arr.length - 2] as num?)?.toDouble();
      double? qoq;
      if (latest != null && prev != null) {
        qoq = double.parse((latest - prev).toStringAsFixed(2));
      }
      double? yoy;
      if (arr.length >= 5) {
        final yearAgo = (arr[arr.length - 5] as num?)?.toDouble();
        if (latest != null && yearAgo != null) {
          yoy = double.parse((latest - yearAgo).toStringAsFixed(2));
        }
      }
      return {'qoq': qoq, 'yoy': yoy};
    }

    final promoter = (sh['promoter_holding'] ?? sh['promoters']) as List<dynamic>?;
    final fii = (sh['fii_dii'] ?? sh['fiis'] ?? sh['fii']) as List<dynamic>?;
    final dii = (sh['diis'] ?? sh['dii']) as List<dynamic>?;
    final govt = sh['government'] as List<dynamic>?;
    final pub = sh['public'] as List<dynamic>?;
    return {
      'promoter': _changes(promoter),
      'fii': _changes(fii),
      'dii': _changes(dii),
      'government': _changes(govt),
      'public': _changes(pub),
    };
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

  Widget _buildGroupedTags(ThemeData theme, List<TagV2> tags) {
    final grouped = groupTagsByCategory(tags);
    final isExpert = ref.read(expertModeProvider);
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
                      children: (isExpert ? entry.value : entry.value.take(3)).map((tag) {
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

  Widget _buildCompactScoreSection(ThemeData theme, DiscoverStockItem item) {
    final sb = item.scoreBreakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ScoreFingerprint(
              quality: sb.quality,
              valuation: sb.valuation,
              growth: sb.growth,
              momentum: sb.momentum,
              institutional: sb.institutional,
              risk: sb.risk,
              dotSize: 12,
            ),
            const SizedBox(width: 12),
            Text(
              item.qualityTier ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ScoreBar.scoreColor(item.score),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Private data holders ─────────────────────────────────────────

class _OwnershipRow {
  final String label;
  final double value;
  final Color color;
  final double? qoqChange;
  final double? yoyChange;

  const _OwnershipRow(this.label, this.value, this.color, this.qoqChange, [this.yoyChange]);
}

class _RadarStat {
  final String label;
  final double value;
  final Color color;

  const _RadarStat(this.label, this.value, this.color);
}
