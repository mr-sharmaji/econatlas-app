import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/market_price.dart';

class PriceCard extends StatelessWidget {
  final MarketPrice price;
  final MarketPrice? previousPrice;
  final VoidCallback? onTap;

  const PriceCard({
    super.key,
    required this.price,
    this.previousPrice,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change =
        previousPrice != null ? price.price - previousPrice!.price : null;
    final isUp = change != null ? change >= 0 : null;
    final valueLabel = price.instrumentType == 'currency'
        ? Formatters.fxInrPrice(price.price)
        : Formatters.fullPrice(price.price);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName(price.asset),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isUp != null)
                    Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      color: isUp ? AppTheme.accentGreen : AppTheme.accentRed,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                valueLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              if (change != null)
                Text(
                  '${change >= 0 ? '+' : ''}${Formatters.price(change, unit: price.unit)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isUp! ? AppTheme.accentGreen : AppTheme.accentRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                Formatters.relativeTime(price.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactPriceCard extends StatelessWidget {
  final MarketPrice price;
  final VoidCallback? onTap;

  const CompactPriceCard({
    super.key,
    required this.price,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueLabel = price.instrumentType == 'currency'
        ? Formatters.fxInrPrice(price.price)
        : Formatters.fullPrice(price.price);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName(price.asset),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                valueLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.relativeTime(price.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
