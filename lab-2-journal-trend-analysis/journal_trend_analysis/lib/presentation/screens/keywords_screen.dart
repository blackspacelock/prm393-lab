import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../../firebase/analytics_service.dart';
import '../providers/providers.dart';
import 'author_network_screen.dart';
import 'heatmap_screen.dart';
import 'search_screen.dart';
import 'trend_analysis_screen.dart';

/// Integrated Keywords page with 4 sub-tabs.
/// The search bar lives here (above tabs) so it persists across all tabs.
class KeywordsScreen extends ConsumerStatefulWidget {
  const KeywordsScreen({super.key});

  @override
  ConsumerState<KeywordsScreen> createState() => _KeywordsScreenState();
}

class _KeywordsScreenState extends ConsumerState<KeywordsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _showAutocomplete = false;
  String _autocompleteQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_focusNode.hasFocus) {
            setState(() => _showAutocomplete = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final text = _searchController.text.trim();
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
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = trimmed;
    unawaited(analyticsService.searchTopic(trimmed));
  }

  void _selectTopicItem(TopicHierarchyItem item) {
    _debounce?.cancel();
    setState(() => _showAutocomplete = false);
    _focusNode.unfocus();
    _searchController.text = item.displayName;
    ref.read(selectedTopicFilterProvider.notifier).state = item;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = item.displayName;
    unawaited(analyticsService.searchTopic(item.displayName));
    unawaited(analyticsService.viewKeyword(item.displayName));
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showAutocomplete = false;
    });
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedTopicFilterProvider.notifier).state = null;
  }

  void _showTopicHierarchySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.shapeMd),
        ),
      ),
      builder: (_) => _TopicHierarchySheet(onSelect: _selectTopicItem),
    );
  }

  void _showSortFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.shapeMd),
        ),
      ),
      builder: (_) => const _SortFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final topicFilter = ref.watch(selectedTopicFilterProvider);
    final sortOption = ref.watch(paperSortOptionProvider);

    // Keep text controller in sync with provider (e.g. cross-tab navigation)
    if (_searchController.text != query && !_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _searchController.text != query &&
            !_focusNode.hasFocus) {
          _searchController.text = query;
          _debounce?.cancel();
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Keywords'),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            48 + // TabBar
                60 + // search bar
                (_showAutocomplete
                    ? 264 // suggestion panel (260) plus its top margin
                    : 48 + // two dropdowns
                          (topicFilter != null ? 44.0 : 0) + // filter chip
                          4), // small gap
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  AppDimensions.sm,
                  AppDimensions.base,
                  0,
                ),
                child: TextField(
                  key: const Key('topicSearchField'),
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search research topics\u2026',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.sm,
                    ),
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

              // ── Autocomplete overlay ──
              if (_showAutocomplete)
                _KeywordsAutocomplete(
                  query: _autocompleteQuery,
                  onSelect: _selectTopicItem,
                ),

              // ── Two full-width dropdowns (50/50) ──
              if (!_showAutocomplete) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.base,
                    AppDimensions.xs,
                    AppDimensions.base,
                    0,
                  ),
                  child: Row(
                    children: [
                      // Topic Hierarchy dropdown
                      Expanded(
                        child: _DropdownButton(
                          icon: Icons.account_tree_outlined,
                          label: topicFilter != null
                              ? topicFilter.displayName
                              : 'Topic Hierarchy',
                          isActive: topicFilter != null,
                          onTap: _showTopicHierarchySheet,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      // Sort / Filter dropdown
                      Expanded(
                        child: _DropdownButton(
                          icon: Icons.tune,
                          label: _sortLabel(sortOption),
                          isActive: sortOption != PaperSortOption.relevance,
                          onTap: _showSortFilterSheet,
                        ),
                      ),
                    ],
                  ),
                ),

                // Active topic filter chip
                if (topicFilter != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.base,
                      AppDimensions.xs,
                      AppDimensions.base,
                      0,
                    ),
                    child: Chip(
                      avatar: const Icon(
                        Icons.filter_alt_outlined,
                        size: 14,
                        color: AppColors.primaryContainer,
                      ),
                      label: Text(
                        '${topicFilter.displayName} (${topicFilter.levelLabel})',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        ref.read(selectedTopicFilterProvider.notifier).state =
                            null;
                        ref.read(searchQueryProvider.notifier).state = '';
                        _searchController.clear();
                      },
                      backgroundColor: AppColors.secondaryContainer,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],

              // ── TabBar ──
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryContainer,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                indicatorColor: AppColors.primaryContainer,
                labelStyle: AppTextStyles.labelLarge,
                unselectedLabelStyle: AppTextStyles.labelMedium,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                ),
                tabs: const [
                  Tab(text: 'Papers'),
                  Tab(text: 'Dashboard'),
                  Tab(text: 'Heatmap'),
                  Tab(text: 'Network'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SearchScreen(),
          TrendAnalysisScreen(),
          HeatmapScreen(),
          AuthorNetworkScreen(),
        ],
      ),
    );
  }

  String _sortLabel(PaperSortOption opt) => switch (opt) {
    PaperSortOption.relevance => 'Sort: Relevance',
    PaperSortOption.citationCount => 'Sort: Most Cited',
    PaperSortOption.year => 'Sort: Newest First',
    PaperSortOption.title => 'Sort: A\u2013Z',
  };
}

