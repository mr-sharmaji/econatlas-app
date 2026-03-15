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

    // Pick a nice interval first, then align bounds to it
    final rawRange = dataMax - dataMin;
    // Choose interval that gives ~4-5 ticks
    const niceSteps = [1.0, 2.0, 5.0, 10.0, 15.0, 20.0, 25.0, 50.0];
    double interval = 10;
    for (final s in niceSteps) {
      if (rawRange / s <= 6 && rawRange / s >= 3) {
        interval = s;
        break;
      }
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
                reservedSize: 32,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  // Hide the top edge label only
                  if (value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${value.toInt()}%',
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
                return BarTooltipItem(
                  '${val.toStringAsFixed(1)}%',
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
