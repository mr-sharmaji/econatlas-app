import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../data/models/discover.dart';
import 'score_bar.dart';

/// A compact stock card for the screener list.
class StockListTile extends StatelessWidget {
  final DiscoverStockItem item;
  final VoidCallback? onTap;

  const StockListTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = (item.percentChange ?? 0) >= 0;
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.symbol} ${item.sector != null ? '· ${item.sector}' : ''}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.fullPrice(item.lastPrice),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      Formatters.changeTag(item.percentChange),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ScoreBar(score: item.score),
            if (item.peRatio != null || item.roe != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.peRatio != null)
                    _inlineMetric(
                        context, 'P/E', item.peRatio!.toStringAsFixed(1)),
                  if (item.peRatio != null && item.roe != null)
                    const SizedBox(width: 12),
                  if (item.roe != null)
                    _inlineMetric(
                        context, 'ROE', '${item.roe!.toStringAsFixed(1)}%'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inlineMetric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Text(
      '$label: $value',
      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
    );
  }
}
