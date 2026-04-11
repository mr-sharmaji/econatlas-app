import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme.dart';
import '../../../widgets/asset_logo_badge.dart';

/// Mini stock card rendered inside chat messages.
class StockMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const StockMiniCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final symbol = data['symbol'] as String? ?? '';
    final name = data['display_name'] as String? ?? symbol;
    final price = (data['last_price'] as num?)?.toDouble();
    final change = (data['percent_change'] as num?)?.toDouble();
    final score = (data['score'] as num?)?.toDouble();
    final sector = data['sector'] as String?;
    final isPositive = (change ?? 0) >= 0;

    return GestureDetector(
      onTap: () {
        if (symbol.isNotEmpty) {
          // URL-encode to survive symbols with `&` (M&M), `/` etc.
          context.push('/discover/stock/${Uri.encodeComponent(symbol)}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.cardDark,
              AppTheme.surfaceDark.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            // Asset badge — uses the same square SVG system as the rest
            // of the app (AssetLogoBadge → SquareBadgeSvg with manifest
            // fallback) so stocks render a consistent, dynamic tile
            // instead of a generic 3-letter text chip.
            AssetLogoBadge(
              asset: name.isNotEmpty ? name : symbol,
              instrumentType: 'stock',
              size: 40,
              borderRadius: 10,
            ),
            const SizedBox(width: 12),
            // Name and sector
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sector != null)
                    Text(
                      sector,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
            // Price & change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (price != null)
                  Text(
                    '\u20b9${_formatPrice(price)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (change != null)
                  Text(
                    '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  ),
              ],
            ),
            // Score badge
            if (score != null) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor(score).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _scoreColor(score),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 100000) return '${(price / 100000).toStringAsFixed(1)}L';
    if (price >= 1000) return price.toStringAsFixed(0);
    return price.toStringAsFixed(2);
  }

  Color _scoreColor(double score) {
    if (score >= 70) return AppTheme.accentGreen;
    if (score >= 50) return AppTheme.accentOrange;
    return AppTheme.accentRed;
  }
}
