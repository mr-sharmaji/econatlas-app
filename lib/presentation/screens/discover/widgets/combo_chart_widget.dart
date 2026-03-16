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
///
/// Zero-aligned: 0% on the line axis always corresponds to 0 on the bar axis.
/// Negative margins render below the x-axis; positive margins above it.
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

    // Always include 0 in line range so negative margins go below the x-axis
    final adjLineMin = math.min(lineMin, 0.0);
    final adjLineMax = math.max(lineMax, 0.0);
    final adjLineInterval = _niceInterval(adjLineMax - adjLineMin);
    final lineChartMax = adjLineMax <= 0
        ? 0.0
        : (adjLineMax / adjLineInterval).ceilToDouble() * adjLineInterval;
    final lineChartMin = adjLineMin >= 0
        ? 0.0
        : (adjLineMin / adjLineInterval).floorToDouble() * adjLineInterval;

    // Extend bar chart below 0 for negative margins / negative profits.
    // Zero-aligned: 0% ↔ bar=0, so bars and line share the zero point.
    double barChartMin = 0.0;
    if (lineChartMin < 0) {
      if (lineChartMax > 0) {
        // Proportional: e.g. line -20..+15 → bar -barMax..+barMax * 15/20?
        // Cap so negative space doesn't dominate
        final ratio = math.min(lineChartMin.abs() / lineChartMax, 1.0);
        barChartMin = -barChartMax * ratio;
      } else {
        // All negative margins — give equal space below
        barChartMin = -barChartMax;
      }
    }
    // Also accommodate negative bar values (negative profit)
    if (barDataMin < 0) {
      final minFromBars =
          (barDataMin / barInterval).floorToDouble() * barInterval;
      barChartMin = math.min(barChartMin, minFromBars);
    }
    // Final safety cap
    barChartMin = math.max(barChartMin, -barChartMax);

    // Piecewise scales anchored at zero:
    //   v ≥ 0 → mapped = v × posScale   (0 → 0,  lineMax → barMax)
    //   v < 0 → mapped = v × negScale   (0 → 0,  lineMin → barMin)
    final posScale =
        lineChartMax > 0 ? barChartMax / lineChartMax : 0.0;
    final negScale =
        lineChartMin < 0 ? barChartMin.abs() / lineChartMin.abs() : 0.0;

    // Shared axis configs to guarantee identical plot-area sizing
    const leftReserved = 40.0;
    const rightReserved = 44.0;
    const bottomReserved = 24.0;
    const leftAxisNameSize = 16.0;

    // Right-axis interval: use the line interval mapped to bar space via
    // the larger scale so labels are evenly spaced in the dominant half.
    final dominantScale = math.max(posScale, negScale);
    final rightInterval = dominantScale > 0
        ? adjLineInterval * dominantScale
        : (barChartMax - barChartMin);

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
                          // Hide left-axis labels below 0 (negative space
                          // is for the line overlay, labelled on the right)
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
                          // Reverse piecewise mapping: bar value → line %
                          double lineVal;
                          if (value >= 0) {
                            lineVal = posScale > 0
                                ? value / posScale
                                : 0;
                          } else {
                            lineVal = negScale > 0
                                ? value / negScale
                                : 0;
                          }
                          // Skip duplicate 0% labels above zero
                          if (value > 0 && lineVal.abs() < 0.01) {
                            return const SizedBox.shrink();
                          }
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
                      color: value.abs() < 0.01
                          ? Colors.white30
                          : Colors.white10,
                      strokeWidth: value.abs() < 0.01 ? 1.0 : 0.5,
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
                          spots: _buildLineSpots(posScale, negScale),
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

  /// Map line values into bar Y-space using piecewise scaling anchored at zero.
  ///   v ≥ 0 → mapped = v × posScale
  ///   v < 0 → mapped = v × negScale
  List<FlSpot> _buildLineSpots(double posScale, double negScale) {
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      final v = entries[i].line1;
      if (v == null) continue;
      final mapped = v >= 0 ? v * posScale : v * negScale;
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
