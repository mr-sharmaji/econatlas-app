import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../data/models/discover.dart';
import 'score_bar.dart';
import 'score_fingerprint.dart';

class ScoreVerdictCard extends StatelessWidget {
  final DiscoverStockItem item;
  final VoidCallback? onFingerprintTap;

  const ScoreVerdictCard({
    super.key,
    required this.item,
    this.onFingerprintTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sb = item.scoreBreakdown;
    final score = item.score;
    final scoreColor = ScoreBar.scoreColor(score);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Circular score
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: score / 100,
                          strokeWidth: 4,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          valueColor:
                              AlwaysStoppedAnimation(scoreColor),
                        ),
                      ),
                      Text(
                        ScoreBar.formatMinified(score),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.qualityTier ?? _tierFromScore(score),
                            style:
                                theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scoreColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (sb.has6LayerScores)
                            ScoreFingerprint(
                              quality: sb.quality,
                              valuation: sb.valuation,
                              growth: sb.growth,
                              momentum: sb.momentum,
                              institutional: sb.institutional,
                              risk: sb.risk,
                              onTap: onFingerprintTap,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Confidence + Trend alignment chips
                      Row(
                        children: [
                          if (sb.scoreConfidence != null &&
                              sb.scoreConfidence != 'high')
                            _buildMiniChip(
                              context,
                              sb.scoreConfidence == 'medium'
                                  ? '~ Medium confidence'
                                  : '\u26A0 Low confidence',
                              sb.scoreConfidence == 'medium'
                                  ? AppTheme.accentOrange
                                  : AppTheme.accentRed,
                            ),
                          if (sb.trendAlignment != null) ...[
                            if (sb.scoreConfidence != null &&
                                sb.scoreConfidence != 'high')
                              const SizedBox(width: 6),
                            _buildMiniChip(
                              context,
                              sb.trendAlignment == 'aligned'
                                  ? '\u2713 Signals aligned'
                                  : sb.trendAlignment == 'divergent'
                                      ? '\u2194 Mixed signals'
                                      : '\u2717 Conflicting',
                              sb.trendAlignment == 'aligned'
                                  ? AppTheme.accentGreen
                                  : sb.trendAlignment == 'divergent'
                                      ? AppTheme.accentOrange
                                      : AppTheme.accentRed,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Verdict text
            if (sb.whyNarrative != null) ...[
              const SizedBox(height: 10),
              Text(
                sb.whyNarrative!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(
      BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }

  static String _tierFromScore(double score) {
    if (score >= 80) return 'Strong';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Average';
    return 'Weak';
  }
}
