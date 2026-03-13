import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';

class PriceLineChart extends StatefulWidget {
  final List<double> prices;
  final List<DateTime> timestamps;
  final String? unit;

  /// When true, bottom axis shows short labels (e.g. "Mar 8"); when false, "Mar 2025".
  final bool isShortRange;

  /// When true, bottom axis and tooltip show time (HH:mm) for 1D intraday.
  final bool isIntraday;

  /// Timezone id for intraday labels (e.g. Asia/Kolkata, America/New_York). Default IST.
  final String? chartTimeZoneId;

  /// Optional prefix for tooltip/display (e.g. "₹ ").
  final String? pricePrefix;

  /// Optional label shown below the chart (e.g. "₹ /10g").
  final String? chartUnitHint;

  const PriceLineChart({
    super.key,
    required this.prices,
    required this.timestamps,
    this.unit,
    this.isShortRange = true,
    this.isIntraday = false,
    this.chartTimeZoneId,
    this.pricePrefix,
    this.chartUnitHint,
  });

  @override
  State<PriceLineChart> createState() => _PriceLineChartState();
}

class _PriceLineChartState extends State<PriceLineChart> {
  int? _touchedSpotIndex;

  @override
  Widget build(BuildContext context) {
    final prices = widget.prices;
    final timestamps = widget.timestamps;
    if (prices.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final theme = Theme.of(context);
    final isUp = prices.length >= 2 && prices.last >= prices.first;
    final lineColor = isUp ? AppTheme.accentGreen : AppTheme.accentRed;

    final spots = <FlSpot>[];
    for (int i = 0; i < prices.length; i++) {
      spots.add(FlSpot(i.toDouble(), prices[i]));
    }

    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding =
        (range > 0 ? range * 0.08 : maxY * 0.02).clamp(0.0, double.infinity);
    final yMin = minY - padding;
    final yMax = maxY + padding;
    final yStep = (yMax - yMin) / 3;

    // Dynamically compute reservedSize for y-axis based on widest label.
    final yLabelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    );
    double maxLabelWidth = 0;
    for (int i = 0; i <= 3; i++) {
      final label = Formatters.price(yMin + yStep * i, unit: widget.unit);
      final tp = TextPainter(
        text: TextSpan(text: label, style: yLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > maxLabelWidth) maxLabelWidth = tp.width;
    }
    final yAxisReservedSize = (maxLabelWidth + 6).clamp(28.0, 90.0);

    final touchedIndex = _touchedSpotIndex;
    final showIndicators = touchedIndex != null &&
        touchedIndex >= 0 &&
        touchedIndex < spots.length;
    final barData = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: lineColor,
      barWidth: 3,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final showDot = _touchedSpotIndex == index;
          return FlDotCirclePainter(
            radius: showDot ? 4 : 2,
            color: lineColor,
            strokeWidth: showDot ? 2 : 0,
            strokeColor: theme.colorScheme.surface,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.35),
            lineColor.withValues(alpha: 0.12),
            lineColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.06),
                  blurRadius: 40,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 0, right: 20, top: 12, bottom: 4),
              child: AspectRatio(
                aspectRatio: 1.75,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yStep,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: (spots.length / 3)
                              .ceilToDouble()
                              .clamp(3.0, double.infinity),
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= timestamps.length) {
                              return const SizedBox.shrink();
                            }
                            final tzId =
                                widget.chartTimeZoneId ?? 'Asia/Kolkata';
                            final label = widget.isIntraday
                                ? Formatters.chartAxisTime(timestamps[idx],
                                    timeZoneId: tzId)
                                : Formatters.chartAxisDate(
                                    timestamps[idx],
                                    isShortRange: widget.isShortRange,
                                  );
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: yAxisReservedSize,
                          interval: yStep,
                          getTitlesWidget: (value, meta) {
                            final label =
                                Formatters.price(value, unit: widget.unit);
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                label,
                                style: yLabelStyle,
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: yMin,
                    maxY: yMax,
                    baselineY: yMin,
                    lineTouchData: LineTouchData(
                      touchCallback: (event, response) {
                        if (event is FlPanDownEvent ||
                            event is FlPanUpdateEvent ||
                            event is FlTapDownEvent) {
                          if (response?.lineBarSpots != null &&
                              response!.lineBarSpots!.isNotEmpty) {
                            final spot = response.lineBarSpots!.first;
                            setState(() => _touchedSpotIndex = spot.x.toInt());
                          }
                        } else if (event is FlPanEndEvent ||
                            event is FlTapUpEvent) {
                          setState(() => _touchedSpotIndex = null);
                        }
                      },
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) =>
                            theme.colorScheme.surface.withValues(alpha: 0.98),
                        tooltipRoundedRadius: 12,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (touchedSpots) {
                          final prefix = widget.pricePrefix ?? '';
                          return touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            final tzId =
                                widget.chartTimeZoneId ?? 'Asia/Kolkata';
                            final dateStr = idx < timestamps.length
                                ? (widget.isIntraday
                                    ? Formatters.chartAxisTime(timestamps[idx],
                                        timeZoneId: tzId)
                                    : Formatters.date(timestamps[idx]))
                                : '';
                            return LineTooltipItem(
                              '$prefix${Formatters.price(spot.y, unit: widget.unit)}\n$dateStr',
                              TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            );
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                    ),
                    showingTooltipIndicators: showIndicators
                        ? [
                            ShowingTooltipIndicators([
                              LineBarSpot(
                                  barData, 0, barData.spots[touchedIndex])
                            ])
                          ]
                        : [],
                    lineBarsData: [barData],
                  ),
                ),
              ),
            ),
          ),
          if (widget.chartUnitHint != null &&
              widget.chartUnitHint!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.chartUnitHint!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
