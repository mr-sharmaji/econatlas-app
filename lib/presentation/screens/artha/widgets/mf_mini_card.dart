import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Mini mutual fund card rendered inside chat messages.
class MfMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const MfMiniCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final code = data['scheme_code'] as String? ?? '';
    final name = data['display_name'] as String? ??
        data['scheme_name'] as String? ??
        code;
    final nav = (data['nav'] as num?)?.toDouble();
    final returns1y = (data['returns_1y'] as num?)?.toDouble();
    final score = (data['score'] as num?)?.toDouble();
    final category = data['category'] as String?;
    final isPositive = (returns1y ?? 0) >= 0;

    return GestureDetector(
      onTap: () {
        if (code.isNotEmpty) {
          context.push('/discover/mf/$code');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF141829),
              const Color(0xFF1A1F36).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            // MF icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.account_balance,
                size: 18,
                color: Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            // Name and category
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
                  if (category != null)
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
            // NAV & returns
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (nav != null)
                  Text(
                    '\u20b9${nav.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (returns1y != null)
                  Text(
                    '${isPositive ? '+' : ''}${returns1y.toStringAsFixed(1)}% 1Y',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? Colors.green[400] : Colors.red[400],
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

  Color _scoreColor(double score) {
    if (score >= 70) return Colors.green[400]!;
    if (score >= 50) return Colors.amber[400]!;
    return Colors.red[400]!;
  }
}
