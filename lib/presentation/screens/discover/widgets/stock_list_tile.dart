import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../data/models/discover.dart';
import 'score_bar.dart';

/// Which percent-change field to display in the tile.
enum StockChangeField {
  daily, // percent_change (default)
  weekly, // percent_change_1w
  threeMonth, // percent_change_3m
  oneYear, // percent_change_1y
}

/// A compact stock card for the screener list.
///
/// 3-row layout:
/// Row 1: name + price
/// Row 2: symbol · sector  [tag] [tag]  +2.5%
/// Row 3: score bar + tier badge
class StockListTile extends StatelessWidget {
  final DiscoverStockItem item;
  final VoidCallback? onTap;

  /// Which change field to display (driven by sort selection).
  final StockChangeField changeField;

  const StockListTile({
    super.key,
    required this.item,
    this.onTap,
    this.changeField = StockChangeField.daily,
  });

  double? get _displayChange {
    switch (changeField) {
      case StockChangeField.daily:
        return item.percentChange;
      case StockChangeField.weekly:
        return item.percentChange1w;
      case StockChangeField.threeMonth:
        return item.percentChange3m;
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
        return '3M ';
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
        padding: const EdgeInsets.all(12),
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

            const SizedBox(height: 4),

            // Row 2: symbol · sector  [tags]  change%
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
                      // Show first 2 tags as small colored pills
                      if (item.tags.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ...item.tags.take(2).map((tag) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _TagChip(tag: tag),
                            )),
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

            // Row 3: Score bar + quality tier badge
            Row(
              children: [
                Expanded(child: ScoreBar(score: item.score)),
                if (item.qualityTier != null) ...[
                  const SizedBox(width: 8),
                  _QualityTierBadge(tier: item.qualityTier!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tag chip for stock tags (Growth, FII, Value, etc.)
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = _tagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static Color _tagColor(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('growth') || t.contains('momentum')) return AppTheme.accentGreen;
    if (t.contains('value') || t.contains('dividend')) return AppTheme.accentOrange;
    if (t.contains('fii') || t.contains('dii')) return AppTheme.accentBlue;
    if (t.contains('quality') || t.contains('strong')) return AppTheme.accentTeal;
    if (t.contains('volatile') || t.contains('risk')) return AppTheme.accentRed;
    return Colors.white54;
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tier,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'strong':
        return AppTheme.accentGreen;
      case 'good':
        return AppTheme.accentBlue;
      case 'average':
        return AppTheme.accentOrange;
      case 'weak':
        return AppTheme.accentRed;
      default:
        return Colors.white54;
    }
  }
}
