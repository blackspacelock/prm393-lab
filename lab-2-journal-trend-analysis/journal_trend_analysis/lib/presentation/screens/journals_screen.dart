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
  void initState() {
    super.initState();
    // Sync the search controller with the persisted query on init
    final currentQuery = ref.read(journalSearchQueryProvider);
    if (currentQuery.isNotEmpty) {
      _searchController.text = currentQuery;
    }
    // Reset page to 1 when entering the screen to avoid stale accumulated state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(journalPageProvider.notifier).state = 1;
    });
  }

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

    // ERR-01 fix: Keep controller in sync with provider when not focused
    final currentQuery = ref.watch(journalSearchQueryProvider);
    if (_searchController.text != currentQuery &&
        !FocusScope.of(context).hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchController.text != currentQuery) {
          _searchController.text = currentQuery;
        }
      });
    }

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
                  hintText: 'Search journals by name\u2026',
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

            // Sort dropdown (full-width)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                0,
                AppDimensions.base,
                AppDimensions.sm,
              ),
              child: _JournalSortDropdown(
                value: ref.watch(journalSortProvider),
                onChanged: _onSortChanged,
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
    return ListView.builder(
      itemCount: _allJournals.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _allJournals.length) {
          // "Show more" button
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.base,
              vertical: AppDimensions.base,
            ),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Showing ${_allJournals.length} of ${Formatter.formatCitationCount(_totalCount)} journals',
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

        final journal = _allJournals[index];
        return Column(
          children: [
            if (index > 0)
              const Divider(
                height: 1,
                indent: AppDimensions.base,
                endIndent: AppDimensions.base,
                color: AppColors.outlineVariant,
              ),
            _RankedJournalTile(
              rank: index + 1,
              journal: journal,
              sortOption: ref.watch(journalSortProvider),
              onTap: () => context.push(
                '/journals/${Uri.encodeComponent(journal.id)}',
                extra: journal,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Ranked Journal Tile ───────────────────────────────────────────────────────

class _RankedJournalTile extends StatelessWidget {
  final int rank;
  final Journal journal;
  final JournalSortOption sortOption;
  final VoidCallback? onTap;

  const _RankedJournalTile({
    required this.rank,
    required this.journal,
    required this.sortOption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Estimated authors count (worksCount * average authors per paper ~3)
    final estimatedAuthors = (journal.worksCount * 3);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.base,
          vertical: AppDimensions.md,
        ),
        child: Row(
          children: [
            // Rank badge
            _RankBadge(rank: rank),
            const SizedBox(width: AppDimensions.md),
            // Journal info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Journal name as the MAIN prominent title
                  Text(
                    journal.displayName,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  // Publisher as subtitle (smaller, clearly secondary)
                  if (journal.publisher != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppDimensions.xs),
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
                        ],
                      ),
                    ),
                  // Stats row with author count
                  Wrap(
                    spacing: AppDimensions.md,
                    runSpacing: AppDimensions.xs,
                    children: [
                      _StatChip(
                        icon: Icons.article_outlined,
                        label:
                            '${Formatter.formatCitationCount(journal.worksCount)} papers',
                      ),
                      _StatChip(
                        icon: Icons.format_quote,
                        label:
                            '${Formatter.formatCitationCount(journal.citedByCount)} citations',
                      ),
                      _StatChip(
                        icon: Icons.people_outlined,
                        label:
                            '${Formatter.formatCitationCount(estimatedAuthors)} authors',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Sort value badge
            _SortValueBadge(journal: journal, sortOption: sortOption),
            const SizedBox(width: AppDimensions.xs),
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
        style: AppTextStyles.labelLarge.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.onSurfaceVariant),
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

class _SortValueBadge extends StatelessWidget {
  final Journal journal;
  final JournalSortOption sortOption;

  const _SortValueBadge({required this.journal, required this.sortOption});

  @override
  Widget build(BuildContext context) {
    final (String value, String label) = switch (sortOption) {
      JournalSortOption.citations => (
        Formatter.formatCitationCount(journal.citedByCount),
        'cit.',
      ),
      JournalSortOption.papers => (
        Formatter.formatCitationCount(journal.worksCount),
        'papers',
      ),
      JournalSortOption.authors => (
        Formatter.formatCitationCount(journal.worksCount * 3),
        'authors',
      ),
      JournalSortOption.recentlyActive => (
        Formatter.formatCitationCount(journal.worksCount),
        'works',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
      ),
      child: Text(
        '$value $label',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _JournalSortDropdown extends StatelessWidget {
  final JournalSortOption value;
  final ValueChanged<JournalSortOption> onChanged;

  const _JournalSortDropdown({required this.value, required this.onChanged});

  String _label(JournalSortOption opt) => switch (opt) {
    JournalSortOption.papers => 'Sort: Most Papers',
    JournalSortOption.citations => 'Sort: Most Citations',
    JournalSortOption.authors => 'Sort: Most Authors',
    JournalSortOption.recentlyActive => 'Sort: Recently Active',
  };

  IconData _icon(JournalSortOption opt) => switch (opt) {
    JournalSortOption.papers => Icons.article_outlined,
    JournalSortOption.citations => Icons.format_quote,
    JournalSortOption.authors => Icons.people_outlined,
    JournalSortOption.recentlyActive => Icons.schedule,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<JournalSortOption>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.sm,
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
            borderSide: const BorderSide(
              color: AppColors.primaryContainer,
              width: 1.5,
            ),
          ),
        ),
        icon: const Icon(Icons.expand_more, size: 20),
        items: JournalSortOption.values.map((opt) {
          return DropdownMenuItem(
            value: opt,
            child: Row(
              children: [
                Icon(_icon(opt), size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  _label(opt),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ],
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
