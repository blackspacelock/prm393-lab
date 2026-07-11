import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/paginated_result.dart';
import '../../domain/entities/publication.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';

/// Papers tab — shows search results only (search bar is in KeywordsScreen).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _scrollController = ScrollController();

  // Accumulated results for pagination
  List<Publication> _allResults = [];
  int _totalCount = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _lastProcessedPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(searchPageProvider.notifier).state = 1;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    ref.read(searchPageProvider.notifier).state = _currentPage;
  }

  void _onDataLoaded(PaginatedResult<Publication> paginated) {
    if (paginated.page <= _lastProcessedPage && _currentPage != 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _totalCount = paginated.totalCount;
        if (paginated.page == 1) {
          _allResults = List.from(paginated.items);
        } else {
          _allResults = [..._allResults, ...paginated.items];
        }
        _lastProcessedPage = paginated.page;
        _hasMore = paginated.hasNextPage;
        _isLoadingMore = false;
      });
    });
  }

  void _searchTopic(String topic) {
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = topic;
    _resetLocal();
  }

  void _searchJournal(String journalName) {
    ref.read(paperSortOptionProvider.notifier).state =
        PaperSortOption.relevance;
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = journalName;
    _resetLocal();
  }

  void _searchAuthor(String authorName) {
    ref.read(paperSortOptionProvider.notifier).state =
        PaperSortOption.relevance;
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = authorName;
    _resetLocal();
  }

  void _resetLocal() {
    setState(() {
      _allResults = [];
      _currentPage = 1;
      _lastProcessedPage = 0;
      _hasMore = true;
      _totalCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final paginatedAsync = ref.watch(paginatedPublicationsProvider);
    final query = ref.watch(searchQueryProvider);
    final sortOption = ref.watch(paperSortOptionProvider);

    // Accumulate data
    paginatedAsync.whenData(_onDataLoaded);

    // Sort the accumulated results
    final sorted = _sortResults(List.from(_allResults), sortOption);

    ref.listen(paginatedPublicationsProvider, (_, next) {
      if (next.hasError) {
        setState(() => _isLoadingMore = false);
      }
    });

    return _buildResults(paginatedAsync, sorted, query);
  }

  Widget _buildResults(
    AsyncValue<PaginatedResult<Publication>> paginatedAsync,
    List<Publication> sorted,
    String query,
  ) {
    if (paginatedAsync.isLoading && _allResults.isEmpty) {
      return const ShimmerLoader();
    }
    if (paginatedAsync.hasError && _allResults.isEmpty) {
      return ErrorState(
        message: paginatedAsync.error.toString(),
        onRetry: () => ref.invalidate(paginatedPublicationsProvider),
      );
    }
    if (sorted.isEmpty && !paginatedAsync.isLoading) {
      return EmptyState(
        icon: Icons.find_in_page,
        message: query.isEmpty
            ? 'Search for publications above'
            : 'No results found for "$query"',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.base,
            AppDimensions.sm,
            AppDimensions.base,
            AppDimensions.xs,
          ),
          child: Text(
            'Showing ${sorted.length} of ${Formatter.formatCitationCount(_totalCount)} results',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: sorted.length + (_hasMore ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == sorted.length) {
                return _buildShowMoreButton();
              }
              final pub = sorted[i];
              return _PaperCard(
                publication: pub,
                rank: i + 1,
                onTopicTap: _searchTopic,
                onJournalTap: _searchJournal,
                onAuthorTap: _searchAuthor,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShowMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.base,
        vertical: AppDimensions.base,
      ),
      child: Center(
        child: Column(
          children: [
            Text(
              'Showing ${_allResults.length} of ${Formatter.formatCitationCount(_totalCount)} results',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            _isLoadingMore
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton.tonal(
                    onPressed: _loadMore,
                    child: const Text('Show more'),
                  ),
          ],
        ),
      ),
    );
  }

  List<Publication> _sortResults(List<Publication> pubs, PaperSortOption sort) {
    switch (sort) {
      case PaperSortOption.relevance:
        break;
      case PaperSortOption.citationCount:
        pubs.sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
      case PaperSortOption.year:
        pubs.sort(
          (a, b) => (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0),
        );
      case PaperSortOption.title:
        pubs.sort((a, b) => a.title.compareTo(b.title));
    }
    return pubs;
  }
}

// ── Paper Card Widget ─────────────────────────────────────────────────────────

class _PaperCard extends StatelessWidget {
  final Publication publication;
  final int rank;
  final ValueChanged<String> onTopicTap;
  final ValueChanged<String> onJournalTap;
  final ValueChanged<String> onAuthorTap;

  const _PaperCard({
    required this.publication,
    required this.rank,
    required this.onTopicTap,
    required this.onJournalTap,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('publicationResult-$rank'),
      onTap: () => context.push(
        '/publication/${Uri.encodeComponent(publication.id)}',
        extra: publication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.base,
          vertical: AppDimensions.md,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RankBadge(rank: rank),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Text(
                    publication.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.xs,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
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
                            Text(
                              'Citations ',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.citationChipText,
                              ),
                            ),
                            Text(
                              Formatter.formatCitationCount(
                                publication.citedByCount,
                              ),
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.citationChipText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (publication.publicationYear != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.md,
                            vertical: AppDimensions.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.shapeXs,
                            ),
                          ),
                          child: Text(
                            'Year ${publication.publicationYear}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (publication.journalName != null) ...[
                    const SizedBox(height: AppDimensions.sm),
                    _TopicChip(
                      topic: publication.journalName!,
                      onTap: () => onJournalTap(publication.journalName!),
                      isJournal: true,
                    ),
                  ],
                  if (publication.authors.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Wrap(
                      spacing: AppDimensions.xs,
                      runSpacing: AppDimensions.xs,
                      children: publication.authors.map((a) {
                        return _TopicChip(
                          topic: a.displayName,
                          onTap: () => onAuthorTap(a.displayName),
                        );
                      }).toList(),
                    ),
                  ],
                  if (publication.concepts.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: AppDimensions.xs,
                      runSpacing: AppDimensions.xs,
                      children: publication.concepts.map((topic) {
                        return _TopicChip(
                          topic: topic,
                          onTap: () => onTopicTap(topic),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String topic;
  final VoidCallback onTap;
  final bool isJournal;

  const _TopicChip({
    required this.topic,
    required this.onTap,
    this.isJournal = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: isJournal
              ? AppColors.citationChipBg
              : AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isJournal) ...[
              Icon(
                Icons.library_books,
                size: 12,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                topic,
                style:
                    (isJournal
                            ? AppTextStyles.bodySmall
                            : AppTextStyles.labelSmall)
                        .copyWith(
                          fontWeight: isJournal ? FontWeight.w700 : null,
                          fontStyle: isJournal ? FontStyle.italic : null,
                          color: isJournal
                              ? AppColors.primaryContainer
                              : AppColors.onSecondaryContainer,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