// ── Full-width dropdown button widget ─────────────────────────────────────────

class _DropdownButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DropdownButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryContainer.withValues(alpha: 0.12)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
          border: Border.all(
            color: isActive
                ? AppColors.primaryContainer
                : AppColors.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? AppColors.primaryContainer
                  : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.xs),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isActive
                      ? AppColors.primaryContainer
                      : AppColors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more,
              size: 16,
              color: isActive
                  ? AppColors.primaryContainer
                  : AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Autocomplete suggestions panel ────────────────────────────────────────────

class _KeywordsAutocomplete extends ConsumerWidget {
  final String query;
  final ValueChanged<TopicHierarchyItem> onSelect;

  const _KeywordsAutocomplete({required this.query, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autocompleteAsync = ref.watch(topicAutocompleteProvider(query));

    return Container(
      height: 260,
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.xs,
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
                onTap: () => onSelect(item),
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

// ── Topic Hierarchy bottom sheet ──────────────────────────────────────────────

class _TopicHierarchySheet extends StatelessWidget {
  final ValueChanged<TopicHierarchyItem> onSelect;

  const _TopicHierarchySheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.base,
              0,
              AppDimensions.xs,
              AppDimensions.sm,
            ),
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
          Expanded(
            child: _TopicHierarchyTree(
              scrollController: scrollController,
              onSelect: (item) {
                Navigator.of(context).pop();
                onSelect(item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sort/Filter bottom sheet ──────────────────────────────────────────────────

class _SortFilterSheet extends ConsumerWidget {
  const _SortFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(paperSortOptionProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.sm,
        AppDimensions.base,
        AppDimensions.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppDimensions.base),
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.tune,
                size: 20,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                'Sort by',
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
          const Divider(height: AppDimensions.base),
          ...PaperSortOption.values.map((opt) {
            final selected = current == opt;
            return RadioListTile<PaperSortOption>(
              title: Text(
                _label(opt),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selected
                      ? AppColors.primaryContainer
                      : AppColors.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              value: opt,
              groupValue: current,
              activeColor: AppColors.primaryContainer,
              dense: true,
              onChanged: (v) {
                if (v != null) {
                  ref.read(paperSortOptionProvider.notifier).state = v;
                  Navigator.of(context).pop();
                }
              },
            );
          }),
        ],
      ),
    );
  }

  String _label(PaperSortOption opt) => switch (opt) {
    PaperSortOption.relevance => 'Relevance',
    PaperSortOption.citationCount => 'Most Cited',
    PaperSortOption.year => 'Newest First',
    PaperSortOption.title => 'A\u2013Z (Title)',
  };
}

// ── Topic Hierarchy Tree ──────────────────────────────────────────────────────

class _TopicHierarchyTree extends ConsumerStatefulWidget {
  final ValueChanged<TopicHierarchyItem> onSelect;
  final ScrollController? scrollController;

  const _TopicHierarchyTree({required this.onSelect, this.scrollController});

  @override
  ConsumerState<_TopicHierarchyTree> createState() =>
      _TopicHierarchyTreeState();
}

class _TopicHierarchyTreeState extends ConsumerState<_TopicHierarchyTree> {
  String? _expandedDomainId;
  String? _expandedFieldId;
  String? _expandedSubfieldId;

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

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
          controller: widget.scrollController,
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
            onPressed: () => setState(() {
              _expandedDomainId = isExpanded ? null : domain.id;
              _expandedFieldId = null;
              _expandedSubfieldId = null;
            }),
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
      data: (fields) => Column(children: fields.map(_buildFieldTile).toList()),
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
              onPressed: () => setState(() {
                _expandedFieldId = isExpanded ? null : field.id;
                _expandedSubfieldId = null;
              }),
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
      data: (subfields) =>
          Column(children: subfields.map(_buildSubfieldTile).toList()),
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
              onPressed: () => setState(
                () => _expandedSubfieldId = isExpanded ? null : subfield.id,
              ),
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
      data: (topics) => Column(children: topics.map(_buildTopicTile).toList()),
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
}
