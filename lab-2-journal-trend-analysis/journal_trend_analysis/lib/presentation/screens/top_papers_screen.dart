import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';

class TopPapersScreen extends ConsumerStatefulWidget {
  const TopPapersScreen({super.key});

  @override
  ConsumerState<TopPapersScreen> createState() => _TopPapersScreenState();
}

class _TopPapersScreenState extends ConsumerState<TopPapersScreen> {
  final _scrollController = ScrollController();
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 300;
      if (show != _showFab) {
        setState(() => _showFab = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pubAsync = ref.watch(publicationsProvider);
    final sorted = ref.watch(sortedPublicationsProvider);
    final sortOption = ref.watch(paperSortOptionProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Most Influential Papers'),
        backgroundColor: AppColors.surfaceContainerLowest,
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.primaryContainer,
              onPressed: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: const Icon(
                Icons.keyboard_arrow_up,
                color: AppColors.onPrimary,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: pubAsync.when(
        loading: () => const ShimmerLoader(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(paginatedPublicationsProvider),
        ),
        data: (_) {
          if (sorted.isEmpty) {
            return const EmptyState(
              icon: Icons.emoji_events,
              message: 'Search for a topic to see top papers',
            );
          }

          return Column(
            children: [
              // Subtitle row
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  AppDimensions.sm,
                  AppDimensions.base,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ranked by citation count · $query',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              // Sort filter bar
              Container(
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
                    vertical: AppDimensions.sm,
                  ),
                  child: Row(
                    children: PaperSortOption.values.map((opt) {
                      final selected = sortOption == opt;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppDimensions.sm),
                        child: ChoiceChip(
                          label: Text(_label(opt)),
                          selected: selected,
                          onSelected: (_) =>
                              ref.read(paperSortOptionProvider.notifier).state =
                                  opt,
                          backgroundColor: AppColors.surfaceContainerLowest,
                          selectedColor: AppColors.secondaryContainer,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            color: selected
                                ? AppColors.onSecondaryContainer
                                : AppColors.onSurface,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primaryContainer
                                : AppColors.outlineVariant,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.shapeSm,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Paper list
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: AppDimensions.base,
                    endIndent: AppDimensions.base,
                    color: AppColors.outlineVariant,
                  ),
                  itemBuilder: (_, i) {
                    final pub = sorted[i];
                    final rank = i + 1;
                    final firstAuthor = pub.authors.isNotEmpty
                        ? pub.authors.first.displayName
                        : null;
                    final authorLabel = firstAuthor != null
                        ? (pub.authors.length > 1
                              ? '$firstAuthor et al.'
                              : firstAuthor)
                        : null;

                    return InkWell(
                      onTap: () => context.push(
                        '/publication/${Uri.encodeComponent(pub.id)}',
                        extra: pub,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.base,
                          vertical: AppDimensions.md,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RankBadge(rank: rank),
                            const SizedBox(width: AppDimensions.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pub.title,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  if (pub.journalName != null) ...[
                                    const SizedBox(height: AppDimensions.xs),
                                    Text(
                                      pub.journalName!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  if (authorLabel != null) ...[
                                    const SizedBox(height: AppDimensions.xs),
                                    Text(
                                      authorLabel,
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppDimensions.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.citationChipBg,
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.shapeXs,
                                    ),
                                  ),
                                  child: Text(
                                    Formatter.formatCitationCount(
                                      pub.citedByCount,
                                    ),
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: AppColors.citationChipText,
                                    ),
                                  ),
                                ),
                                if (pub.publicationYear != null) ...[
                                  const SizedBox(height: AppDimensions.xs),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppDimensions.sm,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.shapeXs,
                                      ),
                                    ),
                                    child: Text(
                                      pub.publicationYear.toString(),
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _label(PaperSortOption opt) => switch (opt) {
    PaperSortOption.relevance => 'Relevance',
    PaperSortOption.citationCount => 'Citation count',
    PaperSortOption.year => 'Year',
    PaperSortOption.title => 'A–Z',
  };
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (AppColors.rankGold, AppColors.rankGoldText),
      2 => (AppColors.rankSilver, AppColors.rankSilverText),
      3 => (AppColors.rankBronze, AppColors.rankBronzeText),
      _ => (AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
    };

    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Text(
        rank.toString(),
        style: AppTextStyles.titleMedium.copyWith(color: fg),
      ),
    );
  }
}
