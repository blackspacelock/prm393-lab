import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
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

const _perPageOptions = [10, 25, 50];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _showAutocomplete = false;
  String _autocompleteQuery = '';

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
    setState(() => _showAutocomplete = false);
    _focusNode.unfocus();
    // Clear topic filter, use free-text search
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = trimmed;
  }

  void _selectTopicItem(TopicHierarchyItem item) {
    setState(() => _showAutocomplete = false);
    _focusNode.unfocus();
    _controller.text = item.displayName;
    // Use topic filter
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

  void _showSortFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final currentSort = ref.watch(paperSortOptionProvider);
            final currentPerPage = ref.watch(searchPerPageProvider);
            return Padding(
              padding: const EdgeInsets.all(AppDimensions.base),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.base),
                  Text(
                    'Sort & Filter',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.base),
                  Text(
                    'Sort by',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Wrap(
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.sm,
                    children: PaperSortOption.values.map((opt) {
                      final selected = currentSort == opt;
                      return ChoiceChip(
                        label: Text(_sortLabel(opt)),
                        selected: selected,
                        onSelected: (_) {
                          ref.read(paperSortOptionProvider.notifier).state =
                              opt;
                        },
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
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppDimensions.base),
                  Text(
                    'Results per page',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Wrap(
                    spacing: AppDimensions.sm,
                    children: _perPageOptions.map((n) {
                      final selected = currentPerPage == n;
                      return ChoiceChip(
                        label: Text('$n'),
                        selected: selected,
                        onSelected: (_) {
                          ref.read(searchPerPageProvider.notifier).state = n;
                          ref.read(searchPageProvider.notifier).state = 1;
                        },
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
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppDimensions.base),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _sortLabel(PaperSortOption opt) => switch (opt) {
    PaperSortOption.citationCount => 'Citation count',
    PaperSortOption.year => 'Year',
    PaperSortOption.relevance => 'Relevance',
    PaperSortOption.title => 'A–Z',
  };

  @override
  Widget build(BuildContext context) {
    final paginatedAsync = ref.watch(paginatedPublicationsProvider);
    final sorted = ref.watch(sortedPublicationsProvider);
    final query = ref.watch(searchQueryProvider);
    final currentPage = ref.watch(searchPageProvider);
    final topicFilter = ref.watch(selectedTopicFilterProvider);

    ref.listen(paginatedPublicationsProvider, (_, next) {
      if (next.hasError) {
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
          // Cascading topic browser button
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Browse Topics',
            onPressed: _openCascadeFilter,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showSortFilterSheet,
          ),
        ],
      ),
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

          // Autocomplete suggestions overlay
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
            Expanded(
              child: paginatedAsync.when(
                loading: () => const ShimmerLoader(),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(paginatedPublicationsProvider),
                ),
                data: (paginated) {
                  if (sorted.isEmpty) {
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
                              ref
                                      .read(
                                        selectedTopicFilterProvider.notifier,
                                      )
                                      .state =
                                  null;
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
                          "Results for '$query' · ${Formatter.formatCitationCount(paginated.totalCount)} total · Page $currentPage/${paginated.totalPages}",
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // Paper list
                      Expanded(
                        child: ListView.separated(
                          itemCount: sorted.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: AppDimensions.base,
                            endIndent: AppDimensions.base,
                            color: AppColors.outlineVariant,
                          ),
                          itemBuilder: (_, i) {
                            final pub = sorted[i];
                            final globalRank =
                                (currentPage - 1) * paginated.perPage + i + 1;
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
                                    _RankBadge(rank: globalRank),
                                    const SizedBox(width: AppDimensions.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pub.title,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.onSurface,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (pub.journalName != null) ...[
                                            const SizedBox(
                                              height: AppDimensions.xs,
                                            ),
                                            Text(
                                              pub.journalName!,
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                    color: AppColors
                                                        .onSurfaceVariant,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (pub.authors.isNotEmpty) ...[
                                            const SizedBox(
                                              height: AppDimensions.xs,
                                            ),
                                            Text(
                                              pub.authors.length > 1
                                                  ? '${pub.authors.first.displayName} et al.'
                                                  : pub
                                                        .authors
                                                        .first
                                                        .displayName,
                                              style: AppTextStyles.labelSmall
                                                  .copyWith(
                                                    color: AppColors
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppDimensions.sm),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                                            style: AppTextStyles.labelMedium
                                                .copyWith(
                                                  color: AppColors
                                                      .citationChipText,
                                                ),
                                          ),
                                        ),
                                        if (pub.publicationYear != null) ...[
                                          const SizedBox(
                                            height: AppDimensions.xs,
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppDimensions.sm,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors
                                                  .surfaceContainerHigh,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppDimensions.shapeXs,
                                                  ),
                                            ),
                                            child: Text(
                                              pub.publicationYear.toString(),
                                              style: AppTextStyles.labelSmall
                                                  .copyWith(
                                                    color: AppColors
                                                        .onSurfaceVariant,
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
                      // Pagination controls
                      if (paginated.totalPages > 1)
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: AppColors.outlineVariant,
                                width: 0.5,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.base,
                            vertical: AppDimensions.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.first_page),
                                onPressed: currentPage > 1
                                    ? () =>
                                          ref
                                                  .read(
                                                    searchPageProvider.notifier,
                                                  )
                                                  .state =
                                              1
                                    : null,
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: currentPage > 1
                                    ? () =>
                                          ref
                                                  .read(
                                                    searchPageProvider.notifier,
                                                  )
                                                  .state =
                                              currentPage - 1
                                    : null,
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              Text(
                                '$currentPage / ${paginated.totalPages}',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: paginated.hasNextPage
                                    ? () =>
                                          ref
                                                  .read(
                                                    searchPageProvider.notifier,
                                                  )
                                                  .state =
                                              currentPage + 1
                                    : null,
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(Icons.last_page),
                                onPressed: currentPage < paginated.totalPages
                                    ? () =>
                                          ref
                                              .read(searchPageProvider.notifier)
                                              .state = paginated
                                              .totalPages
                                    : null,
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
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
