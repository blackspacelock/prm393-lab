import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/journal.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../providers/journal_providers.dart';
import '../providers/providers.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';

// ── Sort enums ────────────────────────────────────────────────────────────────

enum _AuthorSort { papers, citations }

enum _PaperSort { citations, year }

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

  // Shared topic filter
  String _topicFilter = '';

  // Per-tab sort
  _AuthorSort _authorSort = _AuthorSort.papers;
  _PaperSort _paperSort = _PaperSort.citations;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(journalPubsPageProvider.notifier).state = 1;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTopicFilterSheet() {
    showDialog(
      context: context,
      builder: (_) => _TopicFilterDialog(
        currentFilter: _topicFilter,
        onSelect: (value) {
          setState(() => _topicFilter = value);
          Navigator.of(context).pop();
        },
        onClear: () {
          setState(() => _topicFilter = '');
          Navigator.of(context).pop();
        },
      ),
    );
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
          _JournalInfoHeader(journal: journal),
          // Topic filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.base,
              AppDimensions.sm,
              AppDimensions.base,
              AppDimensions.sm,
            ),
            child: GestureDetector(
              onTap: _showTopicFilterSheet,
              child: Container(
                width: double.infinity,
                height: 40,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                decoration: BoxDecoration(
                  color: _topicFilter.isNotEmpty
                      ? AppColors.primaryContainer.withValues(alpha: 0.12)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
                  border: Border.all(
                    color: _topicFilter.isNotEmpty
                        ? AppColors.primaryContainer
                        : AppColors.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 16,
                      color: _topicFilter.isNotEmpty
                          ? AppColors.primaryContainer
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        _topicFilter.isNotEmpty
                            ? 'Topic: $_topicFilter'
                            : 'Filter by Topic',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: _topicFilter.isNotEmpty
                              ? AppColors.primaryContainer
                              : AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_topicFilter.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _topicFilter = ''),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                      )
                    else
                      const Icon(
                        Icons.expand_more,
                        size: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
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
                _AuthorsTab(
                  journal: journal,
                  topicFilter: _topicFilter,
                  sort: _authorSort,
                  onSortChanged: (s) => setState(() => _authorSort = s),
                ),
                _PapersTab(
                  journal: journal,
                  topicFilter: _topicFilter,
                  sort: _paperSort,
                  onSortChanged: (s) => setState(() => _paperSort = s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Topic Filter Dialog ────────────────────────────────────────────────────────

class _TopicFilterDialog extends ConsumerStatefulWidget {
  final String currentFilter;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  const _TopicFilterDialog({
    required this.currentFilter,
    required this.onSelect,
    required this.onClear,
  });

  @override
  ConsumerState<_TopicFilterDialog> createState() => _TopicFilterDialogState();
}

class _TopicFilterDialogState extends ConsumerState<_TopicFilterDialog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentFilter;
    _query = widget.currentFilter;
    _controller.addListener(() {
      final text = _controller.text.trim();
      if (text != _query) {
        setState(() => _query = text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(
                  Icons.filter_list,
                  size: 20,
                  color: AppColors.primaryContainer,
                ),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  'Filter by Topic',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Enter a Domain, Field, Subfield, or Topic keyword:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            // Search field
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Machine Learning, Biology...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isNotEmpty) widget.onSelect(trimmed);
              },
            ),
            // Suggestions (scrollable, constrained height)
            if (_query.length >= 2) _buildSuggestions(),
            // Action buttons
            const SizedBox(height: AppDimensions.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.currentFilter.isNotEmpty)
                  TextButton(
                    onPressed: widget.onClear,
                    child: const Text('Clear'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppDimensions.sm),
                FilledButton(
                  onPressed: () {
                    final trimmed = _controller.text.trim();
                    if (trimmed.isNotEmpty) widget.onSelect(trimmed);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final autocompleteAsync = ref.watch(topicAutocompleteProvider(_query));

    return autocompleteAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppDimensions.sm),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        // Show max 5 suggestions to keep dialog compact
        final shown = items.take(5).toList();
        return Padding(
          padding: const EdgeInsets.only(top: AppDimensions.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: shown.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = shown[i];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    _levelIcon(item.level),
                    size: 16,
                    color: _levelColor(item.level),
                  ),
                  title: Text(
                    item.displayName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _levelColor(item.level).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.shapeXs,
                      ),
                    ),
                    child: Text(
                      item.levelLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _levelColor(item.level),
                        fontSize: 9,
                      ),
                    ),
                  ),
                  onTap: () => widget.onSelect(item.displayName),
                );
              },
            ),
          ),
        );
      },
    );
  }

  IconData _levelIcon(TopicLevel level) => switch (level) {
    TopicLevel.domain => Icons.public,
    TopicLevel.field => Icons.category,
    TopicLevel.subfield => Icons.folder_outlined,
    TopicLevel.topic => Icons.topic_outlined,
    TopicLevel.journal => Icons.library_books,
    TopicLevel.author => Icons.person,
  };

  Color _levelColor(TopicLevel level) => switch (level) {
    TopicLevel.domain => AppColors.metricPurple,
    TopicLevel.field => AppColors.primaryContainer,
    TopicLevel.subfield => AppColors.metricOrange,
    TopicLevel.topic => AppColors.metricGreen,
    TopicLevel.journal => AppColors.primaryContainer,
    TopicLevel.author => AppColors.metricPurple,
  };
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
  final String topicFilter;
  final _AuthorSort sort;
  final ValueChanged<_AuthorSort> onSortChanged;

  const _AuthorsTab({
    required this.journal,
    required this.topicFilter,
    required this.sort,
    required this.onSortChanged,
  });

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
        // Filter by topic keyword
        var pubs = paginated.items;
        if (widget.topicFilter.isNotEmpty) {
          final filter = widget.topicFilter.toLowerCase();
          pubs = pubs
              .where(
                (p) => p.concepts.any((c) => c.toLowerCase().contains(filter)),
              )
              .toList();
        }

        // Extract unique authors
        final authorMap = <String, _AuthorInfo>{};
        for (final pub in pubs) {
          for (final author in pub.authors) {
            final existing = authorMap[author.id];
            final totalCitations =
                (existing?._totalCitations ?? 0) + pub.citedByCount;
            authorMap[author.id] = _AuthorInfo(
              id: author.id,
              name: author.displayName,
              paperCount: (existing?.paperCount ?? 0) + 1,
              publications: [...(existing?.publications ?? []), pub],
              totalCitations: totalCitations,
            );
          }
        }

        var authors = authorMap.values.toList();
        // Sort
        switch (widget.sort) {
          case _AuthorSort.papers:
            authors.sort((a, b) => b.paperCount.compareTo(a.paperCount));
          case _AuthorSort.citations:
            authors.sort(
              (a, b) => b._totalCitations.compareTo(a._totalCitations),
            );
        }

        if (authors.isEmpty) {
          return const Center(child: Text('No authors found for this filter.'));
        }

        final visibleAuthors = authors.take(_visibleCount).toList();
        final hasMore = authors.length > _visibleCount;

        return Column(
          children: [
            // Sort dropdown
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.sm,
                AppDimensions.base,
                AppDimensions.xs,
              ),
              child: _SortRow<_AuthorSort>(
                value: widget.sort,
                items: const [
                  (_AuthorSort.papers, 'Sort: Papers'),
                  (_AuthorSort.citations, 'Sort: Citations'),
                ],
                onChanged: widget.onSortChanged,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: visibleAuthors.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= visibleAuthors.length) {
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
                              onPressed: () =>
                                  setState(() => _visibleCount += 50),
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
              ),
            ),
          ],
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

