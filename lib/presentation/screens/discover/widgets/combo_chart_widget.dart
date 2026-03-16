import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Data for each year in the combo chart.
class ComboChartEntry {
  final String label;
  final double? bar1; // Revenue
  final double? bar2; // Profit
  final double? line1; // OPM%

  const ComboChartEntry({
    required this.label,
    this.bar1,
    this.bar2,
    this.line1,
  });
}

/// Combo chart: grouped bars (left Y-axis, ₹ Cr) + line overlay (right Y-axis, %).
/// Uses a Stack with matching axis configs so both charts align perfectly.
/// Handles negative profit bars and negative margin lines correctly.
class ComboChartWidget extends StatelessWidget {
  final List<ComboChartEntry> entries;
  final List<Color> barColors;
  final Color lineColor;
  final List<String> legendLabels;

  const ComboChartWidget({
    super.key,
    required this.entries,
    this.barColors = const [Color(0xFF448AFF), Color(0xFF64FFDA)],
    this.lineColor = const Color(0xFFFFAB40),
    this.legendLabels = const ['Revenue', 'Profit', 'OPM%'],
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // --- Bar axis (left) ---
    double barDataMax = 0;
    double barDataMin = 0;
    for (final e in entries) {
      for (final v in [e.bar1, e.bar2]) {
        if (v != null) {
          if (v > barDataMax) barDataMax = v;
          if (v < barDataMin) barDataMin = v;
        }
      }
    }
    final barInterval = _niceInterval(barDataMax - math.min(barDataMin, 0));
    final barChartMax =
        (barDataMax / barInterval).ceilToDouble() * barInterval;

    // --- Line axis (right) ---
    double lineMin = double.infinity, lineMax = double.negativeInfinity;
    bool hasLine = false;
    for (final e in entries) {
      if (e.line1 != null) {
        hasLine = true;
        if (e.line1! < lineMin) lineMin = e.line1!;
        if (e.line1! > lineMax) lineMax = e.line1!;
      }
    }
    if (!hasLine || lineMin == lineMax) {
      hasLine = false;
      lineMin = 0;
      lineMax = 100;
    }

    // Always include 0 in the line range so negative margins appear below zero
    final adjLineMin = math.min(lineMin, 0.0);
    final adjLineMax = math.max(lineMax, 0.0);
    final adjLineInterval = _niceInterval(adjLineMax - adjLineMin);
    final lineChartMax =
        (adjLineMax / adjLineInterval).ceilToDouble() * adjLineInterval;
    final lineChartMin =
        (adjLineMin / adjLineInterval).floorToDouble() * adjLineInterval;
    final lineRange = lineChartMax - lineChartMin;

    // Extend bar chart below 0 if line has negative values, so the line
    // renders below the x-axis.  0% on right axis aligns with 0 on left axis.
    double barChartMin = 0.0;
    if (lineChartMin < 0 && lineChartMax > 0) {
      barChartMin = barChartMax * lineChartMin / lineChartMax;
    } else if (lineChartMax <= 0) {
      // All-negative margins — equal space below
      barChartMin = -barChartMax;
    }
    // Also accommodate negative bar values (negative profit)
    if (barDataMin < 0) {
      final minFromBars =
          (barDataMin / barInterval).floorToDouble() * barInterval;
      barChartMin = math.min(barChartMin, minFromBars);
    }
    // Cap: negative space should not exceed positive space
    barChartMin = math.max(barChartMin, -barChartMax);
    final barRange = barChartMax - barChartMin;

    // Shared axis configs to guarantee identical plot-area sizing
    const leftReserved = 40.0;
    const rightReserved = 44.0;
    const bottomReserved = 24.0;
    const leftAxisNameSize = 16.0;

    // Compute right-axis interval in bar-space
    final rightInterval = lineRange > 0
        ? barRange / (lineRange / adjLineInterval)
        : barRange;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (legendLabels.isNotEmpty)
                _legendItem(
                    barColors.isNotEmpty ? barColors[0] : Colors.blue,
                    legendLabels[0]),
              if (legendLabels.length > 1)
                _legendItem(
                    barColors.length > 1 ? barColors[1] : Colors.green,
                    legendLabels[1]),
              if (legendLabels.length > 2 && hasLine)
                _legendItem(lineColor, legendLabels[2], isLine: true),
            ],
          ),
        ),
        // Stacked chart
        Expanded(
          child: Stack(
            children: [
              // ── Bar chart (bottom layer) ──
              BarChart(
                BarChartData(
                  minY: barChartMin,
                  maxY: barChartMax,
                  barGroups: _buildBarGroups(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('\u20B9 Cr',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 9)),
                      axisNameSize: leftAxisNameSize,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: leftReserved,
                        interval: barInterval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          // Only show labels for bar values >= 0
                          // (negative space is for the line axis)
                          if (value < 0) return const SizedBox.shrink();
                          String label;
                          if (value.abs() >= 10000) {
                            label =
                                '${(value / 1000).toStringAsFixed(0)}K';
                          } else {
                            label = value.toInt().toString();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(label,
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: hasLine,
                        reservedSize: rightReserved,
                        interval: rightInterval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          // Map bar value to line value
                          final frac = barRange > 0
                              ? (value - barChartMin) / barRange
                              : 0.0;
                          final lineVal =
                              lineChartMin + frac * lineRange;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text('${lineVal.round()}%',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: bottomReserved,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(entries[idx].label,
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10),
                                overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: barInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: value == 0
                          ? Colors.white24
                          : Colors.white10,
                      strokeWidth: value == 0 ? 1 : 0.5,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      left: BorderSide(
                          color: Colors.white24, width: 0.5),
                      bottom: BorderSide(
                          color: Colors.white24, width: 0.5),
                      right: BorderSide(
                          color: Colors.white24, width: 0.5),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          const Color(0xFF1E1E2C),
                      getTooltipItem:
                          (group, groupIdx, rod, rodIdx) {
                        final val =
                            rod.fromY < 0 ? rod.fromY : rod.toY;
                        String text;
                        if (val.abs() >= 10000) {
                          text =
                              '${(val / 1000).toStringAsFixed(1)}K Cr';
                        } else {
                          text = '${val.toStringAsFixed(0)} Cr';
                        }
                        return BarTooltipItem(
                          text,
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
                ),
                swapAnimationDuration: Duration.zero,
              ),

              // ── Line chart overlay (top layer) ──
              if (hasLine)
                IgnorePointer(
                  child: LineChart(
                    LineChartData(
                      minX: -0.5,
                      maxX: entries.length - 0.5,
                      minY: barChartMin,
                      maxY: barChartMax,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _buildLineSpots(
                              barChartMin, barChartMax,
                              lineChartMin, lineChartMax),
                          isCurved: true,
                          curveSmoothness: 0.2,
                          color: lineColor,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter:
                                (spot, pct, bar, idx) =>
                                    FlDotCirclePainter(
                              radius: 3,
                              color: lineColor,
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      // Match exact same axis sizing as bar chart
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          axisNameSize: leftAxisNameSize,
                          axisNameWidget: const SizedBox.shrink(),
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: leftReserved,
                            getTitlesWidget: (_, __) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: hasLine,
                            reservedSize: rightReserved,
                            getTitlesWidget: (_, __) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: bottomReserved,
                            getTitlesWidget: (_, __) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData:
                          const LineTouchData(enabled: false),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Map line values into bar Y-space so both charts share the same coordinate system.
  /// 0% on the line axis aligns with 0 on the bar axis.
  List<FlSpot> _buildLineSpots(
      double barMin, double barMax, double lineMin, double lineMax) {
    final lineRange = lineMax - lineMin;
    final barRange = barMax - barMin;
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      final v = entries[i].line1;
      if (v == null) continue;
      final mapped = lineRange > 0
          ? ((v - lineMin) / lineRange) * barRange + barMin
          : 0.0;
      spots.add(FlSpot(i.toDouble(), mapped));
    }
    return spots;
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(entries.length, (i) {
      final e = entries[i];
      final v1 = e.bar1 ?? 0;
      final v2 = e.bar2 ?? 0;
      return BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: v1,
            color: barColors.isNotEmpty ? barColors[0] : Colors.blue,
            width: 12,
            borderRadius: v1 >= 0
                ? const BorderRadius.vertical(top: Radius.circular(3))
                : const BorderRadius.vertical(
                    bottom: Radius.circular(3)),
          ),
          BarChartRodData(
            fromY: 0,
            toY: v2,
            color:
                barColors.length > 1 ? barColors[1] : Colors.green,
            width: 12,
            borderRadius: v2 >= 0
                ? const BorderRadius.vertical(top: Radius.circular(3))
                : const BorderRadius.vertical(
                    bottom: Radius.circular(3)),
          ),
        ],
      );
    });
  }

  Widget _legendItem(Color color, String label, {bool isLine = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isLine
            ? Container(width: 12, height: 2, color: color)
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  static double _niceInterval(double range) {
    if (range <= 0) return 10;
    final rough = range / 5;
    final magExp = (math.log(rough) / math.ln10).floorToDouble();
    final mag = math.pow(10, magExp).toDouble();
    final residual = rough / mag;
    double interval;
    if (residual <= 1.5) {
      interval = mag;
    } else if (residual <= 3.5) {
      interval = mag * 2;
    } else if (residual <= 7.5) {
      interval = mag * 5;
    } else {
      interval = mag * 10;
    }
    return interval < 1 ? 1 : interval;
  }
}
