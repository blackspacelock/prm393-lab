import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/usecases/get_trend_data.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/ranked_list_tile.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/trend_chart.dart';

/// Provider for the selected year range filter on the Trends page.
/// Stores (startYear, endYear) pair.
final trendYearRangeProvider = StateProvider<(int, int)?>((_) => null);

/// Ranking mode for Top Journals and Top Authors.
enum TrendRankMode { papers, citations }

final trendRankModeProvider = StateProvider<TrendRankMode>(
  (_) => TrendRankMode.papers,
);

/// Filtered trend data based on selected year range.
final filteredTrendDataProvider = Provider<List<YearTrendData>>((ref) {
  final trendData = ref.watch(trendDataProvider);
  final yearRange = ref.watch(trendYearRangeProvider);
  if (yearRange == null) return trendData;
  return trendData
      .where((d) => d.year >= yearRange.$1 && d.year <= yearRange.$2)
      .toList();
});

class TrendAnalysisScreen extends ConsumerStatefulWidget {
  const TrendAnalysisScreen({super.key});

  @override
  ConsumerState<TrendAnalysisScreen> createState() =>
      _TrendAnalysisScreenState();
}

class _TrendAnalysisScreenState extends ConsumerState<TrendAnalysisScreen> {
  int _journalsVisible = 10;
  int _authorsVisible = 10;

