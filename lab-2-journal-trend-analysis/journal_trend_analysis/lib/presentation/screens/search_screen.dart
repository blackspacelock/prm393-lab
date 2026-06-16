import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/paginated_result.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/topic_cascade_dialog.dart';

const _suggestions = [
  'AI',
  'Software Engineering',
  'Data Science',
  'Cybersecurity',
  'IoT',
  'Blockchain',
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _showAutocomplete = false;
  String _autocompleteQuery = '';

  // Accumulated results for infinite scroll
  List<Publication> _allResults = [];
  int _totalCount = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _lastProcessedPage = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showAutocomplete = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final text = _controller.text.trim();
      if (text.length >= 2 && _focusNode.hasFocus) {
        setState(() {
          _showAutocomplete = true;
          _autocompleteQuery = text;
        });
      } else {
        setState(() => _showAutocomplete = false);
      }
    });
  }

  void _submitFreeText(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _showAutocomplete = false;
      _allResults = [];
      _currentPage = 1;
      _lastProcessedPage = 0;
      _hasMore = true;
      _totalCount = 0;
    });
    _focusNode.unfocus();
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = trimmed;
  }

  void _selectTopicItem(TopicHierarchyItem item) {
    setState(() {
      _showAutocomplete = false;
      _allResults = [];
      _currentPage = 1;
      _lastProcessedPage = 0;
      _hasMore = true;
      _totalCount = 0;
    });
    _focusNode.unfocus();
    _controller.text = item.displayName;
    ref.read(searchQueryProvider.notifier).state = item.displayName;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(selectedTopicFilterProvider.notifier).state = item;
  }

  void _openCascadeFilter() async {
    final result = await showDialog<TopicHierarchyItem>(
      context: context,
      builder: (_) => const TopicCascadeDialog(),
    );
    if (result != null) {
      _selectTopicItem(result);
    }
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    ref.read(searchPageProvider.notifier).state = _currentPage;
  }

  void _onDataLoaded(PaginatedResult<Publication> paginated) {
    // Only process if this is a new page we haven't seen yet
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
    _controller.text = topic;
    _submitFreeText(topic);
  }

  @override
  Widget build(BuildContext context) {
    final paginatedAsync = ref.watch(paginatedPublicationsProvider);
    final query = ref.watch(searchQueryProvider);
    final topicFilter = ref.watch(selectedTopicFilterProvider);
    final sortOption = ref.watch(paperSortOptionProvider);

    // When data arrives, accumulate
    paginatedAsync.whenData(_onDataLoaded);

    // Sort the accumulated results
    final sorted = _sortResults(List.from(_allResults), sortOption);

    ref.listen(paginatedPublicationsProvider, (_, next) {
      if (next.hasError) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => ref.invalidate(paginatedPublicationsProvider),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Trend Analyzer'),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: const Icon(Icons.analytics, color: AppColors.onSurfaceVariant),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Browse Topics',
            onPressed: _openCascadeFilter,
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Sort & Filter',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildFilterDrawer(),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.base,
              AppDimensions.md,
              AppDimensions.base,
              0,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search research topics…',
                hintStyle: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _allResults = [];
                            _totalCount = 0;
                          });
                          ref.read(searchQueryProvider.notifier).state = '';
                          ref.read(selectedTopicFilterProvider.notifier).state =
                              null;
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
                  borderSide: const BorderSide(
                    color: AppColors.primaryContainer,
                    width: 2,
                  ),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _submitFreeText,
            ),
          ),

          // Autocomplete
          if (_showAutocomplete) _buildAutocompleteSuggestions(),

          // Active topic filter chip
          if (topicFilter != null && !_showAutocomplete)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.sm,
                AppDimensions.base,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(
                    _levelIcon(topicFilter.level),
                    size: 16,
                    color: AppColors.primaryContainer,
                  ),
                  label: Text(
                    '${topicFilter.displayName} (${topicFilter.levelLabel})',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    ref.read(selectedTopicFilterProvider.notifier).state = null;
                    ref.read(searchQueryProvider.notifier).state = '';
                    _controller.clear();
                    setState(() {
                      _allResults = [];
                      _totalCount = 0;
                    });
                  },
                  backgroundColor: AppColors.secondaryContainer,
                  side: BorderSide.none,
                ),
              ),
            ),

          // Quick suggestion chips
          if (!_showAutocomplete) ...[
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.base,
                ),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppDimensions.sm),
                itemBuilder: (_, i) {
                  final selected =
                      query == _suggestions[i] && topicFilter == null;
                  return FilterChip(
                    label: Text(_suggestions[i]),
                    selected: selected,
                    onSelected: (_) {
                      _controller.text = _suggestions[i];
                      _submitFreeText(_suggestions[i]);
                    },
                    backgroundColor: AppColors.surfaceContainerHighest,
                    selectedColor: AppColors.secondaryContainer,
                    labelStyle: AppTextStyles.labelLarge.copyWith(
                      color: selected
                          ? AppColors.onSecondaryContainer
                          : AppColors.onSurfaceVariant,
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
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
          ],

          // Results
          if (!_showAutocomplete)
            Expanded(child: _buildResults(paginatedAsync, sorted, query)),
        ],
      ),
    );
  }

  Widget _buildResults(
    AsyncValue<PaginatedResult<Publication>> paginatedAsync,
    List<Publication> sorted,
    String query,
  ) {
    // Initial loading
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
        actionLabel: query.isNotEmpty ? 'Clear' : null,
        onAction: query.isNotEmpty
            ? () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).state = '';
                ref.read(selectedTopicFilterProvider.notifier).state = null;
                setState(() {
                  _allResults = [];
                  _totalCount = 0;
                });
              }
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results info
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.base,
            right: AppDimensions.base,
            bottom: AppDimensions.xs,
          ),
          child: Text(
            "Showing ${sorted.length} of ${Formatter.formatCitationCount(_totalCount)} results",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Paper list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: sorted.length + (_hasMore ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == sorted.length) {
                // "Read more" button
                return _buildReadMoreButton();
              }
              final pub = sorted[i];
              return _PaperCard(
                publication: pub,
                rank: i + 1,
                onTopicTap: _searchTopic,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.base,
        vertical: AppDimensions.base,
      ),
      child: Center(
        child: _isLoadingMore
            ? const Padding(
                padding: EdgeInsets.all(AppDimensions.base),
                child: CircularProgressIndicator(),
              )
            : OutlinedButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Read more'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryContainer,
                  side: const BorderSide(color: AppColors.primaryContainer),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAutocompleteSuggestions() {
    final autocompleteAsync = ref.watch(
      topicAutocompleteProvider(_autocompleteQuery),
    );

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.sm,
        AppDimensions.base,
        0,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: autocompleteAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppDimensions.base),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) {
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppDimensions.base),
              child: Text(
                'No matching topics. Press Enter to search as text.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: AppDimensions.base,
              endIndent: AppDimensions.base,
            ),
            itemBuilder: (_, i) {
              final item = items[i];
              return ListTile(
                dense: true,
                leading: Icon(
                  _levelIcon(item.level),
                  size: 18,
                  color: _levelColor(item.level),
                ),
                title: Text(
                  item.displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _levelColor(item.level).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
                  ),
                  child: Text(
                    item.levelLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _levelColor(item.level),
                    ),
                  ),
                ),
                onTap: () => _selectTopicItem(item),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      child: SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final currentSort = ref.watch(paperSortOptionProvider);
            return Padding(
              padding: const EdgeInsets.all(AppDimensions.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Sort & Filter',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.base),
                  Text(
                    'Sort by',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  ...PaperSortOption.values.map((opt) {
                    return RadioListTile<PaperSortOption>(
                      title: Text(
                        _sortLabel(opt),
                        style: AppTextStyles.bodyMedium,
                      ),
                      value: opt,
                      groupValue: currentSort,
                      activeColor: AppColors.primaryContainer,
                      dense: true,
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(paperSortOptionProvider.notifier).state =
                              val;
                          // Re-sort existing accumulated results
                          setState(() {});
                        }
                      },
                    );
                  }),
                  const Divider(height: 32),
                  Text(
                    'Browse by Category',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openCascadeFilter();
                    },
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text('Browse Topic Hierarchy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryContainer,
                      side: const BorderSide(color: AppColors.primaryContainer),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Publication> _sortResults(List<Publication> pubs, PaperSortOption sort) {
    switch (sort) {
      case PaperSortOption.citationCount:
        pubs.sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
      case PaperSortOption.year:
        pubs.sort(
          (a, b) => (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0),
        );
      case PaperSortOption.relevance:
        break;
      case PaperSortOption.title:
        pubs.sort((a, b) => a.title.compareTo(b.title));
    }
    return pubs;
  }

  String _sortLabel(PaperSortOption opt) => switch (opt) {
    PaperSortOption.citationCount => 'Most Cited',
    PaperSortOption.year => 'Newest First',
    PaperSortOption.relevance => 'Relevance',
    PaperSortOption.title => 'A–Z (Title)',
  };

  IconData _levelIcon(TopicLevel level) => switch (level) {
    TopicLevel.domain => Icons.public,
    TopicLevel.field => Icons.category,
    TopicLevel.subfield => Icons.folder_outlined,
    TopicLevel.topic => Icons.topic_outlined,
  };

  Color _levelColor(TopicLevel level) => switch (level) {
    TopicLevel.domain => AppColors.metricPurple,
    TopicLevel.field => AppColors.primaryContainer,
    TopicLevel.subfield => AppColors.metricOrange,
    TopicLevel.topic => AppColors.metricGreen,
  };
}

// ── Paper Card Widget ─────────────────────────────────────────────────────────

class _PaperCard extends StatelessWidget {
  final Publication publication;
  final int rank;
  final ValueChanged<String> onTopicTap;

  const _PaperCard({
    required this.publication,
    required this.rank,
    required this.onTopicTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            // Paper title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RankBadge(rank: rank),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Text(
                    publication.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),

            // Metadata section (indented under rank badge)
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Journal — full name, no truncation
                  if (publication.journalName != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Journal: ',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            publication.journalName!,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              color: AppColors.primaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Authors — clickable with hover
                  if (publication.authors.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Authors: ',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: AppDimensions.xs,
                            runSpacing: AppDimensions.xs,
                            children: publication.authors.map((a) {
                              return _TopicChip(
                                topic: a.displayName,
                                onTap: () => onTopicTap(a.displayName),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Citations + Year row
                  const SizedBox(height: AppDimensions.sm),
                  Row(
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Citations ',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.citationChipText,
                              ),
                            ),
                            Text(
                              Formatter.formatCitationCount(
                                publication.citedByCount,
                              ),
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.citationChipText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (publication.publicationYear != null) ...[
                        const SizedBox(width: AppDimensions.sm),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Year ',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                publication.publicationYear.toString(),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Research Topics — all, with hover effect
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

/// A topic chip with hover/press visual feedback.
class _TopicChip extends StatefulWidget {
  final String topic;
  final VoidCallback onTap;

  const _TopicChip({required this.topic, required this.onTap});

  @override
  State<_TopicChip> createState() => _TopicChipState();
}

class _TopicChipState extends State<_TopicChip> {
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryContainer.withValues(alpha: 0.2)
                : AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
            border: Border.all(
              color: isActive ? AppColors.primaryContainer : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            widget.topic,
            style: AppTextStyles.labelSmall.copyWith(
              color: isActive
                  ? AppColors.primaryContainer
                  : AppColors.onSecondaryContainer,
            ),
          ),
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
