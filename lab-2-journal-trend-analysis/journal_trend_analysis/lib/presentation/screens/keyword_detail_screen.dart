import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/usecases/get_top_authors.dart';
import '../../domain/usecases/get_top_journals.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/publication_card.dart';
import '../widgets/trend_chart.dart';

class KeywordDetailScreen extends ConsumerWidget {
  final KeywordItem keyword;

  const KeywordDetailScreen({required this.keyword, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publications = ref.watch(keywordPublicationsProvider(keyword.name));
    final trend = ref.watch(keywordTrendProvider(keyword.name));
    final journals = ref.watch(keywordJournalsProvider(keyword.name));
    final authors = ref
        .watch(keywordAuthorsProvider(keyword.name))
        .take(10)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(keyword.name, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _KeywordHero(keyword: keyword)),
          if (trend.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  AppDimensions.lg,
                  AppDimensions.base,
                  AppDimensions.sm,
                ),
                child: _TrendPanel(trend: trend),
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
              child: const _SectionHeader(
                title: 'Related Journals',
                subtitle: 'Top sources publishing this keyword',
              ),
            ),
          ),
          if (journals.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppDimensions.base),
                child: _SoftEmptyMessage(message: 'No related journal data.'),
              ),
            )
          else
            SliverList.builder(
              itemCount: journals.length,
              itemBuilder: (context, index) {
                final journal = journals[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
                    vertical: AppDimensions.xs,
                  ),
                  child: _JournalTile(
                    rank: index + 1,
                    journal: journal,
                    onTap: () => context.push(
                      '/journal/${Uri.encodeComponent(journal.name)}',
                      extra: journal,
                    ),
                  ),
                );
              },
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.lg,
                AppDimensions.base,
                AppDimensions.xs,
              ),
              child: const _SectionHeader(
                title: 'Top Authors',
                subtitle: 'Authors ranked by keyword publication count',
              ),
            ),
          ),
          if (authors.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppDimensions.base),
                child: _SoftEmptyMessage(message: 'No related author data.'),
              ),
            )
          else
            SliverList.builder(
              itemCount: authors.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
                    vertical: AppDimensions.xs,
                  ),
                  child: _AuthorTile(rank: index + 1, author: authors[index]),
                );
              },
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
                title: 'Related Publications',
                subtitle: publications.isEmpty
                    ? 'No matching papers in the current result set'
                    : 'Top cited papers mentioning this keyword',
              ),
            ),
          ),
          if (publications.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                message:
                    'No publications mention this keyword in current search',
              ),
            )
          else
            SliverList.separated(
              itemCount: publications.take(5).length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: AppDimensions.base,
                endIndent: AppDimensions.base,
                color: AppColors.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final pub = publications[index];
                return PublicationCard(
                  publication: pub,
                  onTap: () => context.push(
                    '/publication/${Uri.encodeComponent(pub.id)}',
                    extra: pub,
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.xl)),
        ],
      ),
    );
  }
}

class _KeywordHero extends StatelessWidget {
  final KeywordItem keyword;

  const _KeywordHero({required this.keyword});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ContextPill(),
          const SizedBox(height: AppDimensions.base),
          Text(
            keyword.name,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'Keyword-level trend, source, author, and publication analysis.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.base),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Publications',
                  value: keyword.frequency.toString(),
                  icon: Icons.article_outlined,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _StatBlock(
                  label: 'Avg Relevance',
                  value: keyword.avgScore.toStringAsFixed(2),
                  icon: Icons.auto_graph_outlined,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _StatBlock(
                  label: 'Recent',
                  value: '${(keyword.trendRatio * 100).round()}%',
                  icon: Icons.trending_up,
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
  const _ContextPill();

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
          const Icon(Icons.label, size: 16, color: AppColors.primaryContainer),
          const SizedBox(width: AppDimensions.xs),
          Text(
            'Keyword Detail',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBlock({
    required this.label,
    required this.value,
    required this.icon,
  });

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
          Icon(icon, size: 18, color: AppColors.primaryContainer),
          const SizedBox(height: AppDimensions.sm),
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

class _TrendPanel extends StatelessWidget {
  final List trend;

  const _TrendPanel({required this.trend});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Publication Trend',
          subtitle: 'Keyword mentions over publication years',
        ),
        const SizedBox(height: AppDimensions.md),
        SizedBox(height: 220, child: TrendChart(data: trend.cast())),
      ],
    );
  }
}

class _JournalTile extends StatelessWidget {
  final int rank;
  final JournalWithCount journal;
  final VoidCallback onTap;

  const _JournalTile({
    required this.rank,
    required this.journal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _RankedSurfaceTile(
      rank: rank,
      title: journal.name,
      subtitle:
          '${journal.publicationCount} publications · ${journal.totalCitations} citations',
      onTap: onTap,
    );
  }
}

class _AuthorTile extends StatelessWidget {
  final int rank;
  final AuthorWithCount author;

  const _AuthorTile({required this.rank, required this.author});

  @override
  Widget build(BuildContext context) {
    return _RankedSurfaceTile(
      rank: rank,
      title: author.author.displayName,
      subtitle:
          '${author.publicationCount} publications · ${author.totalCitations} citations',
    );
  }
}

class _RankedSurfaceTile extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _RankedSurfaceTile({
    required this.rank,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppDimensions.sm),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
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
      radius: 17,
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
