import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

class RadarDimension {
  final String label;
  final double value;

  const RadarDimension({required this.label, required this.value});
}

class RadarChartWidget extends StatelessWidget {
  final List<RadarDimension> dimensions;
  final Color fillColor;

  const RadarChartWidget({
    super.key,
    required this.dimensions,
    this.fillColor = AppTheme.accentBlue,
  });

  @override
  Widget build(BuildContext context) {
    if (dimensions.isEmpty) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 1,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            // Hidden reference dataset to fix scale at 0-100
            RadarDataSet(
              dataEntries: dimensions
                  .map((_) => const RadarEntry(value: 100))
                  .toList(),
              fillColor: Colors.transparent,
              borderColor: Colors.transparent,
              borderWidth: 0,
              entryRadius: 0,
            ),
            RadarDataSet(
              dataEntries: dimensions
                  .map((d) => RadarEntry(value: d.value))
                  .toList(),
              fillColor: fillColor.withValues(alpha: 0.2),
              borderColor: fillColor,
              borderWidth: 2,
              entryRadius: 3,
            ),
          ],
          radarBackgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          radarBorderData: const BorderSide(color: Colors.white10),
          tickBorderData: const BorderSide(color: Colors.white10),
          gridBorderData: const BorderSide(color: Colors.white10, width: 0.5),
          tickCount: 4,
          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
          titlePositionPercentageOffset: 0.2,
          titleTextStyle: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
          getTitle: (index, angle) {
            if (index < dimensions.length) {
              return RadarChartTitle(text: dimensions[index].label);
            }
            return const RadarChartTitle(text: '');
          },
          radarShape: RadarShape.polygon,
        ),
      ),
    );
  }
}
