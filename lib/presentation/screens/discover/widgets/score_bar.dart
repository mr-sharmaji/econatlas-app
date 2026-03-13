import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// A horizontal score bar that fills proportionally from 0 to 100.
/// Color tiers: >=70 green, >=40 orange, <40 red.
class ScoreBar extends StatelessWidget {
  final double score;
  final double height;
  final bool showLabel;

  const ScoreBar({
    super.key,
    required this.score,
    this.height = 6,
    this.showLabel = true,
  });

  static Color scoreColor(double score) {
    if (score >= 70) return AppTheme.accentGreen;
    if (score >= 40) return AppTheme.accentOrange;
    return AppTheme.accentRed;
  }

  static String formatMinified(double score) {
    final scaled = score / 10.0;
    final bounded = scaled < 0 ? 0.0 : (scaled > 10 ? 10.0 : scaled);
    return '${bounded.toStringAsFixed(1)}/10';
  }

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    final fraction = (score / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        if (showLabel) ...[
          Text(
            formatMinified(score),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: height,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Score breakdown with labeled segments side by side.
class ScoreBreakdownBar extends StatelessWidget {
  final List<ScoreSegment> segments;
  final double height;

  const ScoreBreakdownBar({
    super.key,
    required this.segments,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: segments.map((seg) {
        final fraction = (seg.value / 100).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  seg.label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white60),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(seg.color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  seg.value.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ScoreSegment {
  final String label;
  final double value;
  final Color color;

  const ScoreSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}
