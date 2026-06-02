import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/providers.dart';
import '../widgets/author_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/ranked_list_tile.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/trend_chart.dart';

class TrendAnalysisScreen extends ConsumerWidget {
  const TrendAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubAsync = ref.watch(publicationsProvider);
    final trendData = ref.watch(trendDataProvider);
    final topJournals = ref.watch(topJournalsProvider);
    final topAuthors = ref.watch(topAuthorsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Trend Analysis'),
        backgroundColor: AppColors.surfaceContainerLowest,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
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
        data: (pubs) {
          if (trendData.isEmpty) {
            return const EmptyState(
              icon: Icons.show_chart,
              message: 'Search for a topic to see trends',
            );
          }

          final maxJ =
              topJournals.isNotEmpty ? topJournals.first.publicationCount : 1;
          final maxA =
              topAuthors.isNotEmpty ? topAuthors.first.publicationCount : 1;

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
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.onSurfaceVariant),
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
                              AppDimensions.shapeSm),
                        ),
                        child: Text(
                          query,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pubs.length} papers',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.onSurfaceVariant),
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
                                AppDimensions.shapeMd),
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
                                  style: AppTextStyles.titleLarge
                                      .copyWith(color: AppColors.onSurface),
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
                          style: AppTextStyles.titleLarge
                              .copyWith(color: AppColors.onSurface),
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
                          style: AppTextStyles.titleLarge
                              .copyWith(color: AppColors.onSurface),
                        ),
                      ),
                      ...List.generate(
                        topAuthors.length,
                        (i) {
                          final name =
                              topAuthors[i].author.displayName;
                          return RankedListTile(
                            rank: i + 1,
                            title: name,
                            subtitle:
                                '${topAuthors[i].totalCitations} total citations',
                            count: topAuthors[i].publicationCount,
                            maxCount: maxA,
                            leading: AuthorChip(displayName: name),
                          );
                        },
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