  void _showYearRangeDialog() {
    final trendData = ref.read(trendDataProvider);
    final currentRange = ref.read(trendYearRangeProvider);
    final now = DateTime.now().year;

    final minYear = trendData.isNotEmpty ? trendData.first.year : now - 20;
    final maxYear = trendData.isNotEmpty ? trendData.last.year : now;

    int startYear = currentRange?.$1 ?? minYear;
    int endYear = currentRange?.$2 ?? maxYear;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter by Year Range'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'From:',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const Spacer(),
                      DropdownButton<int>(
                        value: startYear.clamp(minYear, maxYear),
                        items: List.generate(maxYear - minYear + 1, (i) {
                          final y = minYear + i;
                          return DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              startYear = val;
                              if (endYear < startYear) endYear = startYear;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.base),
                  Row(
                    children: [
                      Text(
                        'To:',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const Spacer(),
                      DropdownButton<int>(
                        value: endYear.clamp(startYear, maxYear),
                        items: List.generate(maxYear - startYear + 1, (i) {
                          final y = startYear + i;
                          return DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => endYear = val);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(trendYearRangeProvider.notifier).state = null;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    ref.read(trendYearRangeProvider.notifier).state = (
                      startYear,
                      endYear,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pubAsync = ref.watch(paginatedPublicationsProvider);
    final trendData = ref.watch(filteredTrendDataProvider);
    final topJournals = ref.watch(topJournalsProvider);
    final topAuthors = ref.watch(topAuthorsProvider);
    final query = ref.watch(searchQueryProvider);
    final yearRange = ref.watch(trendYearRangeProvider);
    final summary = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Trend Analysis'),
        backgroundColor: AppColors.surfaceContainerLowest,
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range_outlined,
              color: yearRange != null ? AppColors.primaryContainer : null,
            ),
            onPressed: _showYearRangeDialog,
          ),
        ],
      ),
      body: pubAsync.when(
        loading: () => const ShimmerLoader(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(paginatedPublicationsProvider),
        ),
        data: (paginated) {
          if (trendData.isEmpty && ref.read(trendDataProvider).isEmpty) {
            return const EmptyState(
              icon: Icons.show_chart,
              message: 'Search for a topic to see trends',
            );
          }

          final rankMode = ref.watch(trendRankModeProvider);

          // Sort with tiebreaker
          final sortedJournals = List.of(topJournals)
            ..sort((a, b) {
              if (rankMode == TrendRankMode.citations) {
                final cmp = b.totalCitations.compareTo(a.totalCitations);
                return cmp != 0
                    ? cmp
                    : b.publicationCount.compareTo(a.publicationCount);
              } else {
                final cmp = b.publicationCount.compareTo(a.publicationCount);
                return cmp != 0
                    ? cmp
                    : b.totalCitations.compareTo(a.totalCitations);
              }
            });
          final sortedAuthors = List.of(topAuthors)
            ..sort((a, b) {
              if (rankMode == TrendRankMode.citations) {
                final cmp = b.totalCitations.compareTo(a.totalCitations);
                return cmp != 0
                    ? cmp
                    : b.publicationCount.compareTo(a.publicationCount);
              } else {
                final cmp = b.publicationCount.compareTo(a.publicationCount);
                return cmp != 0
                    ? cmp
                    : b.totalCitations.compareTo(a.totalCitations);
              }
            });

          final maxJ = sortedJournals.isNotEmpty
              ? (rankMode == TrendRankMode.citations
                    ? sortedJournals.first.totalCitations
                    : sortedJournals.first.publicationCount)
              : 1;
          final maxA = sortedAuthors.isNotEmpty
              ? (rankMode == TrendRankMode.citations
                    ? sortedAuthors.first.totalCitations
                    : sortedAuthors.first.publicationCount)
              : 1;

          final visibleJournals = sortedJournals
              .take(_journalsVisible)
              .toList();
          final visibleAuthors = sortedAuthors.take(_authorsVisible).toList();
          final hasMoreJournals = sortedJournals.length > _journalsVisible;
          final hasMoreAuthors = sortedAuthors.length > _authorsVisible;

          return Column(
            children: [
              // Sticky topic context bar
              if (query.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
                    vertical: AppDimensions.sm,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Topic:',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.md,
                            vertical: AppDimensions.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.shapeSm,
                            ),
                          ),
                          child: Text(
                            query,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      if (yearRange != null) ...[
                        Text(
                          '${yearRange.$1}–${yearRange.$2}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryContainer,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        GestureDetector(
                          onTap: () =>
                              ref.read(trendYearRangeProvider.notifier).state =
                                  null,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ] else
                        Text(
                          '${paginated.items.length} papers',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI row
                      if (paginated.totalCount > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.base,
                            AppDimensions.base,
                            AppDimensions.base,
                            0,
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _KpiBox(
                                    label: 'Total Papers',
                                    value: Formatter.formatCitationCount(
                                      paginated.totalCount,
                                    ),
                                    icon: Icons.article,
                                    iconColor: AppColors.primaryContainer,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                Expanded(
                                  child: _KpiBox(
                                    label: 'Avg. Citations',
                                    value: Formatter.formatDouble(
                                      summary.avgCitations,
                                    ),
                                    icon: Icons.format_quote,
                                    iconColor: AppColors.metricOrange,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                Expanded(
                                  child: _KpiBox(
                                    label: 'Most Active Year',
                                    value:
                                        summary.mostActiveYear?.toString() ??
                                        'N/A',
                                    icon: Icons.calendar_today,
                                    iconColor: AppColors.metricGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Publications per year chart
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.base),
                        child: Container(
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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppDimensions.base,
                                  AppDimensions.base,
                                  AppDimensions.base,
                                  AppDimensions.sm,
                                ),
                                child: Text(
                                  'Publications per year',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 180,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppDimensions.sm,
                                    0,
                                    AppDimensions.sm,
                                    AppDimensions.base,
                                  ),
                                  child: TrendChart(data: trendData),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Rank mode toggle
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.base,
                          0,
                          AppDimensions.base,
                          AppDimensions.sm,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Rank by:',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            SegmentedButton<TrendRankMode>(
                              segments: const [
                                ButtonSegment(
                                  value: TrendRankMode.papers,
                                  label: Text('Papers'),
                                ),
                                ButtonSegment(
                                  value: TrendRankMode.citations,
                                  label: Text('Citations'),
                                ),
                              ],
                              selected: {rankMode},
                              onSelectionChanged: (val) {
                                ref.read(trendRankModeProvider.notifier).state =
                                    val.first;
                              },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Top Journals
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.base,
                          0,
                          AppDimensions.base,
                          AppDimensions.sm,
                        ),
                        child: Text(
                          'Top Journals',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      ...List.generate(
                        visibleJournals.length,
                        (i) => RankedListTile(
                          rank: i + 1,
                          title: visibleJournals[i].name,
                          subtitle: rankMode == TrendRankMode.citations
                              ? '${visibleJournals[i].publicationCount} papers'
                              : '${visibleJournals[i].totalCitations} total citations',
                          count: rankMode == TrendRankMode.citations
                              ? visibleJournals[i].totalCitations
                              : visibleJournals[i].publicationCount,
                          maxCount: maxJ,
                          countLabel: rankMode == TrendRankMode.citations
                              ? 'citations'
                              : null,
                          onTap: () {
                            ref
                                    .read(selectedTopicFilterProvider.notifier)
                                    .state =
                                null;
                            ref.read(searchPageProvider.notifier).state = 1;
                            ref.read(searchQueryProvider.notifier).state =
                                visibleJournals[i].name;
                            ref.read(paperSortOptionProvider.notifier).state =
                                PaperSortOption.relevance;
                            context.go('/search');
                          },
                        ),
                      ),
                      if (hasMoreJournals)
                        _ShowMoreButton(
                          onPressed: () =>
                              setState(() => _journalsVisible += 10),
                        ),

                      // Top Authors
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.base,
                          AppDimensions.base,
                          AppDimensions.base,
                          AppDimensions.sm,
                        ),
                        child: Text(
                          'Top Authors',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      ...List.generate(visibleAuthors.length, (i) {
                        final name = visibleAuthors[i].author.displayName;
                        return RankedListTile(
                          rank: i + 1,
                          title: name,
                          subtitle: rankMode == TrendRankMode.citations
                              ? '${visibleAuthors[i].publicationCount} papers'
                              : '${visibleAuthors[i].totalCitations} total citations',
                          count: rankMode == TrendRankMode.citations
                              ? visibleAuthors[i].totalCitations
                              : visibleAuthors[i].publicationCount,
                          maxCount: maxA,
                          countLabel: rankMode == TrendRankMode.citations
                              ? 'citations'
                              : null,
                          onTap: () {
                            ref
                                    .read(selectedTopicFilterProvider.notifier)
                                    .state =
                                null;
                            ref.read(searchPageProvider.notifier).state = 1;
                            ref.read(searchQueryProvider.notifier).state = name;
                            ref.read(paperSortOptionProvider.notifier).state =
                                PaperSortOption.relevance;
                            context.go('/search');
                          },
                        );
                      }),
                      if (hasMoreAuthors)
                        _ShowMoreButton(
                          onPressed: () =>
                              setState(() => _authorsVisible += 10),
                        ),
                      const SizedBox(height: AppDimensions.xxl),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _KpiBox({
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
          ),
        ],
      ),
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShowMoreButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.base,
        vertical: AppDimensions.sm,
      ),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.expand_more),
          label: const Text('Show more'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryContainer,
            side: const BorderSide(color: AppColors.primaryContainer),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
        ),
      ),
    );
  }
}
