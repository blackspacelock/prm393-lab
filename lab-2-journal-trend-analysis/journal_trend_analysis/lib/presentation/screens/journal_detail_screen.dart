import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/publication.dart';
import '../../domain/usecases/get_top_journals.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';

class JournalDetailScreen extends ConsumerWidget {
  final JournalWithCount journal;

  const JournalDetailScreen({required this.journal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publications = ref.watch(journalPublicationsProvider(journal.name));
    final avgCitations = journal.publicationCount == 0
        ? 0.0
        : journal.totalCitations / journal.publicationCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(journal.name, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _JournalDetailHero(
              journal: journal,
              avgCitations: avgCitations,
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
                title: 'Related Publications',
                subtitle: publications.isEmpty
                    ? 'No matching papers in the current result set'
                    : '${publications.length} papers sorted by citations',
              ),
            ),
          ),
          if (publications.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                message: 'No publications from this journal in current search',
              ),
            )
          else
            SliverList.builder(
              itemCount: publications.length,
              itemBuilder: (context, index) {
                final pub = publications[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
                    vertical: AppDimensions.xs,
                  ),
                  child: _PublicationResultTile(
                    publication: pub,
                    onTap: () => context.push(
                      '/publication/${Uri.encodeComponent(pub.id)}',
                      extra: pub,
                    ),
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

class _JournalDetailHero extends StatelessWidget {
  final JournalWithCount journal;
  final double avgCitations;

  const _JournalDetailHero({required this.journal, required this.avgCitations});

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
            journal.name,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'A focused view of this journal within your active publication collection.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.base),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Papers',
                  value: journal.publicationCount.toString(),
                  icon: Icons.article_outlined,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _StatBlock(
                  label: 'Citations',
                  value: _formatCompact(journal.totalCitations),
                  icon: Icons.format_quote,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _StatBlock(
                  label: 'Avg',
                  value: avgCitations.toStringAsFixed(1),
                  icon: Icons.insights_outlined,
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
          const Icon(
            Icons.menu_book_outlined,
            size: 16,
            color: AppColors.primaryContainer,
          ),
          const SizedBox(width: AppDimensions.xs),
          Text(
            'Journal Detail',
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
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicationResultTile extends StatelessWidget {
  final Publication publication;
  final VoidCallback onTap;

  const _PublicationResultTile({
    required this.publication,
    required this.onTap,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                publication.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.xs,
                runSpacing: AppDimensions.xs,
                children: [
                  _InfoPill(
                    icon: Icons.calendar_today_outlined,
                    label: Formatter.formatYear(publication.publicationYear),
                  ),
                  _InfoPill(
                    icon: Icons.format_quote,
                    label:
                        '${Formatter.formatCitationCount(publication.citedByCount)} citations',
                  ),
                  _InfoPill(
                    icon: Icons.people_alt_outlined,
                    label: '${publication.authors.length} authors',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
