import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/publication.dart';
import '../../domain/usecases/get_top_journals.dart';
import '../providers/providers.dart';
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
  String _localQuery = '';
  _JournalSort _sort = _JournalSort.publications;
  int? _publicationCountFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider).trim();
    final isDefaultView = query.isEmpty;
    final paginated = ref.watch(paginatedPublicationsProvider);
    final recentPublications = ref.watch(recentPublicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Journals')),
      body: paginated.when(
        data: (_) {
          final journals = ref.watch(topJournalsProvider);
          if (journals.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              message: isDefaultView
                  ? 'No journal data is available for trending publications'
                  : 'No journal data available for "$query"',
            );
          }
          final localQuery = _localQuery.trim().toLowerCase();
          final countOptions = _publicationCountOptions(journals);
          if (_publicationCountFilter != null &&
              !countOptions.contains(_publicationCountFilter)) {
            _publicationCountFilter = null;
          }
          final visibleJournals = _sortJournals(
            (localQuery.isEmpty
                    ? journals
                    : journals.where(
                        (j) => j.name.toLowerCase().contains(localQuery),
                      ))
                .where(_matchesFilter)
                .toList(),
          );

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroSummary(
                  isDefaultView: isDefaultView,
                  query: query,
                  publications: recentPublications,
                  journals: journals,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.base,
                    AppDimensions.md,
                    AppDimensions.base,
                    AppDimensions.sm,
                  ),
                  child: _JournalControls(
                    controller: _searchController,
                    query: _localQuery,
                    sort: _sort,
                    publicationCountFilter: _publicationCountFilter,
                    publicationCountOptions: countOptions,
                    onChanged: (value) => setState(() => _localQuery = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _localQuery = '');
                    },
                    onSortChanged: (value) => setState(() => _sort = value),
                    onFilterChanged: (value) =>
                        setState(() => _publicationCountFilter = value),
                  ),
                ),
              ),
              if (visibleJournals.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.base,
                      AppDimensions.md,
                      AppDimensions.base,
                      AppDimensions.sm,
                    ),
                    child: _TopSourcesPanel(journals: visibleJournals),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.base,
                    AppDimensions.lg,
                    AppDimensions.base,
                    AppDimensions.xs,
                  ),
                  child: _SectionHeader(
                    title: 'All Sources',
                    subtitle: visibleJournals.isEmpty
                        ? 'No journals match "$_localQuery"'
                        : '${visibleJournals.length} journals ordered by activity',
                  ),
                ),
              ),
              if (visibleJournals.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.base,
                    ),
                    child: _SoftEmptyMessage(
                      message: 'Try a different journal name.',
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: visibleJournals.length,
                  itemBuilder: (context, index) {
                    final journal = visibleJournals[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.base,
                        vertical: AppDimensions.xs,
                      ),
                      child: _JournalListTile(
                        rank: index + 1,
                        journal: journal,
                        maxCount: visibleJournals.first.publicationCount,
                        onTap: () => context.push(
                          '/journal/${Uri.encodeComponent(journal.name)}',
                          extra: journal,
                        ),
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppDimensions.xl),
              ),
            ],
          );
        },
        loading: () => const ShimmerLoader(),
        error: (error, _) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(paginatedPublicationsProvider),
        ),
      ),
    );
  }

  bool _matchesFilter(JournalWithCount journal) {
    return _publicationCountFilter == null ||
        journal.publicationCount == _publicationCountFilter;
  }

  List<int> _publicationCountOptions(List<JournalWithCount> journals) {
    final options = journals.map((j) => j.publicationCount).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return options.take(8).toList();
  }

  List<JournalWithCount> _sortJournals(List<JournalWithCount> journals) {
    final sorted = List<JournalWithCount>.from(journals);
    switch (_sort) {
      case _JournalSort.publications:
        sorted.sort((a, b) => b.publicationCount.compareTo(a.publicationCount));
      case _JournalSort.citations:
        sorted.sort((a, b) => b.totalCitations.compareTo(a.totalCitations));
      case _JournalSort.averageCitations:
        sorted.sort((a, b) {
          final aAvg = a.publicationCount == 0
              ? 0.0
              : a.totalCitations / a.publicationCount;
          final bAvg = b.publicationCount == 0
              ? 0.0
              : b.totalCitations / b.publicationCount;
          return bAvg.compareTo(aAvg);
        });
      case _JournalSort.name:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    return sorted;
  }
}

enum _JournalSort { publications, citations, averageCitations, name }

