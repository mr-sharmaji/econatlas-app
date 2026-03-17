import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SparklineWidget extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  final double? width;

  const SparklineWidget({
    super.key,
    required this.values,
    required this.color,
    this.height = 30,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height, width: width);

    final safeValues = values.where((v) => v.isFinite).toList(growable: false);
    if (safeValues.length < 2) return SizedBox(height: height, width: width);

    final spots = List.generate(
      safeValues.length,
      (i) => FlSpot(i.toDouble(), safeValues[i]),
    );
    final minVal = safeValues.reduce((a, b) => a < b ? a : b);
    final maxVal = safeValues.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    final yPad =
        range == 0 ? (minVal.abs() * 0.08).clamp(0.2, 2.0) : range * 0.22;
    final minY = minVal - yPad;
    final maxY = maxVal + yPad;
    const xPad = 0.2;

    return SizedBox(
      height: height,
      width: width,
      child: LineChart(
        LineChartData(
          minX: -xPad,
          maxX: (safeValues.length - 1).toDouble() + xPad,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: safeValues.length > 2,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              preventCurveOvershootingThreshold: 6,
              color: color,
              barWidth: 1.8,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          clipData: const FlClipData.all(),
        ),
        duration: Duration.zero,
      ),
    );
  }
}
