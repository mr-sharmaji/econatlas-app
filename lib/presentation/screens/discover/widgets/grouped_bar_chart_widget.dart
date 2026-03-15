import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BarGroup {
  final String label;
  final List<double> values;
  final List<Color> colors;

  const BarGroup({
    required this.label,
    required this.values,
    this.colors = const [],
  });
}

class GroupedBarChartWidget extends StatelessWidget {
  final List<BarGroup> groups;
  final List<Color> barColors;
  final List<String> legendLabels;
  final String? yAxisLabel;
  /// When true, y-axis starts from a smart minimum instead of 0
  /// to reduce dead space for data with a high baseline (e.g. percentages).
  final bool smartMinY;

  const GroupedBarChartWidget({
    super.key,
    required this.groups,
    this.barColors = const [],
    this.legendLabels = const [],
    this.yAxisLabel,
    this.smartMinY = false,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    // Compute data range
    double dataMin = double.infinity;
    double dataMax = double.negativeInfinity;
    for (final g in groups) {
      for (final v in g.values) {
        if (v < dataMin) dataMin = v;
        if (v > dataMax) dataMax = v;
      }
    }
    if (!dataMin.isFinite) dataMin = 0;
    if (!dataMax.isFinite) dataMax = 100;

    // Pick a nice interval that gives ~4-5 ticks
    final rawRange = (dataMax - dataMin).abs();
    double interval = 10;
    if (rawRange > 0) {
      final rough = rawRange / 5;
      final magExp = (math.log(rough) / math.ln10).floorToDouble();
      final mag = math.pow(10, magExp).toDouble();
      final residual = rough / mag;
      if (residual <= 1.5) {
        interval = mag;
      } else if (residual <= 3.5) {
        interval = mag * 2;
      } else if (residual <= 7.5) {
        interval = mag * 5;
      } else {
        interval = mag * 10;
      }
      if (interval < 1) interval = 1;
    }

    // Align chartMin/chartMax to interval boundaries
    double chartMin = 0;
    if (smartMinY && dataMin > interval) {
      chartMin = (dataMin / interval).floorToDouble() * interval;
    }
    double chartMax = ((dataMax / interval).ceilToDouble() * interval);
    if (chartMax <= chartMin) chartMax = chartMin + interval;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (legendLabels.isNotEmpty && barColors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: List.generate(
                legendLabels.length.clamp(0, barColors.length),
                (i) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: barColors[i],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      legendLabels[i],
                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: BarChart(
        BarChartData(
          minY: chartMin,
          maxY: chartMax,
          barGroups: _buildBarGroups(chartMin),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: yAxisLabel != null
                  ? Text(yAxisLabel!,
                      style: const TextStyle(color: Colors.white38, fontSize: 9))
                  : null,
              axisNameSize: yAxisLabel != null ? 16 : 0,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  // Hide the top edge label only
                  if (value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  // Format label: use compact notation for large values, % for percentages
                  String label;
                  if (yAxisLabel != null && !yAxisLabel!.contains('%')) {
                    // Absolute values (e.g. ₹ Cr) — use compact format
                    if (value.abs() >= 10000) {
                      label = '${(value / 1000).toStringAsFixed(0)}K';
                    } else {
                      label = value.toInt().toString();
                    }
                  } else {
                    label = '${value.toInt()}%';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= groups.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      groups[idx].label,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: Colors.white10,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              left: BorderSide(color: Colors.white24, width: 0.5),
              bottom: BorderSide(color: Colors.white24, width: 0.5),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E1E2C),
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                final val = rod.fromY < 0 ? rod.fromY : rod.toY;
                final isPercent = yAxisLabel == null || yAxisLabel!.contains('%');
                String text;
                if (isPercent) {
                  text = '${val.toStringAsFixed(1)}%';
                } else if (val.abs() >= 10000) {
                  text = '${(val / 1000).toStringAsFixed(1)}K Cr';
                } else {
                  text = '${val.toStringAsFixed(0)} Cr';
                }
                return BarTooltipItem(
                  text,
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ),
          ),
        ),
      ],
    );
  }

  List<BarChartGroupData> _buildBarGroups(double chartMin) {
    return List.generate(groups.length, (groupIdx) {
      final group = groups[groupIdx];
      return BarChartGroupData(
        x: groupIdx,
        barsSpace: 4,
        barRods: List.generate(group.values.length, (barIdx) {
          final val = group.values[barIdx];
          return BarChartRodData(
            fromY: val < 0 ? val : math.max(chartMin, 0),
            toY: val < 0 ? 0 : val,
            color: barIdx < group.colors.length && group.colors.isNotEmpty
                ? group.colors[barIdx]
                : barIdx < barColors.length
                    ? barColors[barIdx]
                    : Colors.white38,
            width: 12,
            borderRadius: val >= 0
                ? const BorderRadius.vertical(top: Radius.circular(3))
                : const BorderRadius.vertical(bottom: Radius.circular(3)),
          );
        }),
      );
    });
  }
}
