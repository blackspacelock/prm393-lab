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
import '../widgets/metric_card.dart';
import '../widgets/publication_card.dart';
import '../widgets/topic_cascade_dialog.dart' show TopicBrowserDialog;
import '../widgets/trend_chart.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginated = ref.watch(paginatedPublicationsProvider);
    final yearly = ref.watch(yearlyTrendProvider);
    final isLoading = paginated.isLoading || yearly.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 22,
              color: AppColors.primaryContainer,
            ),
            const SizedBox(width: AppDimensions.sm),
            Text(
              'Journal Trend Analyzer',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          const _TopicSearchBar(),
          if (isLoading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(paginatedPublicationsProvider);
                ref.invalidate(yearlyTrendProvider);
                await Future.wait([
                  ref.read(paginatedPublicationsProvider.future),
                  ref.read(yearlyTrendProvider.future),
                ]);
              },
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: _DashboardContextBanner()),
                  const SliverToBoxAdapter(child: _ChartSection()),
                  const SliverToBoxAdapter(child: _KpiRow()),
                  const SliverToBoxAdapter(child: _TrendingTopicsRow()),
                  const SliverToBoxAdapter(child: _HighlightCards()),
                  const SliverToBoxAdapter(child: _InfluentialPublication()),
                  const SliverToBoxAdapter(child: _ExploreMoreSection()),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.xl),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Context Banner ──────────────────────────────────────────────────

class _DashboardContextBanner extends ConsumerWidget {
  const _DashboardContextBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final topicFilter = ref.watch(selectedTopicFilterProvider);

    final IconData icon;
    final String label;
    final String subtitle;

    if (topicFilter != null) {
      icon = Icons.filter_alt_outlined;
      label = topicFilter.displayName;
      subtitle = 'Filtered by ${topicFilter.levelLabel.toLowerCase()}';
    } else if (query.isNotEmpty) {
      icon = Icons.search;
      label = '"$query"';
      subtitle = 'Search results';
    } else {
      icon = Icons.public;
      label = 'Global Trending Research';
      final cutoffYear = DateTime.now().year - 10;
      subtitle =
          'Top cited articles · all fields · $cutoffYear–${DateTime.now().year}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.sm,
        AppDimensions.base,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
          border: Border.all(
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryContainer),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _TopicSearchBar extends ConsumerStatefulWidget {
  const _TopicSearchBar();

  @override
  ConsumerState<_TopicSearchBar> createState() => _TopicSearchBarState();
}

class _TopicSearchBarState extends ConsumerState<_TopicSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = trimmed;
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
  }

