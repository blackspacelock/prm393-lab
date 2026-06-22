import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/journal.dart';
import '../../domain/entities/publication.dart';
import '../providers/journal_providers.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';

class JournalDetailScreen extends ConsumerStatefulWidget {
  final Journal journal;

  const JournalDetailScreen({super.key, required this.journal});

  @override
  ConsumerState<JournalDetailScreen> createState() =>
      _JournalDetailScreenState();
}

class _JournalDetailScreenState extends ConsumerState<JournalDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Reset pagination when entering detail
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(journalPubsPageProvider.notifier).state = 1;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journal = widget.journal;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          journal.displayName,
          style: AppTextStyles.titleLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        children: [
          // Journal info header
          _JournalInfoHeader(journal: journal),
          // Tab bar
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryContainer,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorColor: AppColors.primaryContainer,
              labelStyle: AppTextStyles.labelLarge,
              unselectedLabelStyle: AppTextStyles.labelMedium,
              tabs: const [
                Tab(text: 'Authors'),
                Tab(text: 'Papers'),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AuthorsTab(journal: journal),
                _PapersTab(journal: journal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Journal Info Header ───────────────────────────────────────────────────────

class _JournalInfoHeader extends StatelessWidget {
  final Journal journal;

  const _JournalInfoHeader({required this.journal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.base),
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Journal name prominently displayed
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: AppColors.primaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journal.displayName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (journal.publisher != null) ...[
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        journal.publisher!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (journal.type != null) ...[
                      const SizedBox(height: AppDimensions.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.shapeXs,
                          ),
                        ),
                        child: Text(
                          journal.type!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          // Stats row
          Row(
            children: [
              _InfoChip(
                icon: Icons.article_outlined,
                label:
                    '${Formatter.formatCitationCount(journal.worksCount)} works',
              ),
              const SizedBox(width: AppDimensions.md),
              _InfoChip(
                icon: Icons.format_quote,
                label:
                    '${Formatter.formatCitationCount(journal.citedByCount)} citations',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
        const SizedBox(width: AppDimensions.xs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── Authors Tab ───────────────────────────────────────────────────────────────

class _AuthorsTab extends ConsumerStatefulWidget {
  final Journal journal;

  const _AuthorsTab({required this.journal});

  @override
  ConsumerState<_AuthorsTab> createState() => _AuthorsTabState();
}

class _AuthorsTabState extends ConsumerState<_AuthorsTab>
    with AutomaticKeepAliveClientMixin {
  int _visibleCount = 50;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pubsAsync = ref.watch(journalPublicationsProvider(widget.journal.id));

    return pubsAsync.when(
      loading: () => const ShimmerLoader(),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () =>
            ref.invalidate(journalPublicationsProvider(widget.journal.id)),
      ),
      data: (paginated) {
        // Extract unique authors from publications
        final authorMap = <String, _AuthorInfo>{};
        for (final pub in paginated.items) {
          for (final author in pub.authors) {
            final existing = authorMap[author.id];
            authorMap[author.id] = _AuthorInfo(
              id: author.id,
              name: author.displayName,
              paperCount: (existing?.paperCount ?? 0) + 1,
              publications: [...(existing?.publications ?? []), pub],
            );
          }
        }

        final authors = authorMap.values.toList()
          ..sort((a, b) => b.paperCount.compareTo(a.paperCount));

        if (authors.isEmpty) {
          return const Center(
            child: Text('No authors found for this journal.'),
          );
        }

        final visibleAuthors = authors.take(_visibleCount).toList();
        final hasMore = authors.length > _visibleCount;

        return ListView.builder(
          itemCount: visibleAuthors.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= visibleAuthors.length) {
              // Show more button
              return Padding(
                padding: const EdgeInsets.all(AppDimensions.base),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'Showing $_visibleCount of ${authors.length} authors',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      FilledButton.tonal(
                        onPressed: () {
                          setState(() => _visibleCount += 50);
                        },
                        child: const Text('Show more'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final author = visibleAuthors[index];
            return Column(
              children: [
                if (index > 0)
                  const Divider(
                    height: 1,
                    indent: AppDimensions.base,
                    endIndent: AppDimensions.base,
                    color: AppColors.outlineVariant,
                  ),
                _AuthorTile(
                  rank: index + 1,
                  author: author,
                  onTap: () => _showAuthorPapers(context, author),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAuthorPapers(BuildContext context, _AuthorInfo author) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.shapeMd),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.base,
                vertical: AppDimensions.sm,
              ),
              child: Text(
                '${author.name} — ${author.paperCount} paper${author.paperCount == 1 ? '' : 's'}',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.outlineVariant),
            // Papers list
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: author.publications.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: AppDimensions.base,
                  endIndent: AppDimensions.base,
                  color: AppColors.outlineVariant,
                ),
                itemBuilder: (context, i) {
                  final pub = author.publications[i];
                  return _PublicationTile(
                    publication: pub,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(
                        '/publication/${Uri.encodeComponent(pub.id)}',
                        extra: pub,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorInfo {
  final String id;
  final String name;
  final int paperCount;
  final List<Publication> publications;

  const _AuthorInfo({
    required this.id,
    required this.name,
    required this.paperCount,
    required this.publications,
  });
}

class _AuthorTile extends StatelessWidget {
  final int rank;
  final _AuthorInfo author;
  final VoidCallback? onTap;

  const _AuthorTile({required this.rank, required this.author, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.base,
          vertical: AppDimensions.md,
        ),
        child: Row(
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${author.paperCount} paper${author.paperCount == 1 ? '' : 's'} in this journal',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Papers Tab ────────────────────────────────────────────────────────────────

class _PapersTab extends ConsumerStatefulWidget {
  final Journal journal;

  const _PapersTab({required this.journal});

  @override
  ConsumerState<_PapersTab> createState() => _PapersTabState();
}

class _PapersTabState extends ConsumerState<_PapersTab>
    with AutomaticKeepAliveClientMixin {
  List<Publication> _allPapers = [];
  int _totalCount = 0;
  bool _hasMore = true;
  int _currentPage = 1;
  int _lastProcessedPage = 0;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  void _showMore() {
    setState(() => _isLoadingMore = true);
    _currentPage++;
    ref.read(journalPubsPageProvider.notifier).state = _currentPage;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pubsAsync = ref.watch(journalPublicationsProvider(widget.journal.id));

    pubsAsync.whenData((paginated) {
      if (paginated.page <= _lastProcessedPage && _currentPage != 1) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _totalCount = paginated.totalCount;
          if (paginated.page == 1) {
            _allPapers = List.from(paginated.items);
          } else {
            _allPapers = [..._allPapers, ...paginated.items];
          }
          _lastProcessedPage = paginated.page;
          _hasMore = paginated.hasNextPage;
          _isLoadingMore = false;
        });
      });
    });

    // Reset loading state on error
    if (pubsAsync.hasError && _isLoadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isLoadingMore = false);
      });
    }

    return pubsAsync.when(
      loading: () =>
          _allPapers.isEmpty ? const ShimmerLoader() : _buildPaperList(),
      error: (e, _) => _allPapers.isEmpty
          ? ErrorState(
              message: e.toString(),
              onRetry: () => ref.invalidate(
                journalPublicationsProvider(widget.journal.id),
              ),
            )
          : _buildPaperList(),
      data: (_) => _allPapers.isEmpty
          ? const Center(child: Text('No papers found for this journal.'))
          : _buildPaperList(),
    );
  }

  Widget _buildPaperList() {
    return ListView.builder(
      itemCount: _allPapers.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _allPapers.length) {
          // Show more button with loading effect
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.base),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Showing ${_allPapers.length} of ${Formatter.formatCitationCount(_totalCount)} papers',
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
                          onPressed: _showMore,
                          child: const Text('Show more'),
                        ),
                ],
              ),
            ),
          );
        }

        final pub = _allPapers[index];
        return Column(
          children: [
            if (index > 0)
              const Divider(
                height: 1,
                indent: AppDimensions.base,
                endIndent: AppDimensions.base,
                color: AppColors.outlineVariant,
              ),
            _RankedPublicationTile(
              rank: index + 1,
              publication: pub,
              onTap: () => context.push(
                '/publication/${Uri.encodeComponent(pub.id)}',
                extra: pub,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Rank Badge ────────────────────────────────────────────────────────────────

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
      radius: 16,
      backgroundColor: bg,
      child: Text(
        rank.toString(),
        style: AppTextStyles.labelLarge.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Ranked Publication Tile ───────────────────────────────────────────────────

class _RankedPublicationTile extends StatelessWidget {
  final int rank;
  final Publication publication;
  final VoidCallback? onTap;

  const _RankedPublicationTile({
    required this.rank,
    required this.publication,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                    publication.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Row(
                    children: [
                      if (publication.publicationYear != null) ...[
                        Text(
                          '${publication.publicationYear}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                      ],
                      Icon(
                        Icons.format_quote,
                        size: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppDimensions.xs),
                      Text(
                        '${Formatter.formatCitationCount(publication.citedByCount)} citations',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (publication.authors.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      publication.authors
                              .map((a) => a.displayName)
                              .take(3)
                              .join(', ') +
                          (publication.authors.length > 3 ? ' et al.' : ''),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Publication Tile ───────────────────────────────────────────────────

class _PublicationTile extends StatelessWidget {
  final Publication publication;
  final VoidCallback? onTap;

  const _PublicationTile({required this.publication, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.base,
          vertical: AppDimensions.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              publication.title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppDimensions.xs),
            Row(
              children: [
                if (publication.publicationYear != null) ...[
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Text(
                    '${publication.publicationYear}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                ],
                Icon(
                  Icons.format_quote,
                  size: 12,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  '${publication.citedByCount} citations',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (publication.authors.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.xs),
              Text(
                publication.authors
                        .map((a) => a.displayName)
                        .take(3)
                        .join(', ') +
                    (publication.authors.length > 3 ? ' et al.' : ''),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
