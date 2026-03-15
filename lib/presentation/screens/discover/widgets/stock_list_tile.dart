import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../data/models/discover.dart';
import 'sparkline_widget.dart';
import 'tag_utils.dart';

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
/// Row 2: symbol · sector  [readable tags]  3M change%
/// Row 3: circular score + quality tier text
class StockListTile extends StatelessWidget {
  final DiscoverStockItem item;
  final VoidCallback? onTap;

  /// Which change field to display (driven by sort selection).
  final StockChangeField changeField;

  /// Optional 7-day sparkline data points.
  final List<double>? sparklineValues;

  const StockListTile({
    super.key,
    required this.item,
    this.onTap,
    this.changeField = StockChangeField.threeMonth,
    this.sparklineValues,
  });

  double? get _displayChange {
    switch (changeField) {
      case StockChangeField.daily:
        return item.percentChange;
      case StockChangeField.weekly:
        return item.percentChange1w;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = _displayChange;
    final isPositive = (change ?? 0) >= 0;
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

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
            // Row 1: name + price
            Row(
              children: [
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

            // Row 2: symbol · sector  [readable tags]  3M change%
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${item.symbol}${item.sector != null ? ' \u00b7 ${item.sector}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white54),
                        ),
                      ),
                      if (item.tags.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ...item.tags.take(2).map((tag) {
                          final td = getTagDisplay(tag);
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: td.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(td.icon, size: 9, color: td.color),
                                  const SizedBox(width: 3),
                                  Text(
                                    td.label,
                                    style: TextStyle(
                                      color: td.color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
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

            // Row 3: Circular score + quality tier text + sparkline
            Row(
              children: [
                _CircularScore(score: item.score),
                const SizedBox(width: 10),
                if (item.qualityTier != null)
                  _QualityTierBadge(tier: item.qualityTier!),
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

/// Small colored chip showing quality tier (Strong, Good, Average, Weak).
class _QualityTierBadge extends StatelessWidget {
  final String tier;

  const _QualityTierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tier,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'strong':
      case 'excellent':
        return AppTheme.accentGreen;
      case 'good':
        return AppTheme.accentBlue;
      case 'average':
        return AppTheme.accentOrange;
      case 'weak':
      case 'poor':
        return AppTheme.accentRed;
      default:
        return Colors.white54;
    }
  }
}
