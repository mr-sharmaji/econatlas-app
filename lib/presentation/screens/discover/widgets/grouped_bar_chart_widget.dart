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

  const GroupedBarChartWidget({
    super.key,
    required this.groups,
    this.barColors = const [],
    this.legendLabels = const [],
    this.yAxisLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

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
          barGroups: _buildBarGroups(),
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
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
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
            getDrawingHorizontalLine: (value) => const FlLine(
              color: Colors.white10,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E1E2C),
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                return BarTooltipItem(
                  rod.toY.toStringAsFixed(1),
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

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(groups.length, (groupIdx) {
      final group = groups[groupIdx];
      return BarChartGroupData(
        x: groupIdx,
        barsSpace: 4,
        barRods: List.generate(group.values.length, (barIdx) {
          return BarChartRodData(
            toY: group.values[barIdx],
            color: barIdx < group.colors.length && group.colors.isNotEmpty
                ? group.colors[barIdx]
                : barIdx < barColors.length
                    ? barColors[barIdx]
                    : Colors.white38,
            width: 12,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(3),
            ),
          );
        }),
      );
    });
  }
}
