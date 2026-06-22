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

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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
        // Delay hiding autocomplete to allow tap events on suggestions to fire first
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_focusNode.hasFocus) {
            setState(() => _showAutocomplete = false);
          }
        });
      }
    });
    // Reset page to 1 when entering the screen to avoid stale accumulated state
    // after navigating away and back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(searchPageProvider.notifier).state = 1;
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
    _debounce?.cancel();
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
    _debounce?.cancel(); // Cancel any debounce triggered by text change
    // Set topic filter first, then query — provider prioritizes topicFilter
    ref.read(selectedTopicFilterProvider.notifier).state = item;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = item.displayName;
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

  void _searchJournal(String journalName) {
    ref.read(paperSortOptionProvider.notifier).state =
        PaperSortOption.relevance;
    _controller.text = journalName;
    _submitFreeText(journalName);
  }

  void _searchAuthor(String authorName) {
    ref.read(paperSortOptionProvider.notifier).state =
        PaperSortOption.relevance;
    _controller.text = authorName;
    _submitFreeText(authorName);
  }

  @override
  Widget build(BuildContext context) {
    final paginatedAsync = ref.watch(paginatedPublicationsProvider);
    final query = ref.watch(searchQueryProvider);
    final topicFilter = ref.watch(selectedTopicFilterProvider);
    final sortOption = ref.watch(paperSortOptionProvider);

    // Sync controller text with query provider (e.g. when navigated from dashboard)
    if (_controller.text != query && !_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text != query && !_focusNode.hasFocus) {
          _controller.text = query;
          _debounce?.cancel();
        }
      });
    }

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
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      drawer: _buildTopicHierarchyDrawer(),
      endDrawer: _buildFilterDrawer(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
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
                            ref
                                    .read(selectedTopicFilterProvider.notifier)
                                    .state =
                                null;
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.shapeFull,
                    ),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.shapeFull,
                    ),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.shapeFull,
                    ),
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

            // Topic Hierarchy & Filter buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.sm,
                AppDimensions.base,
                0,
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.account_tree_outlined, size: 16),
                    label: const Text('Topic Hierarchy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      side: const BorderSide(color: AppColors.outlineVariant),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: AppDimensions.sm,
                      ),
                      textStyle: AppTextStyles.labelMedium,
                      shape: const StadiumBorder(),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Builder(
                    builder: (ctx) => OutlinedButton.icon(
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Filter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: AppDimensions.sm,
                        ),
                        textStyle: AppTextStyles.labelMedium,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
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
                      ref.read(selectedTopicFilterProvider.notifier).state =
                          null;
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

            if (!_showAutocomplete) const SizedBox(height: AppDimensions.sm),

            // Results
            if (!_showAutocomplete)
              Expanded(child: _buildResults(paginatedAsync, sorted, query)),
          ],
        ),
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
                onJournalTap: _searchJournal,
                onAuthorTap: _searchAuthor,
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
        error: (_, _) => const SizedBox.shrink(),
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
            separatorBuilder: (_, _) => const Divider(
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

  Widget _buildTopicHierarchyDrawer() {
    return Drawer(
      child: SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.base),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_tree_outlined,
                        size: 20,
                        color: AppColors.primaryContainer,
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Text(
                        'Topic Hierarchy',
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
                ),
                const Divider(height: 1),
                // Topic hierarchy tree
                Expanded(
                  child: _TopicHierarchyTree(
                    onSelect: (item) {
                      Navigator.of(context).pop();
                      _selectTopicItem(item);
                    },
                  ),
                ),
              ],
            );
          },
        ),
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
                        'Filter',
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
                  RadioGroup<PaperSortOption>(
                    groupValue: currentSort,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(paperSortOptionProvider.notifier).state = val;
                        setState(() {});
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: PaperSortOption.values.map((opt) {
                        return RadioListTile<PaperSortOption>(
                          title: Text(
                            _sortLabel(opt),
                            style: AppTextStyles.bodyMedium,
                          ),
                          value: opt,
                          activeColor: AppColors.primaryContainer,
                          dense: true,
                        );
                      }).toList(),
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

  String _sortLabel(PaperSortOption opt) => switch (opt) {
    PaperSortOption.relevance => 'Relevance',
    PaperSortOption.citationCount => 'Most Cited',
    PaperSortOption.year => 'Newest First',
    PaperSortOption.title => 'A–Z (Title)',
  };

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

// ── Topic Hierarchy Tree Widget ───────────────────────────────────────────────

class _TopicHierarchyTree extends ConsumerStatefulWidget {
  final ValueChanged<TopicHierarchyItem> onSelect;

  const _TopicHierarchyTree({required this.onSelect});

  @override
  ConsumerState<_TopicHierarchyTree> createState() =>
      _TopicHierarchyTreeState();
}

class _TopicHierarchyTreeState extends ConsumerState<_TopicHierarchyTree> {
  String? _expandedDomainId;
  String? _expandedFieldId;
  String? _expandedSubfieldId;

  @override
  Widget build(BuildContext context) {
    final domainsAsync = ref.watch(domainsProvider);

    return domainsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Text('Error: $e'),
        ),
      ),
      data: (domains) {
        if (domains.isEmpty) {
          return const Center(child: Text('No topics available'));
        }
        return ListView.builder(
          itemCount: domains.length,
          itemBuilder: (_, i) => _buildDomainTile(domains[i]),
        );
      },
    );
  }

  Widget _buildDomainTile(TopicHierarchyItem domain) {
    final isExpanded = _expandedDomainId == domain.id;
    return Column(
      children: [
        ListTile(
          leading: const Icon(
            Icons.public,
            size: 20,
            color: AppColors.metricPurple,
          ),
          title: Text(
            domain.displayName,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          subtitle: domain.worksCount != null
              ? Text(
                  '${_formatCount(domain.worksCount!)} works',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: IconButton(
            icon: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _expandedDomainId = isExpanded ? null : domain.id;
                _expandedFieldId = null;
                _expandedSubfieldId = null;
              });
            },
          ),
          dense: true,
          onTap: () => widget.onSelect(domain),
        ),
        if (isExpanded) _buildFieldsList(domain.id),
        const Divider(height: 1, indent: AppDimensions.base),
      ],
    );
  }

  Widget _buildFieldsList(String domainId) {
    final fieldsAsync = ref.watch(fieldsProvider(domainId));

    return fieldsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimensions.base),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.sm),
        child: Text('Error: $e', style: AppTextStyles.labelSmall),
      ),
      data: (fields) {
        return Column(
          children: fields.map((field) => _buildFieldTile(field)).toList(),
        );
      },
    );
  }

  Widget _buildFieldTile(TopicHierarchyItem field) {
    final isExpanded = _expandedFieldId == field.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppDimensions.base),
          child: ListTile(
            leading: const Icon(
              Icons.category,
              size: 18,
              color: AppColors.primaryContainer,
            ),
            title: Text(
              field.displayName,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
            subtitle: field.worksCount != null
                ? Text(
                    '${_formatCount(field.worksCount!)} works',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  )
                : null,
            trailing: IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _expandedFieldId = isExpanded ? null : field.id;
                  _expandedSubfieldId = null;
                });
              },
            ),
            dense: true,
            onTap: () => widget.onSelect(field),
          ),
        ),
        if (isExpanded) _buildSubfieldsList(field.id),
      ],
    );
  }

  Widget _buildSubfieldsList(String fieldId) {
    final subfieldsAsync = ref.watch(subfieldsProvider(fieldId));

    return subfieldsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimensions.sm),
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.sm),
        child: Text('Error: $e', style: AppTextStyles.labelSmall),
      ),
      data: (subfields) {
        return Column(
          children: subfields
              .map((subfield) => _buildSubfieldTile(subfield))
              .toList(),
        );
      },
    );
  }

  Widget _buildSubfieldTile(TopicHierarchyItem subfield) {
    final isExpanded = _expandedSubfieldId == subfield.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppDimensions.xl),
          child: ListTile(
            leading: const Icon(
              Icons.folder_outlined,
              size: 16,
              color: AppColors.metricOrange,
            ),
            title: Text(
              subfield.displayName,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            subtitle: subfield.worksCount != null
                ? Text(
                    '${_formatCount(subfield.worksCount!)} works',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  )
                : null,
            trailing: IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              onPressed: () {
                setState(() {
                  _expandedSubfieldId = isExpanded ? null : subfield.id;
                });
              },
            ),
            dense: true,
            onTap: () => widget.onSelect(subfield),
          ),
        ),
        if (isExpanded) _buildTopicsList(subfield.id),
      ],
    );
  }

  Widget _buildTopicsList(String subfieldId) {
    final topicsAsync = ref.watch(topicsProvider(subfieldId));

    return topicsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimensions.sm),
        child: Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.sm),
        child: Text('Error: $e', style: AppTextStyles.labelSmall),
      ),
      data: (topics) {
        return Column(
          children: topics.map((topic) => _buildTopicTile(topic)).toList(),
        );
      },
    );
  }

  Widget _buildTopicTile(TopicHierarchyItem topic) {
    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.xxl),
      child: ListTile(
        leading: const Icon(
          Icons.topic_outlined,
          size: 14,
          color: AppColors.metricGreen,
        ),
        title: Text(
          topic.displayName,
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface),
        ),
        subtitle: topic.worksCount != null
            ? Text(
                '${_formatCount(topic.worksCount!)} works',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              )
            : null,
        dense: true,
        onTap: () => widget.onSelect(topic),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
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

            // Metadata section (indented under rank badge)
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Citations + Year row
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Year ',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                publication.publicationYear.toString(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Journal — clickable with hover effect
                  if (publication.journalName != null) ...[
                    const SizedBox(height: AppDimensions.sm),
                    _TopicChip(
                      topic: publication.journalName!,
                      onTap: () => onJournalTap(publication.journalName!),
                      isJournal: true,
                    ),
                  ],

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
                                onTap: () => onAuthorTap(a.displayName),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Research Topics — all, with hover effect
                  if (publication.concepts.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Topics: ',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: AppDimensions.xs,
                            runSpacing: AppDimensions.xs,
                            children: publication.concepts.map((topic) {
                              return _TopicChip(
                                topic: topic,
                                onTap: () => onTopicTap(topic),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
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
  final bool isJournal;

  const _TopicChip({
    required this.topic,
    required this.onTap,
    this.isJournal = false,
  });

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
                : widget.isJournal
                ? AppColors.citationChipBg
                : AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
            border: Border.all(
              color: isActive ? AppColors.primaryContainer : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isJournal) ...[
                Icon(
                  Icons.library_books,
                  size: 12,
                  color: isActive
                      ? AppColors.primaryContainer
                      : AppColors.primaryContainer,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  widget.topic,
                  style:
                      (widget.isJournal
                              ? AppTextStyles.bodySmall
                              : AppTextStyles.labelSmall)
                          .copyWith(
                            fontWeight: widget.isJournal
                                ? FontWeight.w700
                                : null,
                            fontStyle: widget.isJournal
                                ? FontStyle.italic
                                : null,
                            color: isActive
                                ? AppColors.primaryContainer
                                : widget.isJournal
                                ? AppColors.primaryContainer
                                : AppColors.onSecondaryContainer,
                          ),
                ),
              ),
            ],
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
