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
                        '${item.symbol} ${item.sector != null ? '\u00b7 ${item.sector}' : ''}',
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

            // Score bar + quality tier badge
            Row(
              children: [
                Expanded(child: ScoreBar(score: item.score)),
                if (item.qualityTier != null) ...[
                  const SizedBox(width: 8),
                  _QualityTierBadge(tier: item.qualityTier!),
                ],
              ],
            ),

            // Metrics row: P/E, ROE, market cap
            if (item.peRatio != null ||
                item.roe != null ||
                item.marketCap != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.peRatio != null)
                    _inlineMetric(
                        context, 'P/E', item.peRatio!.toStringAsFixed(1)),
                  if (item.peRatio != null &&
                      (item.roe != null || item.marketCap != null))
                    const SizedBox(width: 12),
                  if (item.roe != null)
                    _inlineMetric(
                        context, 'ROE', '${item.roe!.toStringAsFixed(1)}%'),
                  if (item.roe != null && item.marketCap != null)
                    const SizedBox(width: 12),
                  if (item.marketCap != null)
                    _inlineMetric(
                        context, 'MCap', _formatMarketCap(item.marketCap!)),
                ],
              ),
            ],

            // 52-week range indicator
            if (item.low52w != null && item.high52w != null) ...[
              const SizedBox(height: 6),
              _WeekRangeBar(
                low: item.low52w!,
                high: item.high52w!,
                current: item.lastPrice,
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

  /// Format market cap in Indian crore notation.
  /// [value] is already in Crores (from Screener.in / API).
  static String _formatMarketCap(double value) {
    if (value >= 100000) {
      return '\u20b9${(value / 100000).toStringAsFixed(1)} L Cr';
    } else if (value >= 1) {
      // Format with commas for Indian numbering
      final rounded = value.round();
      return '\u20b9${_indianNumber(rounded)} Cr';
    }
    return '\u20b9${value.toStringAsFixed(1)} Cr';
  }

  /// Formats an integer with Indian-style comma grouping (e.g. 12,45,000).
  static String _indianNumber(int n) {
    if (n < 0) return '-${_indianNumber(-n)}';
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(rest[i]);
    }
    return '$buffer,$last3';
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

/// A thin 52-week range bar showing current price position.
class _WeekRangeBar extends StatelessWidget {
  final double low;
  final double high;
  final double current;

  const _WeekRangeBar({
    required this.low,
    required this.high,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final range = high - low;
    final fraction =
        range > 0 ? ((current - low) / range).clamp(0.0, 1.0) : 0.5;

    return Row(
      children: [
        Text(
          '52W',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Colors.white38, fontSize: 9),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          height: 4,
          child: CustomPaint(
            painter: _RangeBarPainter(fraction: fraction),
          ),
        ),
      ],
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  final double fraction;

  _RangeBarPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeCap = StrokeCap.round;

    // Draw track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(2),
      ),
      trackPaint,
    );

    // Draw position indicator
    final indicatorX = fraction * size.width;
    final indicatorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      Offset(indicatorX.clamp(2, size.width - 2), size.height / 2),
      3,
      indicatorPaint,
    );
  }

  @override
  bool shouldRepaint(_RangeBarPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
