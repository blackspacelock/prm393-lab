import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../providers/providers.dart';
import '../widgets/author_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/metric_card.dart';
import '../widgets/shimmer_loader.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubAsync = ref.watch(publicationsProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const Icon(Icons.analytics, color: AppColors.onSurfaceVariant),
        title: const Text('Research Dashboard'),
        backgroundColor: AppColors.surfaceContainerLowest,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(publicationsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: pubAsync.when(
        loading: () => const ShimmerLoader(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(publicationsProvider),
        ),
        data: (_) {
          if (summary.totalPublications == 0) {
            return const EmptyState(
              icon: Icons.dashboard,
              message: 'Search for a topic to see insights',
            );
          }

          // Compute YoY growth %
          String growthLabel = '';
          if (summary.sparklineData.length >= 2) {
            final last = summary.sparklineData.last.publicationCount;
            final prev =
                summary.sparklineData[summary.sparklineData.length - 2]
                    .publicationCount;
            if (prev > 0) {
              final pct = ((last - prev) / prev * 100).round();
              growthLabel = pct >= 0 ? '+$pct% YoY' : '$pct% YoY';
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero topic card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.base),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.shapeMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              query,
                              style: AppTextStyles.headlineLarge
                                  .copyWith(color: AppColors.onPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (growthLabel.isNotEmpty) ...[
                              const SizedBox(height: AppDimensions.xs),
                              Text(
                                growthLabel,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.onPrimary
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (summary.sparklineData.isNotEmpty)
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: _Sparkline(
                            data: summary.sparklineData
                                .map((e) =>
                                    e.publicationCount.toDouble())
                                .toList(),
                            lineColor: AppColors.onPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.base),

                // KPI 2×2 grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    MetricCard(
                      title: 'Total Publications',
                      value: summary.totalPublications.toString(),
                      icon: Icons.article,
                      iconColor: AppColors.primaryContainer,
                    ),
                    MetricCard(
                      title: 'Avg. Citations',
                      value: Formatter.formatDouble(summary.avgCitations),
                      icon: Icons.format_quote,
                      iconColor: AppColors.metricOrange,
                    ),
                    MetricCard(
                      title: 'Most Active Year',
                      value: summary.mostActiveYear?.toString() ?? 'N/A',
                      icon: Icons.calendar_today,
                      iconColor: AppColors.metricGreen,
                    ),
                    MetricCard(
                      title: 'Top Growth Year',
                      value: summary.topGrowthYear?.toString() ?? 'N/A',
                      icon: Icons.trending_up,
                      iconColor: AppColors.metricPurple,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.base),

                // Most influential paper
                if (summary.mostInfluentialPaper != null) ...[
                  Text(
                    'Most Influential Paper',
                    style: AppTextStyles.titleLarge
                        .copyWith(color: AppColors.onSurface),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.base + 4,
                          AppDimensions.base,
                          AppDimensions.base,
                          AppDimensions.base,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.shapeMd),
                          border: Border.all(
                            color: AppColors.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  size: 20,
                                  color: AppColors.primaryContainer,
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                Expanded(
                                  child: Text(
                                    summary
                                        .mostInfluentialPaper!.title,
                                    style: AppTextStyles.titleLarge
                                        .copyWith(
                                            color: AppColors.onSurface),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.sm,
                                vertical: AppDimensions.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.citationChipBg,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.shapeXs),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
                                    size: 12,
                                    color: AppColors.citationChipText,
                                  ),
                                  const SizedBox(width: AppDimensions.xs),
                                  Text(
                                    '${Formatter.formatCitationCount(summary.mostInfluentialPaper!.citedByCount)} citations',
                                    style: AppTextStyles.labelMedium
                                        .copyWith(
                                            color: AppColors
                                                .citationChipText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Left accent bar
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(AppDimensions.shapeMd),
                              bottomLeft:
                                  Radius.circular(AppDimensions.shapeMd),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.base),
                ],

                // Top Journal + Top Author side-by-side
                if (summary.topJournalName != null ||
                    summary.topAuthorName != null) ...[
                  Row(
                    children: [
                      if (summary.topJournalName != null)
                        Expanded(
                          child: Container(
                            padding:
                                const EdgeInsets.all(AppDimensions.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.shapeMd),
                              border: Border.all(
                                color: AppColors.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.library_books,
                                  size: 20,
                                  color: AppColors.primaryContainer,
                                ),
                                const SizedBox(height: AppDimensions.sm),
                                Text(
                                  summary.topJournalName!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.onSurface),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (summary.topJournalName != null &&
                          summary.topAuthorName != null)
                        const SizedBox(width: AppDimensions.sm),
                      if (summary.topAuthorName != null)
                        Expanded(
                          child: Container(
                            padding:
                                const EdgeInsets.all(AppDimensions.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.shapeMd),
                              border: Border.all(
                                color: AppColors.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                AuthorChip(
                                    displayName: summary.topAuthorName!),
                                const SizedBox(height: AppDimensions.sm),
                                Text(
                                  summary.topAuthorName!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.onSurface),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.base),
                ],

                // Publication trend mini-chart
                if (summary.sparklineData.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.shapeMd),
                      border: Border.all(
                        color: AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.base,
                            AppDimensions.base,
                            AppDimensions.sm,
                            0,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Publication Trend',
                                style: AppTextStyles.titleLarge
                                    .copyWith(color: AppColors.onSurface),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () =>
                                    context.go('/trends'),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      AppColors.primaryContainer,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('View full →'),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 80,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppDimensions.sm,
                              0,
                              AppDimensions.sm,
                              AppDimensions.base,
                            ),
                            child: _Sparkline(
                              data: summary.sparklineData
                                  .map((e) =>
                                      e.publicationCount.toDouble())
                                  .toList(),
                              lineColor: AppColors.primaryContainer,
                              areaColor: AppColors.citationChipBg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> data;
  final Color? lineColor;
  final Color? areaColor;

  const _Sparkline({
    required this.data,
    this.lineColor,
    this.areaColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final color = lineColor ?? AppColors.primaryContainer;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.25,
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
                data.length, (i) => FlSpot(i.toDouble(), data[i])),
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: areaColor ?? color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
