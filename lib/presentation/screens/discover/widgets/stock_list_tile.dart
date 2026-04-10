import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../data/models/discover.dart';
import 'sparkline_widget.dart';

/// Which percent-change field to display in the tile.
enum StockChangeField {
  daily, // percent_change
  weekly, // percent_change_1w
  threeMonth, // percent_change_3m (default)
  oneYear, // percent_change_1y
}

/// A compact stock card for the screener list.
///
/// 3-row layout:
/// Row 1: name + price
/// Row 2: symbol · market cap · sector     3M change%
/// Row 3: circular score + quality tier + lynch classification + sparkline
class StockListTile extends StatelessWidget {
  final DiscoverStockItem item;
  final VoidCallback? onTap;

  /// Which change field to display (driven by sort selection).
  final StockChangeField changeField;

  /// Optional sparkline data points.
  final List<double>? sparklineValues;

  const StockListTile({
    super.key,
    required this.item,
    this.onTap,
    // Strict 1D default on all card lists (home, discover, screener,
    // watchlist). Was previously 3M — changed per product decision so
    // cards show today's movement at a glance, matching the new 30-min
    // intraday refresh cadence.
    this.changeField = StockChangeField.daily,
    this.sparklineValues,
  });

  double? get _displayChange {
    switch (changeField) {
      case StockChangeField.daily:
        return item.percentChange;
      case StockChangeField.weekly:
        return item.percentChange1w ?? item.percentChange;
      case StockChangeField.threeMonth:
        return item.percentChange3m ?? item.percentChange;
      case StockChangeField.oneYear:
        return item.percentChange1y;
    }
  }

  String get _changeLabel {
    switch (changeField) {
      case StockChangeField.daily:
        return '';
      case StockChangeField.weekly:
        return '1W ';
      case StockChangeField.threeMonth:
        return item.percentChange3m != null ? '3M ' : '';
      case StockChangeField.oneYear:
        return '1Y ';
    }
  }

  /// Format market cap (in Cr) to compact string.
  static String _formatMarketCap(double crores) {
    if (crores >= 100000) return '${(crores / 100000).toStringAsFixed(1)}L Cr';
    if (crores >= 1000) return '${(crores / 1000).toStringAsFixed(1)}K Cr';
    return '${crores.toStringAsFixed(0)} Cr';
  }

  /// Format lynch classification from snake_case to Title Case.
  static String _formatLynch(String classification) {
    return classification
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Color for Lynch classification badge — uses severity colors from backend.
  /// neutral → blue, cautionary → orange, negative → red.
  static Color _lynchColor(String classification) {
    final normalized = classification.toLowerCase().replaceAll('_', ' ');
    switch (normalized) {
      // neutral severity → blue
      case 'fast grower':
      case 'stalwart':
      case 'asset play':
        return AppTheme.accentBlue;
      // cautionary severity → orange
      case 'slow grower':
      case 'cyclical':
      case 'turnaround':
        return AppTheme.accentOrange;
      // negative severity → red
      case 'speculative':
        return AppTheme.accentRed;
      default:
        return AppTheme.accentBlue;
    }
  }

  /// Icon and color for action verdict tag — matches stock_detail_screen.dart.
  static ({IconData icon, Color color}) _actionVerdict(String? tag) {
    final formatted = _formatLynch(tag ?? ''); // normalize snake_case
    switch (formatted) {
      case 'Strong Outperformer':
        return (icon: Icons.rocket_launch_rounded, color: AppTheme.accentGreen);
      case 'Outperformer':
        return (icon: Icons.trending_up_rounded, color: AppTheme.accentTeal);
      case 'Accumulate':
        return (icon: Icons.add_circle_outline_rounded, color: const Color(0xFF66BB6A));
      case 'Watchlist':
        return (icon: Icons.visibility_rounded, color: AppTheme.accentBlue);
      case 'Momentum Only':
        return (icon: Icons.speed_rounded, color: const Color(0xFF7C4DFF));
      case 'Hold':
      case 'Hold — Low Data':
        return (icon: Icons.pause_circle_outline_rounded, color: AppTheme.accentOrange);
      case 'Neutral':
        return (icon: Icons.pause_circle_outline_rounded, color: AppTheme.accentGray);
      case 'Deteriorating':
        return (icon: Icons.trending_down_rounded, color: const Color(0xFFFF7043));
      case 'Underperformer':
        return (icon: Icons.trending_down_rounded, color: AppTheme.accentRed);
      case 'Avoid':
        return (icon: Icons.block_rounded, color: const Color(0xFFD32F2F));
      default:
        return (icon: Icons.bolt, color: AppTheme.accentTeal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = _displayChange;
    final isPositive = (change ?? 0) >= 0;
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;
    final verdict = _actionVerdict(item.actionTag);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: verdict icon + name + price
            Row(
              children: [
                Icon(verdict.icon, size: 16, color: verdict.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.fullPrice(item.lastPrice),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Row 2: symbol · market cap · sector     3M change%
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.symbol}'
                    '${item.marketCap != null ? ' \u00b7 \u20b9${_formatMarketCap(item.marketCap!)}' : ''}'
                    '${item.sector != null ? ' \u00b7 ${item.sector}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$_changeLabel${Formatters.changeTag(change)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Row 3: score + lynch classification + sparkline
            Row(
              children: [
                _CircularScore(score: item.score),
                if (item.lynchClassification != null) ...[
                  const SizedBox(width: 8),
                  _LynchBadge(classification: item.lynchClassification!),
                ],
                const Spacer(),
                if (sparklineValues != null && sparklineValues!.length >= 2)
                  SizedBox(
                    width: 50,
                    child: SparklineWidget(
                      values: sparklineValues!,
                      color: (sparklineValues!.last >= sparklineValues!.first)
                          ? AppTheme.accentGreen
                          : AppTheme.accentRed,
                      height: 24,
                    ),
                  ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}

/// Circular score indicator.
class _CircularScore extends StatelessWidget {
  final double score;

  const _CircularScore({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppTheme.accentGreen
        : score >= 40
            ? AppTheme.accentOrange
            : AppTheme.accentRed;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        score.toInt().toString(),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Colored chip showing Lynch classification.
class _LynchBadge extends StatelessWidget {
  final String classification;

  const _LynchBadge({required this.classification});

  @override
  Widget build(BuildContext context) {
    final color = StockListTile._lynchColor(classification);
    final label = StockListTile._formatLynch(classification);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
