import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class ScoreFingerprint extends StatelessWidget {
  final double? quality;
  final double? valuation;
  final double? growth;
  final double? momentum;
  final double? institutional;
  final double? risk;
  final double dotSize;
  final VoidCallback? onTap;

  const ScoreFingerprint({
    super.key,
    this.quality,
    this.valuation,
    this.growth,
    this.momentum,
    this.institutional,
    this.risk,
    this.dotSize = 10,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final layers = [
      ('Quality', quality),
      ('Valuation', valuation),
      ('Growth', growth),
      ('Momentum', momentum),
      ('Smart Money', institutional),
      ('Risk', risk),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: layers
            .map((l) =>
                '${l.$1}: ${l.$2?.toStringAsFixed(0) ?? '—'}')
            .join(' · '),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: layers.map((l) {
            final v = l.$2;
            final color = v == null
                ? Colors.white24
                : v >= 60
                    ? AppTheme.accentGreen
                    : v >= 40
                        ? AppTheme.accentOrange
                        : AppTheme.accentRed;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
