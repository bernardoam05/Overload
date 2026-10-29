import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../domain/stats.dart';

/// Simple time-series line chart used for progress and body weight.
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({
    super.key,
    required this.points,
    required this.valueLabel,
    this.height = 200,
    this.color,
  });

  final List<ProgressPoint> points;
  final String Function(double) valueLabel;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    if (points.length < 2) {
      return SizedBox(
        height: height * 0.6,
        child: Center(
          child: Text(
            'Regista pelo menos duas sessões para ver o gráfico.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final first = points.first.date;
    double x(DateTime d) => d.difference(first).inHours / 24;
    final spots = [for (final p in points) FlSpot(x(p.date), p.value)];
    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(1, double.infinity).toDouble();
    final maxX = spots.last.x <= 0 ? 1.0 : spots.last.x;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: (minY - pad).clamp(0, double.infinity).toDouble(),
          maxY: maxY + pad,
          minX: 0,
          maxX: maxX,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min || v == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    valueLabel(v),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (maxX / 3).clamp(1, double.infinity).toDouble(),
                getTitlesWidget: (v, meta) {
                  final d = first.add(Duration(hours: (v * 24).round()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      formatDateShort(d),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${valueLabel(s.y)}\n${formatDateShort(first.add(Duration(hours: (s.x * 24).round())))}',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: c,
              barWidth: 3,
              dotData: FlDotData(
                show: spots.length <= 30,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: c,
                  strokeWidth: 2,
                  strokeColor: theme.colorScheme.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.withValues(alpha: 0.30), c.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
