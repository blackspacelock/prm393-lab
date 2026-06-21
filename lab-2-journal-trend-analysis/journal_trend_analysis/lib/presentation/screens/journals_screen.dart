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

class JournalsScreen extends ConsumerWidget {
  const JournalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider).trim();
    final isDefaultView = query.isEmpty;
    final paginated = ref.watch(paginatedPublicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Journals')),
      body: paginated.when(
        data: (result) {
          final journals = ref.watch(topJournalsProvider);
          if (journals.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              message: isDefaultView
                  ? 'No journal data is available for trending publications'
                  : 'No journal data available for "$query"',
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroSummary(
                  isDefaultView: isDefaultView,
                  query: query,
                  publications: result.items,
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
                  child: _TopSourcesPanel(journals: journals),
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
                    subtitle: '${journals.length} journals ordered by activity',
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: journals.length,
                itemBuilder: (context, index) {
                  final journal = journals[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.base,
                      vertical: AppDimensions.xs,
                    ),
                    child: _JournalListTile(
                      rank: index + 1,
                      journal: journal,
                      maxCount: journals.first.publicationCount,
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