  Future<void> _openCascade() async {
    final selected = await showDialog<TopicHierarchyItem>(
      context: context,
      builder: (_) => const TopicBrowserDialog(),
    );
    if (selected == null) return;
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedTopicFilterProvider.notifier).state = selected;
    ref.read(searchPageProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final topicFilter = ref.watch(selectedTopicFilterProvider);
    final query = ref.watch(searchQueryProvider);
    final hasActive = topicFilter != null || query.isNotEmpty;

    ref.listen(searchQueryProvider, (_, next) {
      if (_controller.text != next) {
        _controller.text = next;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: next.length),
        );
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          // ── Search field ─────────────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _controller,
                enabled: topicFilter == null,
                decoration: InputDecoration(
                  hintText: topicFilter != null
                      ? topicFilter.displayName
                      : 'Search papers...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: hasActive
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _clear,
                          tooltip: 'Clear',
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.shapeFull,
                    ),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),

          const SizedBox(width: AppDimensions.sm),

          // ── Browse button ─────────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openCascade,
              icon: Icon(
                topicFilter != null ? Icons.explore : Icons.explore_outlined,
                size: 18,
                color: topicFilter != null
                    ? AppColors.primaryContainer
                    : AppColors.onSurfaceVariant,
              ),
              label: Text(
                'Browse',
                style: AppTextStyles.labelMedium.copyWith(
                  color: topicFilter != null
                      ? AppColors.primaryContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                side: BorderSide(
                  color: topicFilter != null
                      ? AppColors.primaryContainer
                      : AppColors.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
                ),
                minimumSize: const Size(104, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart Section ─────────────────────────────────────────────────────────────

class _ChartSection extends ConsumerWidget {
  const _ChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearly = ref.watch(yearlyTrendProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        0,
      ),
      child: SizedBox(
        height: 200,
        child: yearly.when(
          loading: () => const _BoxShimmer(height: 200),
          error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(yearlyTrendProvider),
          ),
          data: (trendData) {
            if (trendData.isEmpty) {
              return const EmptyState(
                icon: Icons.show_chart,
                message: 'No trend data available',
              );
            }
            return TrendChart(data: trendData);
          },
        ),
      ),
    );
  }
}

// ── KPI Row ───────────────────────────────────────────────────────────────────

class _KpiRow extends ConsumerWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearly = ref.watch(yearlyTrendProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        0,
      ),
      child: yearly.when(
        loading: () => const Row(
          children: [
            Expanded(child: _BoxShimmer(height: 88)),
            SizedBox(width: AppDimensions.sm),
            Expanded(child: _BoxShimmer(height: 88)),
            SizedBox(width: AppDimensions.sm),
            Expanded(child: _BoxShimmer(height: 88)),
          ],
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (trendData) {
          final totalPapers = trendData.fold<int>(
            0,
            (sum, item) => sum + item.publicationCount,
          );
          final peakYear = trendData.isEmpty
              ? null
              : trendData
                    .reduce(
                      (a, b) =>
                          a.publicationCount >= b.publicationCount ? a : b,
                    )
                    .year;
          final avgPerYear = trendData.isEmpty
              ? 0
              : totalPapers / trendData.length;

          return Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Total Papers',
                  value: totalPapers == 0
                      ? '—'
                      : Formatter.formatCitationCount(totalPapers),
                  icon: Icons.article_outlined,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: MetricCard(
                  title: 'Avg / Year',
                  value: totalPapers == 0
                      ? '—'
                      : Formatter.formatCitationCount(avgPerYear.round()),
                  icon: Icons.insights_outlined,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: MetricCard(
                  title: 'Peak Year',
                  value: peakYear?.toString() ?? '—',
                  icon: Icons.calendar_today_outlined,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Highlight Cards ───────────────────────────────────────────────────────────

class _HighlightCards extends ConsumerWidget {
  const _HighlightCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginated = ref.watch(paginatedPublicationsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        0,
      ),
      child: paginated.when(
        loading: () => const Row(
          children: [
            Expanded(child: _BoxShimmer(height: 96)),
            SizedBox(width: AppDimensions.sm),
            Expanded(child: _BoxShimmer(height: 96)),
          ],
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (_) {
          final summary = ref.watch(dashboardSummaryProvider);
          if (summary.totalPublications == 0) return const SizedBox.shrink();
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _HighlightCard(
                    label: 'Top Journal',
                    title: summary.topJournalName ?? '—',
                    subtitle:
                        '${summary.topJournalPublications ?? 0} papers · '
                        '${Formatter.formatCitationCount(summary.topJournalCitations ?? 0)} cited',
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: _HighlightCard(
                    label: 'Top Author',
                    title: summary.topAuthorName ?? '—',
                    subtitle:
                        '${summary.topAuthorPublications ?? 0} papers · '
                        '${Formatter.formatCitationCount(summary.topAuthorCitations ?? 0)} cited',
                    icon: Icons.person_outlined,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;

  const _HighlightCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primaryContainer),
              const SizedBox(width: AppDimensions.xs),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            subtitle,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Most Influential Publication ──────────────────────────────────────────────

class _InfluentialPublication extends ConsumerWidget {
  const _InfluentialPublication();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginated = ref.watch(paginatedPublicationsProvider);

    if (paginated.isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.base,
          AppDimensions.base,
          AppDimensions.base,
          0,
        ),
        child: _BoxShimmer(height: 88),
      );
    }
    if (paginated.hasError) return const SizedBox.shrink();

    final summary = ref.watch(dashboardSummaryProvider);
    final paper = summary.mostInfluentialPaper;
    if (paper == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most Influential Paper',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: PublicationCard(
              publication: paper,
              onTap: () =>
                  context.push('/publication/${paper.id}', extra: paper),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Explore More ──────────────────────────────────────────────────────────────

class _ExploreMoreSection extends StatelessWidget {
  const _ExploreMoreSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore More',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ExploreCard(
                    title: 'Publication Heatmap',
                    subtitle: 'Yearly distribution by topic',
                    icon: Icons.grid_view_rounded,
                    onTap: () => context.push('/heatmap'),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: _ExploreCard(
                    title: 'Author Network',
                    subtitle: 'Co-authorship connections',
                    icon: Icons.hub_outlined,
                    onTap: () => context.push('/network'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ExploreCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: AppColors.primaryContainer),
              const SizedBox(height: AppDimensions.sm),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                subtitle,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Trending Topics Row ───────────────────────────────────────────────────────

class _TrendingTopicsRow extends ConsumerWidget {
  const _TrendingTopicsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginated = ref.watch(paginatedPublicationsProvider);
    if (paginated.isLoading || paginated.hasError) {
      return const SizedBox.shrink();
    }

    final topics = ref.watch(trendingTopicsProvider);
    if (topics.isEmpty) return const SizedBox.shrink();

    final currentQuery = ref.watch(searchQueryProvider);
    final currentFilter = ref.watch(selectedTopicFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.base,
        AppDimensions.base,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
                  ),
                  child: Icon(
                    Icons.travel_explore_outlined,
                    size: 20,
                    color: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore Topics',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        'Jump into active research themes from the current results.',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showTopicBrowser(context, ref),
                  icon: const Icon(Icons.tune_outlined, size: 16),
                  label: const Text('Browse'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryContainer,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: topics.take(10).map((topic) {
                final isSelected =
                    currentFilter == null && currentQuery == topic;
                return FilterChip(
                  label: Text(
                    topic,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.outlineVariant,
                  ),
                  backgroundColor: AppColors.surfaceContainerHigh,
                  selectedColor: AppColors.primaryContainer,
                  onSelected: (_) {
                    if (isSelected) {
                      ref.read(searchQueryProvider.notifier).state = '';
                      ref.read(searchPageProvider.notifier).state = 1;
                    } else {
                      ref.read(selectedTopicFilterProvider.notifier).state =
                          null;
                      ref.read(searchQueryProvider.notifier).state = topic;
                      ref.read(searchPageProvider.notifier).state = 1;
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTopicBrowser(BuildContext context, WidgetRef ref) async {
    final selected = await showDialog<TopicHierarchyItem>(
      context: context,
      builder: (_) => const TopicBrowserDialog(),
    );
    if (selected == null) return;
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedTopicFilterProvider.notifier).state = selected;
    ref.read(searchPageProvider.notifier).state = 1;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _BoxShimmer extends StatelessWidget {
  final double height;
  const _BoxShimmer({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
      ),
    );
  }
}