class _JournalControls extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final _JournalSort sort;
  final int? publicationCountFilter;
  final List<int> publicationCountOptions;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<_JournalSort> onSortChanged;
  final ValueChanged<int?> onFilterChanged;

  const _JournalControls({
    required this.controller,
    required this.query,
    required this.sort,
    required this.publicationCountFilter,
    required this.publicationCountOptions,
    required this.onChanged,
    required this.onClear,
    required this.onSortChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search journals...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                    tooltip: 'Clear',
                  ),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: publicationCountFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.filter_list, size: 20),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All pub counts'),
                  ),
                  ...publicationCountOptions.map(
                    (count) => DropdownMenuItem<int?>(
                      value: count,
                      child: Text('$count pubs'),
                    ),
                  ),
                ],
                onChanged: onFilterChanged,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: DropdownButtonFormField<_JournalSort>(
                initialValue: sort,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.sort, size: 20),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: _JournalSort.publications,
                    child: Text('Publications'),
                  ),
                  DropdownMenuItem(
                    value: _JournalSort.citations,
                    child: Text('Citations'),
                  ),
                  DropdownMenuItem(
                    value: _JournalSort.averageCitations,
                    child: Text('Avg cites'),
                  ),
                  DropdownMenuItem(
                    value: _JournalSort.name,
                    child: Text('Name'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final bool isDefaultView;
  final String query;
  final List<Publication> publications;
  final List<JournalWithCount> journals;

  const _HeroSummary({
    required this.isDefaultView,
    required this.query,
    required this.publications,
    required this.journals,
  });

  @override
  Widget build(BuildContext context) {
    final totalCitations = journals.fold<int>(
      0,
      (sum, journal) => sum + journal.totalCitations,
    );
    final topJournal = journals.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.lg,
      ),
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContextPill(
            icon: isDefaultView ? Icons.trending_up : Icons.search,
            label: isDefaultView ? 'Live OpenAlex trending set' : query,
          ),
          const SizedBox(height: AppDimensions.base),
          Text(
            isDefaultView
                ? 'Journal Landscape'
                : 'Journal Landscape for "$query"',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'See which publication sources dominate this result set, then drill into the papers behind each journal.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.base),
          _FeaturedJournal(journal: topJournal),
          const SizedBox(height: AppDimensions.base),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Papers',
                  value: publications.length.toString(),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _MiniStat(
                  label: 'Journals',
                  value: journals.length.toString(),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _MiniStat(
                  label: 'Citations',
                  value: _formatCompact(totalCitations),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ContextPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.citationChipBg,
        borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryContainer),
          const SizedBox(width: AppDimensions.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedJournal extends StatelessWidget {
  final JournalWithCount journal;

  const _FeaturedJournal({required this.journal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.base),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryContainer,
            child: Icon(Icons.workspace_premium, color: AppColors.onPrimary),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leading source',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  journal.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Text(
            '${journal.publicationCount} pubs',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSourcesPanel extends StatelessWidget {
  final List<JournalWithCount> journals;

  const _TopSourcesPanel({required this.journals});

  @override
  Widget build(BuildContext context) {
    final topJournals = journals.take(5).toList();
    final maxCount = topJournals.first.publicationCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Top Sources',
          subtitle: 'Publication share among the leading journals',
        ),
        const SizedBox(height: AppDimensions.md),
        for (var i = 0; i < topJournals.length; i++) ...[
          _SourceBar(rank: i + 1, journal: topJournals[i], maxCount: maxCount),
          if (i != topJournals.length - 1)
            const SizedBox(height: AppDimensions.md),
        ],
      ],
    );
  }
}

class _SourceBar extends StatelessWidget {
  final int rank;
  final JournalWithCount journal;
  final int maxCount;

  const _SourceBar({
    required this.rank,
    required this.journal,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount == 0 ? 0.0 : journal.publicationCount / maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _RankBadge(rank: rank, small: true),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                journal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${journal.publicationCount}',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio.clamp(0.0, 1.0),
            color: AppColors.primaryContainer,
            backgroundColor: AppColors.surfaceContainerHigh,
          ),
        ),
      ],
    );
  }
}

class _JournalListTile extends StatelessWidget {
  final int rank;
  final JournalWithCount journal;
  final int maxCount;
  final VoidCallback onTap;

  const _JournalListTile({
    required this.rank,
    required this.journal,
    required this.maxCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avgCitations = journal.publicationCount == 0
        ? 0.0
        : journal.totalCitations / journal.publicationCount;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              _RankBadge(rank: rank),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      '${journal.publicationCount} publications · ${journal.totalCitations} citations · ${avgCitations.toStringAsFixed(1)} avg',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              const Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceVariant,
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
  final bool small;

  const _RankBadge({required this.rank, this.small = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (AppColors.rankGold, AppColors.rankGoldText),
      2 => (AppColors.rankSilver, AppColors.rankSilverText),
      3 => (AppColors.rankBronze, AppColors.rankBronzeText),
      _ => (AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
    };

    return CircleAvatar(
      radius: small ? 13 : 17,
      backgroundColor: bg,
      child: Text(
        rank.toString(),
        style: AppTextStyles.labelMedium.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SoftEmptyMessage extends StatelessWidget {
  final String message;

  const _SoftEmptyMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.base),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _formatCompact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
