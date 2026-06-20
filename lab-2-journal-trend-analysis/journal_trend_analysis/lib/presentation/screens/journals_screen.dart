import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/journal.dart';
import '../providers/journal_providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';

class JournalsScreen extends ConsumerStatefulWidget {
  const JournalsScreen({super.key});

  @override
  ConsumerState<JournalsScreen> createState() => _JournalsScreenState();
}

class _JournalsScreenState extends ConsumerState<JournalsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Accumulated results for infinite scroll
  List<Journal> _allJournals = [];
  int _totalCount = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _lastProcessedPage = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _resetList();
      ref.read(journalPageProvider.notifier).state = 1;
      ref.read(journalSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _onSortChanged(JournalSortOption sort) {
    if (ref.read(journalSortProvider) == sort) return;
    _resetList();
    ref.read(journalPageProvider.notifier).state = 1;
    ref.read(journalSortProvider.notifier).state = sort;
  }

  void _resetList() {
    setState(() {
      _allJournals = [];
      _currentPage = 1;
      _lastProcessedPage = 0;
      _hasMore = true;
      _totalCount = 0;
    });
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    ref.read(journalPageProvider.notifier).state = _currentPage;
  }

  @override
  Widget build(BuildContext context) {
    final journalListAsync = ref.watch(journalListProvider);

    journalListAsync.whenData((paginated) {
      if (paginated.page <= _lastProcessedPage && _currentPage != 1) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _totalCount = paginated.totalCount;
          if (paginated.page == 1) {
            _allJournals = List.from(paginated.items);
          } else {
            _allJournals = [..._allJournals, ...paginated.items];
          }
          _lastProcessedPage = paginated.page;
          _hasMore = paginated.hasNextPage;
          _isLoadingMore = false;
        });
      });
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Journals'),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
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
                AppDimensions.sm,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search journals by name…',
                  hintStyle: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
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
                onChanged: _onSearchChanged,
              ),
            ),

            // Sort options
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.base,
              ),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _SortChip(
                      label: 'Citations',
                      icon: Icons.format_quote,
                      selected:
                          ref.watch(journalSortProvider) ==
                          JournalSortOption.citations,
                      onTap: () => _onSortChanged(JournalSortOption.citations),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    _SortChip(
                      label: 'Papers',
                      icon: Icons.article_outlined,
                      selected:
                          ref.watch(journalSortProvider) ==
                          JournalSortOption.papers,
                      onTap: () => _onSortChanged(JournalSortOption.papers),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    _SortChip(
                      label: 'Authors',
                      icon: Icons.people_outlined,
                      selected:
                          ref.watch(journalSortProvider) ==
                          JournalSortOption.authors,
                      onTap: () => _onSortChanged(JournalSortOption.authors),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    _SortChip(
                      label: 'Recently Active',
                      icon: Icons.schedule,
                      selected:
                          ref.watch(journalSortProvider) ==
                          JournalSortOption.recentlyActive,
                      onTap: () =>
                          _onSortChanged(JournalSortOption.recentlyActive),
                    ),
                  ],
                ),
              ),
            ),

            // Results count
            if (_allJournals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.base,
                  vertical: AppDimensions.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${Formatter.formatCitationCount(_totalCount)} journals found',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            // Journal list
            Expanded(
              child: journalListAsync.when(
                loading: () => _allJournals.isEmpty
                    ? const ShimmerLoader()
                    : _buildJournalList(),
                error: (e, _) => _allJournals.isEmpty
                    ? ErrorState(
                        message: e.toString(),
                        onRetry: () => ref.invalidate(journalListProvider),
                      )
                    : _buildJournalList(),
                data: (_) => _allJournals.isEmpty
                    ? const EmptyState(
                        icon: Icons.menu_book,
                        message: 'No journals found. Try a different search.',
                      )
                    : _buildJournalList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: _allJournals.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: AppDimensions.base,
          endIndent: AppDimensions.base,
          color: AppColors.outlineVariant,
        ),
        itemBuilder: (context, index) {
          if (index >= _allJournals.length) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.base),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final journal = _allJournals[index];
          return _JournalTile(
            journal: journal,
            onTap: () => context.push(
              '/journals/${Uri.encodeComponent(journal.id)}',
              extra: journal,
            ),
          );
        },
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  final Journal journal;
  final VoidCallback? onTap;

  const _JournalTile({required this.journal, this.onTap});

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
            // Journal icon
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
            // Journal info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journal.displayName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Row(
                    children: [
                      if (journal.publisher != null) ...[
                        Flexible(
                          child: Text(
                            journal.publisher!,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppDimensions.xs),
                      Text(
                        '${Formatter.formatCitationCount(journal.worksCount)} works',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Icon(
                        Icons.format_quote,
                        size: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppDimensions.xs),
                      Text(
                        '${Formatter.formatCitationCount(journal.citedByCount)} citations',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
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

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: selected
                ? AppColors.primaryContainer
                : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.xs),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryContainer.withValues(alpha: 0.12),
      checkmarkColor: AppColors.primaryContainer,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: selected
            ? AppColors.primaryContainer
            : AppColors.onSurfaceVariant,
      ),
      side: BorderSide(
        color: selected ? AppColors.primaryContainer : AppColors.outlineVariant,
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xs),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
