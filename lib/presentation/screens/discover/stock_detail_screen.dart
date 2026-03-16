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
import 'widgets/position_bar.dart';
import 'widgets/radar_chart_widget.dart';
import 'widgets/metric_glossary.dart';
import 'widgets/stat_card.dart';
import 'widgets/tag_utils.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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

  /// Normalize market_cap to crores (some sources store raw rupees, others crores).
  /// Indian max market cap is ~20 lakh crore = 2e7 Cr.  Anything > 1e7 is likely raw rupees.
  static double _mcapInCr(double raw) => raw > 1e7 ? raw / 1e7 : raw;

  /// Format market cap for display, handling mixed units.
  static String _formatMarketCap(double? raw) {
    if (raw == null) return '\u2014';
    final cr = _mcapInCr(raw);
    if (cr >= 1e5) {
      return '\u20B9${(cr / 1e5).toStringAsFixed(2)} L Cr';
    }
    return '\u20B9${Formatters.price(cr)} Cr';
  }

  static String _formatShareholderCount(int count) {
    if (count >= 1e7) return '${(count / 1e7).toStringAsFixed(1)} Cr';
    if (count >= 1e5) return '${(count / 1e5).toStringAsFixed(1)} L';
    if (count >= 1e3) return '${(count / 1e3).toStringAsFixed(0)}K';
    return count.toString();
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
              'NSE \u00B7 Mkt Cap: ${_formatMarketCap(item.marketCap)}',
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
              loading: () => const ShimmerCard(height: 180),
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

            // ── Tags (outside tabs) ──
            if (item.tags.isNotEmpty) ...[
              _buildGroupedTags(theme, _filterVerdictTags(item)),
              const SizedBox(height: 8),
            ],

            // ── Peer Comparison ──
            _buildPeerComparison(theme, item),
            const SizedBox(height: 12),

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
                indicator: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerColor: Colors.transparent,
                labelColor: AppTheme.accentBlue,
                unselectedLabelColor: Colors.white54,
                labelStyle: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: theme.textTheme.labelMedium,
                tabs: const [
                  Tab(text: 'Financials'),
                  Tab(text: 'Ownership'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Tab Content (indexed, no TabBarView) ──
            _buildTabContent(theme, item),
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
      _RadarStat('Financial Health', sb.quality ?? 0, AppTheme.accentGreen, 'score_financial_health'),
      _RadarStat('Valuation', sb.valuation ?? 0, AppTheme.accentOrange, 'score_valuation'),
      _RadarStat('Growth', sb.growth, AppTheme.accentTeal, 'score_growth'),
      _RadarStat('Momentum', sb.momentum, AppTheme.accentBlue, 'score_momentum'),
      _RadarStat('Smart Money', sb.institutional ?? 0, const Color(0xFF7986CB), 'score_smart_money'),
      _RadarStat('Risk Shield', sb.risk ?? 0, const Color(0xFFAB47BC), 'score_risk_shield'),
    ];

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: RadarChartWidget(dimensions: dimensions),
        ),
        const SizedBox(height: 16),
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
                    metricKey: e.metricKey,
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
        return _buildFinancialsTab(theme, item);
      case 1:
        return _buildOwnershipTab(theme, item);
      default:
        return const SizedBox.shrink();
    }
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

    final bannerTags = _bannerContextTags(item.tags);

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
          Row(
            children: [
              if (actionTag != null) ...[
                Icon(_actionTagIcon(actionTag), size: 18, color: color),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  actionTag != null ? _formatActionTag(actionTag) : '',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (item.scoreConfidence != null)
                _miniIndicator(theme,
                    item.scoreConfidence == 'high'
                        ? Icons.verified_rounded
                        : item.scoreConfidence == 'medium'
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                    '${_capitalize(item.scoreConfidence!)} alignment',
                    item.scoreConfidence == 'high'
                        ? AppTheme.accentGreen
                        : item.scoreConfidence == 'medium'
                            ? Colors.amber
                            : Colors.white38),
            ],
          ),
          if (narrative != null) ...[
            const SizedBox(height: 8),
            Text(
              narrative,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
          if (bannerTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: bannerTags.map((t) {
                final td = getTagV2Display(t);
                return _bannerChip(theme, td, t);
              }).toList(),
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

    if (actionTag == null && verdict == null && narrative == null) {
      return const SizedBox.shrink();
    }

    final color = actionTag != null
        ? _actionTagColor(actionTag)
        : Colors.white54;

    final bannerTags = _bannerContextTags(item.tags);

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
          // Action tag header row with confidence badge
          Row(
            children: [
              if (actionTag != null) ...[
                Icon(_actionTagIcon(actionTag), size: 18, color: color),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  actionTag != null ? _formatActionTag(actionTag) : '',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (item.scoreConfidence != null)
                _miniIndicator(theme,
                    item.scoreConfidence == 'high'
                        ? Icons.verified_rounded
                        : item.scoreConfidence == 'medium'
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                    '${_capitalize(item.scoreConfidence!)} alignment',
                    item.scoreConfidence == 'high'
                        ? AppTheme.accentGreen
                        : item.scoreConfidence == 'medium'
                            ? Colors.amber
                            : Colors.white38),
            ],
          ),

          // Verdict one-liner
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

          // Narrative paragraph
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

          // Context tag chips
          if (bannerTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: bannerTags.map((t) {
                final td = getTagV2Display(t);
                return _bannerChip(theme, td, t);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Pick conviction, risk-context, and context tags for the banner.
  List<TagV2> _bannerContextTags(List<TagV2> tags) {
    const bannerCategories = {'conviction', 'context'};
    // Also include specific risk tags from context generation (not the general risk tags)
    const contextRiskTags = {
      'Oversold Quality', 'Low Risk Setup', 'High Risk Momentum',
      'Overbought Warning', 'Near 52W Low', 'Near 52W High',
    };
    return tags.where((t) {
      if (t.isExpired) return false;
      if (bannerCategories.contains(t.category)) return true;
      if (t.category == 'risk' && contextRiskTags.contains(t.tag)) return true;
      return false;
    }).toList();
  }

  /// Compact chip for banner display. Matches tag chip style exactly.
  /// Tappable when tag has an explanation — reuses the same popup as Tags section.
  Widget _bannerChip(ThemeData theme, TagDisplay td, TagV2 tag) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          Text(td.label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: td.color, fontWeight: FontWeight.w600)),
          if (tag.explanation != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.info_outline,
                size: 12, color: td.color.withValues(alpha: 0.6)),
          ],
        ],
      ),
    );
    if (tag.explanation == null) return chip;
    return GestureDetector(
      onTap: () => _showTagExplanation(theme, tag),
      child: chip,
    );
  }

  /// Tiny icon + label indicator used in the banner strip.
  Widget _miniIndicator(
      ThemeData theme, IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                color: color, fontWeight: FontWeight.w600, fontSize: 11)),
      ],
    );
  }


  // ── FINANCIALS TAB ──────────────────────────────────────────

  Widget _buildFinancialsTab(ThemeData theme, DiscoverStockItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Overview ──
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overview',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _metricRow(context,
                    label: 'Market Cap',
                    value: _formatMarketCap(item.marketCap),
                    metricKey: 'market_cap'),
                _metricRow(context,
                    label: item.sectorPercentile != null
                        ? 'P/E Ratio (${item.sectorPercentile!.toStringAsFixed(0)}th %ile)'
                        : 'P/E Ratio',
                    value: _ratio(item.peRatio, decimals: 1),
                    valueColor: _peColor(item.peRatio),
                    metricKey: 'pe_ratio'),
                _metricRow(context,
                    label: 'P/B Ratio',
                    value: _ratio(item.priceToBook),
                    metricKey: 'price_to_book'),
                _metricRow(context,
                    label: 'EPS',
                    value: item.eps != null
                        ? '\u20B9${item.eps!.toStringAsFixed(1)}'
                        : '\u2014',
                    metricKey: 'eps'),
                if (item.forwardPe != null)
                  _metricRow(context,
                      label: 'Forward PE',
                      value: item.forwardPe!.toStringAsFixed(1),
                      valueColor: item.peRatio != null && item.forwardPe! < item.peRatio!
                          ? AppTheme.accentGreen : null,
                      metricKey: 'forward_pe'),
                if (item.pegRatio != null)
                  _metricRow(context,
                      label: 'PEG Ratio',
                      value: item.pegRatio!.toStringAsFixed(2),
                      valueColor: item.pegRatio! < 1.0
                          ? AppTheme.accentGreen
                          : item.pegRatio! > 2.5
                              ? AppTheme.accentRed
                              : null,
                      metricKey: 'peg_ratio'),
                _metricRow(context,
                    label: 'Dividend Yield',
                    value: item.dividendYield != null
                        ? '${item.dividendYield!.toStringAsFixed(2)}%'
                        : '\u2014',
                    metricKey: 'dividend_yield'),
                _metricRow(context,
                    label: 'Beta',
                    value: item.beta != null
                        ? item.beta!.toStringAsFixed(2)
                        : '\u2014',
                    metricKey: 'beta',
                    isLast: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Profitability ──
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profitability',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _metricRow(context,
                    label: 'ROE',
                    value: _pct(item.roe),
                    valueColor: _roeColor(item.roe),
                    metricKey: 'roe'),
                _metricRow(context,
                    label: 'ROCE',
                    value: _pct(item.roce),
                    valueColor: _roeColor(item.roce),
                    metricKey: 'roce'),
                _metricRow(context,
                    label: 'Operating Margin',
                    value: _marginPct(item.operatingMargins),
                    metricKey: 'operating_margin'),
                _metricRow(context,
                    label: 'Net Margin',
                    value: _marginPct(item.profitMargins),
                    valueColor: _marginColor(item.profitMargins),
                    metricKey: 'profit_margin'),
                _metricRow(context,
                    label: 'Revenue Growth',
                    value: _marginPct(item.revenueGrowth),
                    valueColor: _changeColor(item.revenueGrowth),
                    metricKey: 'revenue_growth'),
                _metricRow(context,
                    label: 'Earnings Growth',
                    value: _marginPct(item.earningsGrowth),
                    valueColor: _changeColor(item.earningsGrowth),
                    metricKey: 'earnings_growth'),
                if (item.compoundedSalesGrowth3y != null)
                  _metricRow(context,
                      label: 'Revenue CAGR (3Y)',
                      value: '${item.compoundedSalesGrowth3y!.toStringAsFixed(0)}%',
                      valueColor: _changeColor(item.compoundedSalesGrowth3y! / 100)),
                if (item.compoundedProfitGrowth3y != null)
                  _metricRow(context,
                      label: 'Profit CAGR (3Y)',
                      value: '${item.compoundedProfitGrowth3y!.toStringAsFixed(0)}%',
                      valueColor: _changeColor(item.compoundedProfitGrowth3y! / 100),
                      isLast: item.plAnnual == null || item.plAnnual!.isEmpty),
                // Revenue & Profit Trend chart
                if (item.plAnnual != null && item.plAnnual!.isNotEmpty)
                  Builder(builder: (_) {
                    final groups = _buildPlTrendGroups(item.plAnnual!);
                    if (groups.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text('Revenue & Profit Trend',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white54)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 160,
                          child: GroupedBarChartWidget(
                            groups: groups,
                            barColors: [
                              AppTheme.accentBlue,
                              AppTheme.accentGreen
                            ],
                            legendLabels: const ['Revenue', 'Profit'],
                            yAxisLabel: '\u20B9 Cr',
                          ),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Balance Sheet ──
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Balance Sheet',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _metricRow(context,
                    label: 'D/E Ratio',
                    value: _ratio(item.debtToEquity),
                    valueColor: _deColor(item.debtToEquity),
                    metricKey: 'debt_to_equity'),
                if (item.interestCoverage != null)
                  _metricRow(context,
                      label: 'Interest Coverage',
                      value:
                          '${item.interestCoverage!.toStringAsFixed(1)}x',
                      valueColor: item.interestCoverage! < 1.5
                          ? AppTheme.accentRed
                          : (item.interestCoverage! > 3
                              ? AppTheme.accentGreen
                              : null),
                      metricKey: 'interest_coverage'),
                _metricRow(context,
                    label: 'Total Debt',
                    value: _formatLargeNumber(item.totalDebt),
                    metricKey: 'total_debt'),
                _metricRow(context,
                    label: 'Total Cash',
                    value: _formatLargeNumber(item.totalCash)),
                if (item.freeCashFlow != null)
                  _metricRow(context,
                      label: 'Free Cash Flow',
                      value: _formatLargeNumber(item.freeCashFlow),
                      valueColor: item.freeCashFlow != null &&
                              item.freeCashFlow! < 0
                          ? AppTheme.accentRed
                          : AppTheme.accentGreen,
                      metricKey: 'free_cash_flow'),
                _metricRow(context,
                    label: 'Payout Ratio',
                    value: _marginPct(item.payoutRatio),
                    metricKey: 'payout_ratio',
                    isLast: true),
              ],
            ),
          ),
        ),

        // ── Cash Flow ──
        if (item.cashFromOperations != null ||
            item.cashFromInvesting != null ||
            item.cashFromFinancing != null) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cash Flow',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (item.cashFromOperations != null)
                    _metricRow(context,
                        label: 'Operating (CFO)',
                        value: _formatLargeNumber(item.cashFromOperations),
                        valueColor: item.cashFromOperations! >= 0
                            ? AppTheme.accentGreen
                            : AppTheme.accentRed,
                        metricKey: 'cash_from_operations'),
                  if (item.cashFromInvesting != null)
                    _metricRow(context,
                        label: 'Investing (CFI)',
                        value: _formatLargeNumber(item.cashFromInvesting),
                        valueColor: item.cashFromInvesting! >= 0
                            ? AppTheme.accentGreen
                            : Colors.white54,
                        metricKey: 'cash_from_investing'),
                  if (item.cashFromFinancing != null)
                    _metricRow(context,
                        label: 'Financing (CFF)',
                        value: _formatLargeNumber(item.cashFromFinancing),
                        metricKey: 'cash_from_financing',
                        isLast: true),
                ],
              ),
            ),
          ),
        ],
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

    // Build holder rows — skip when value is 0 AND no QoQ/YoY data
    bool _showHolder(double? val, double? qoq, double? yoy) {
      if (val == null) return false;
      if (val != 0) return true;
      // Value is 0 — only show if there's meaningful change data
      return (qoq != null && qoq != 0) || (yoy != null && yoy != 0);
    }

    final promQoq = item.promoterHoldingChange ?? changes['promoter']?['qoq'];
    final promYoy = changes['promoter']?['yoy'];
    final fiiQoq = item.fiiHoldingChange ?? changes['fii']?['qoq'];
    final fiiYoy = changes['fii']?['yoy'];
    final diiQoq = item.diiHoldingChange ?? changes['dii']?['qoq'];
    final diiYoy = changes['dii']?['yoy'];
    final govtQoq = changes['government']?['qoq'];
    final govtYoy = changes['government']?['yoy'];
    final pubQoq = changes['public']?['qoq'];
    final pubYoy = changes['public']?['yoy'];

    final holders = <_OwnershipRow>[
      if (_showHolder(item.promoterHolding, promQoq, promYoy))
        _OwnershipRow('Promoters', item.promoterHolding!, const Color(0xFF448AFF),
            promQoq, promYoy),
      if (_showHolder(item.fiiHolding, fiiQoq, fiiYoy))
        _OwnershipRow('FII', item.fiiHolding!, const Color(0xFF64FFDA),
            fiiQoq, fiiYoy),
      if (_showHolder(item.diiHolding, diiQoq, diiYoy))
        _OwnershipRow('DII', item.diiHolding!, const Color(0xFFFFAB40),
            diiQoq, diiYoy),
      if (_showHolder(item.governmentHolding, govtQoq, govtYoy))
        _OwnershipRow('Government', item.governmentHolding!,
            const Color(0xFFAB47BC), govtQoq, govtYoy),
      if (_showHolder(item.publicHolding, pubQoq, pubYoy))
        _OwnershipRow('Public', item.publicHolding!, const Color(0xFF78909C),
            pubQoq, pubYoy),
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

        // Shareholder count + trends
        if (item.numShareholders != null) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Retail Sentiment',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _metricRow(context,
                      label: 'Shareholders',
                      value: _formatShareholderCount(item.numShareholders!),
                      metricKey: 'num_shareholders'),
                  if (item.numShareholdersChangeQoq != null)
                    _metricRow(context,
                        label: 'QoQ Change',
                        value: '${item.numShareholdersChangeQoq! >= 0 ? '+' : ''}${item.numShareholdersChangeQoq!.toStringAsFixed(1)}%',
                        valueColor: _changeColor(item.numShareholdersChangeQoq! / 100)),
                  if (item.numShareholdersChangeYoy != null)
                    _metricRow(context,
                        label: 'YoY Change',
                        value: '${item.numShareholdersChangeYoy! >= 0 ? '+' : ''}${item.numShareholdersChangeYoy!.toStringAsFixed(1)}%',
                        valueColor: _changeColor(item.numShareholdersChangeYoy! / 100),
                        isLast: true),
                ],
              ),
            ),
          ),
        ],

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
          if (h.qoqChange != null && h.qoqChange != 0) ...[
            const SizedBox(width: 8),
            _buildChangePill(theme, 'QoQ', h.qoqChange!),
          ],
          if (h.yoyChange != null && h.yoyChange != 0) ...[
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

        Widget buildActionIcon(String? actionTag) {
          if (actionTag == null) return const SizedBox(width: 18);
          final color = _actionTagColor(actionTag);
          final icon = _actionTagIcon(actionTag);
          return Icon(icon, size: 14, color: color);
        }

        String fmtMcap(double? v) {
          if (v == null) return '\u2014';
          final cr = _mcapInCr(v);
          if (cr >= 1e5) return '${(cr / 1e5).toStringAsFixed(1)}L Cr';
          if (cr >= 1e3) return '${(cr / 1e3).toStringAsFixed(0)}K Cr';
          return '${cr.toStringAsFixed(0)} Cr';
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
                  SizedBox(width: 18, child: buildActionIcon(stock.actionTag)),
                  const SizedBox(width: 4),
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
                    width: 48,
                    child: Text(
                      fmtMcap(stock.marketCap),
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      fmtChange(stock.percentChange3m ?? stock.percentChange),
                      style: cellStyle.copyWith(
                        color: changeColor(stock.percentChange3m ?? stock.percentChange),
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
                  'Peers in ${item.industry ?? item.sector ?? "Sector"}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: const [
                      SizedBox(width: 22),
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
                          width: 48,
                          child: Text('Mkt Cap',
                              style: headerStyle,
                              textAlign: TextAlign.right)),
                      SizedBox(
                          width: 52,
                          child: Text('3M %',
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

  // ── Metric Row Helper ──────────────────────────────────────

  void _showMetricExplanation(BuildContext context, String label, String explanation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(explanation,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    String? metricKey,
    bool isLast = false,
  }) {
    final explanation =
        metricKey != null ? metricExplanations[metricKey] : null;
    return InkWell(
      onTap: explanation != null
          ? () => _showMetricExplanation(context, label, explanation)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13)),
                  if (explanation != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.info_outline,
                        size: 13, color: Colors.white30),
                  ],
                ],
              ),
            ),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
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

  // ── Chart Data Helpers ──────────────────────────────────────

  List<BarGroup> _buildPlTrendGroups(Map<String, dynamic> pl) {
    final years = pl['years'] as List<dynamic>? ?? [];
    final sales = (pl['sales'] ?? pl['revenue']) as List<dynamic>?;
    final profit = pl['net_profit'] as List<dynamic>?;
    if (years.isEmpty || (sales == null && profit == null)) return [];

    final len = years.length;
    final start = len > 5 ? len - 5 : 0;
    final groups = <BarGroup>[];
    for (var i = start; i < len; i++) {
      groups.add(BarGroup(
        label: _shortYear(years[i].toString()),
        values: [_valAt(sales, i), _valAt(profit, i)],
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

  /// Filter out tags already shown in the verdict banner indicator strip.
  /// Only removes Signal, Risk-Reward, Regime (shown in the compact strip).
  /// Keeps Lynch, Trend, Breakout tags — they have explanations useful in Tags section.
  List<TagV2> _filterVerdictTags(DiscoverStockItem item) {
    // Tags shown in the banner are excluded from the Tags section
    final bannerSet = _bannerContextTags(item.tags).map((t) => t.tag).toSet();
    return item.tags.where((t) {
      if (bannerSet.contains(t.tag)) return false;
      // Safety net: filter out old Signal/Risk-Reward/Regime tags
      if (t.tag.startsWith('Signal:')) return false;
      if (t.tag.startsWith('Risk-Reward:')) return false;
      if (t.tag.startsWith('Regime:')) return false;
      return true;
    }).toList();
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
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
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
  final String? metricKey;

  const _RadarStat(this.label, this.value, this.color, [this.metricKey]);
}
