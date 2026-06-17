import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/usecases/get_trend_data.dart';

class TrendChart extends StatelessWidget {
  final List<YearTrendData> data;

  const TrendChart({super.key, required this.data});

  bool _shouldShowYearLabel(int year, int firstYear, int lastYear) {
    if (year == firstYear || year == lastYear) return true;
    return (year - firstYear) % 5 == 0;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }

    final maxY = data
        .map((e) => e.publicationCount)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    final firstYear = data.first.year;
    final lastYear = data.last.year;
    final horizontalInterval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1.0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.25,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.onSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final d = data[spot.x.toInt()];
                return LineTooltipItem(
                  '${d.year}\n${d.publicationCount} papers',
                  TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }

                final year = data[idx].year;
                if (!_shouldShowYearLabel(year, firstYear, lastYear)) {
                  return const SizedBox.shrink();
                }

                return Transform.rotate(
                  angle: -0.5,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      year.toString(),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.onSurfaceVariant,
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
              reservedSize: 32,
              interval: horizontalInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
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
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.surfaceContainerHigh,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) => FlSpot(i.toDouble(), data[i].publicationCount.toDouble()),
            ),
            isCurved: true,
            color: AppColors.primaryContainer,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length <= 24,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 2.5,
                color: AppColors.primaryContainer,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
