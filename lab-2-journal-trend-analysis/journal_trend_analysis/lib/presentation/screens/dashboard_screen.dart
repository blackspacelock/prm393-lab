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
import '../widgets/shimmer_loader.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubAsync = ref.watch(paginatedPublicationsProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const Icon(Icons.analytics, color: AppColors.onSurfaceVariant),
        title: const Text('Research Dashboard'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: pubAsync.when(
        loading: () => const ShimmerLoader(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(paginatedPublicationsProvider),
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
            final prev = summary
                .sparklineData[summary.sparklineData.length - 2]
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
                    borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
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
                              style: AppTextStyles.headlineLarge.copyWith(
                                color: AppColors.onPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (growthLabel.isNotEmpty) ...[
                              const SizedBox(height: AppDimensions.xs),
                              Text(
                                growthLabel,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.onPrimary.withValues(
                                    alpha: 0.8,
                                  ),
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
                                .map((e) => e.publicationCount.toDouble())
                                .toList(),
                            lineColor: AppColors.onPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.base),

                // KPI row — 3 compact boxes in one row
                Row(
                  children: [
                    Expanded(
                      child: _CompactMetric(
                        label: 'Total Publications',
                        value: summary.totalPublications.toString(),
                        icon: Icons.article,
                        iconColor: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _CompactMetric(
                        label: 'Avg. Citations',
                        value: Formatter.formatDouble(summary.avgCitations),
                        icon: Icons.format_quote,
                        iconColor: AppColors.metricOrange,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _CompactMetric(
                        label: 'Most Active Year',
                        value: summary.mostActiveYear?.toString() ?? 'N/A',
                        icon: Icons.calendar_today,
                        iconColor: AppColors.metricGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.base),

                // Most influential paper
                if (summary.mostInfluentialPaper != null) ...[
                  Text(
                    'Most Influential Paper',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  _HoverableCard(
                    onTap: () => context.push(
                      '/publication/${Uri.encodeComponent(summary.mostInfluentialPaper!.id)}',
                      extra: summary.mostInfluentialPaper,
                    ),
                    child: Stack(
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
                            borderRadius: BorderRadius.circular(
                              AppDimensions.shapeMd,
                            ),
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
                                      summary.mostInfluentialPaper!.title,
                                      style: AppTextStyles.titleLarge.copyWith(
                                        color: AppColors.onSurface,
                                      ),
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
                                    AppDimensions.shapeXs,
                                  ),
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
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.citationChipText,
                                      ),
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
                            decoration: const BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(AppDimensions.shapeMd),
                                bottomLeft: Radius.circular(
                                  AppDimensions.shapeMd,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.base),
                ],

                // Top Journal — separate row with title
                if (summary.topJournalName != null) ...[
                  Text(
                    'Most Publications Journal',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  _HoverableCard(
                    onTap: () {
                      ref.read(selectedTopicFilterProvider.notifier).state =
                          null;
                      ref.read(searchPageProvider.notifier).state = 1;
                      ref.read(searchQueryProvider.notifier).state =
                          summary.topJournalName!;
                      context.go('/search');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.shapeMd,
                        ),
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
                                Icons.library_books,
                                size: 20,
                                color: AppColors.primaryContainer,
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              Expanded(
                                child: Text(
                                  summary.topJournalName!,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            '${summary.topJournalPublications ?? 0} publications',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.base),
                ],

                // Top Author — separate row with title
                if (summary.topAuthorName != null) ...[
                  Text(
                    'Most Publications Author',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  _HoverableCard(
                    onTap: () {
                      ref.read(selectedTopicFilterProvider.notifier).state =
                          null;
                      ref.read(searchPageProvider.notifier).state = 1;
                      ref.read(searchQueryProvider.notifier).state =
                          summary.topAuthorName!;
                      context.go('/search');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.shapeMd,
                        ),
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
                              AuthorChip(displayName: summary.topAuthorName!),
                              const SizedBox(width: AppDimensions.sm),
                              Expanded(
                                child: Text(
                                  summary.topAuthorName!,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            '${summary.topAuthorPublications ?? 0} publications',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.base),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _CompactMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: AppDimensions.xs),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> data;
  final Color? lineColor;
  final Color? areaColor;

  const _Sparkline({required this.data, this.lineColor, this.areaColor});

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
              data.length,
              (i) => FlSpot(i.toDouble(), data[i]),
            ),
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

class _HoverableCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _HoverableCard({required this.onTap, required this.child});

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _hovering || _pressing;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
            border: Border.all(
              color: isActive ? AppColors.primaryContainer : Colors.transparent,
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedScale(
            scale: _pressing ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