// ── Author Info model ─────────────────────────────────────────────────────────

class _AuthorInfo {
  final String id;
  final String name;
  final int paperCount;
  final List<Publication> publications;
  final int _totalCitations;

  const _AuthorInfo({
    required this.id,
    required this.name,
    required this.paperCount,
    required this.publications,
    int totalCitations = 0,
  }) : _totalCitations = totalCitations;
}

// ── Papers Tab ────────────────────────────────────────────────────────────────

class _PapersTab extends ConsumerStatefulWidget {
  final Journal journal;
  final String topicFilter;
  final _PaperSort sort;
  final ValueChanged<_PaperSort> onSortChanged;

  const _PapersTab({
    required this.journal,
    required this.topicFilter,
    required this.sort,
    required this.onSortChanged,
  });

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
    // Apply topic filter
    var papers = _allPapers;
    if (widget.topicFilter.isNotEmpty) {
      final filter = widget.topicFilter.toLowerCase();
      papers = papers
          .where((p) => p.concepts.any((c) => c.toLowerCase().contains(filter)))
          .toList();
    }

    // Apply sort
    switch (widget.sort) {
      case _PaperSort.citations:
        papers = List.from(papers)
          ..sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
      case _PaperSort.year:
        papers = List.from(papers)
          ..sort(
            (a, b) =>
                (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0),
          );
    }

    final hasMoreAfterFilter = widget.topicFilter.isEmpty && _hasMore;

    return Column(
      children: [
        // Sort dropdown
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.base,
            AppDimensions.sm,
            AppDimensions.base,
            AppDimensions.xs,
          ),
          child: _SortRow<_PaperSort>(
            value: widget.sort,
            items: const [
              (_PaperSort.citations, 'Sort: Citations'),
              (_PaperSort.year, 'Sort: Year'),
            ],
            onChanged: widget.onSortChanged,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: papers.length + (hasMoreAfterFilter ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= papers.length) {
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

              final pub = papers[index];
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
          ),
        ),
      ],
    );
  }
}

// ── Sort Row (generic dropdown) ───────────────────────────────────────────────

class _SortRow<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  const _SortRow({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: 0,
          ),
          filled: true,
          fillColor: AppColors.surfaceContainer,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
            borderSide: BorderSide.none,
          ),
        ),
        icon: const Icon(Icons.expand_more, size: 18),
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item.$1,
            child: Text(
              item.$2,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// ── Author Tile ───────────────────────────────────────────────────────────────

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
                    '${author.paperCount} papers \u2022 ${Formatter.formatCitationCount(author._totalCitations)} citations',
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

// ── Publication Tile (for bottom sheet) ───────────────────────────────────────

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
          ],
        ),
      ),
    );
  }
}
