import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

class PositionBar extends StatelessWidget {
  final double min;
  final double max;
  final double current;
  final String? minLabel;
  final String? maxLabel;
  final Color color;

  const PositionBar({
    super.key,
    required this.min,
    required this.max,
    required this.current,
    this.minLabel,
    this.maxLabel,
    this.color = AppTheme.accentBlue,
  });

  @override
  Widget build(BuildContext context) {
    final range = max - min;
    if (range <= 0) return const SizedBox.shrink();

    final fraction = ((current - min) / range).clamp(0.0, 1.0);
    const nearThreshold = 0.05;
    final nearHigh = fraction >= (1.0 - nearThreshold);
    final nearLow = fraction <= nearThreshold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            const markerSize = 10.0;
            final markerLeft =
                (fraction * (trackWidth - markerSize)).clamp(0.0, trackWidth - markerSize);

            return SizedBox(
              height: 14,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Positioned(
                    left: markerLeft,
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (minLabel != null)
              Text(
                minLabel!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              )
            else
              const SizedBox.shrink(),
            if (nearLow)
              Text(
                'Near Low',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (nearHigh)
              Text(
                'Near High',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (maxLabel != null)
              Text(
                maxLabel!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ],
    );
  }
}
