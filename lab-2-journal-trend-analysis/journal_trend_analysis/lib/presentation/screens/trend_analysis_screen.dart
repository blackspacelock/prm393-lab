import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/usecases/get_trend_data.dart';
import '../providers/providers.dart';
import '../widgets/author_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/ranked_list_tile.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/trend_chart.dart';

/// Provider for the selected year range filter on the Trends page.
/// Stores (startYear, endYear) pair.
final trendYearRangeProvider = StateProvider<(int, int)?>((_) => null);

/// Filtered trend data based on selected year range.
final filteredTrendDataProvider = Provider<List<YearTrendData>>((ref) {
  final trendData = ref.watch(trendDataProvider);
  final yearRange = ref.watch(trendYearRangeProvider);
  if (yearRange == null) return trendData;
  return trendData
      .where((d) => d.year >= yearRange.$1 && d.year <= yearRange.$2)
      .toList();
});

class TrendAnalysisScreen extends ConsumerWidget {
  const TrendAnalysisScreen({super.key});

  void _showYearRangeDialog(BuildContext context, WidgetRef ref) {
    final trendData = ref.read(trendDataProvider);
    final currentRange = ref.read(trendYearRangeProvider);
    final now = DateTime.now().year;

    // Determine available year range from data
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
                  // Start year
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
                  // End year
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
  Widget build(BuildContext context, WidgetRef ref) {
    final pubAsync = ref.watch(paginatedPublicationsProvider);
    final trendData = ref.watch(filteredTrendDataProvider);
    final topJournals = ref.watch(topJournalsProvider);
    final topAuthors = ref.watch(topAuthorsProvider);
    final query = ref.watch(searchQueryProvider);
    final yearRange = ref.watch(trendYearRangeProvider);

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
            onPressed: () => _showYearRangeDialog(context, ref),
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

          final maxJ = topJournals.isNotEmpty
              ? topJournals.first.publicationCount
              : 1;
          final maxA = topAuthors.isNotEmpty
              ? topAuthors.first.publicationCount
              : 1;

          return Column(
            children: [
              // Sticky topic context bar
              if (query.isNotEmpty)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
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
                      Container(
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
                      const Spacer(),
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
                      // Bar chart card
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
                        topJournals.length,
                        (i) => RankedListTile(
                          rank: i + 1,
                          title: topJournals[i].name,
                          subtitle:
                              '${topJournals[i].totalCitations} total citations',
                          count: topJournals[i].publicationCount,
                          maxCount: maxJ,
                        ),
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
                      ...List.generate(topAuthors.length, (i) {
                        final name = topAuthors[i].author.displayName;
                        return RankedListTile(
                          rank: i + 1,
                          title: name,
                          subtitle:
                              '${topAuthors[i].totalCitations} total citations',
                          count: topAuthors[i].publicationCount,
                          maxCount: maxA,
                          leading: AuthorChip(displayName: name),
                        );
                      }),
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
