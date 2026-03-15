import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../data/models/discover.dart';
import 'score_bar.dart';
import 'sparkline_widget.dart';

/// A horizontal "Today's Pick" card for Discover Home.
/// Shows name, score circle, sparkline, and quality tier.
class DiscoverPickCard extends StatelessWidget {
  final DiscoverHomeStockItem item;
  final List<double>? sparklineValues;
  final VoidCallback? onTap;

  const DiscoverPickCard({
    super.key,
    required this.item,
    this.sparklineValues,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = ScoreBar.scoreColor(item.score);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Name + Score badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.symbol}${item.sector != null ? ' · ${item.sector}' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white38,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Score circle
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withValues(alpha: 0.15),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    ScoreBar.formatMinified(item.score),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Sparkline
            if (sparklineValues != null && sparklineValues!.length >= 2)
              SizedBox(
                height: 32,
                child: SparklineWidget(
                  values: sparklineValues!,
                  color: scoreColor,
                ),
              ),
            if (sparklineValues != null && sparklineValues!.length >= 2)
              const SizedBox(height: 6),
            // Row 3: Quality tier + change
            Row(
              children: [
                if (item.qualityTier != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.qualityTier!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                const Spacer(),
                if (item.percentChange != null)
                  Text(
                    '${item.percentChange! >= 0 ? '+' : ''}${item.percentChange!.toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: item.percentChange! >= 0
                          ? AppTheme.accentGreen
                          : AppTheme.accentRed,
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
}
