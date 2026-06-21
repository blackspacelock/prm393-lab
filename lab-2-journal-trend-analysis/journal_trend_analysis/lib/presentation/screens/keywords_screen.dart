import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/keyword.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';

enum _KeywordSort { frequency, relevance, recent, name }

class KeywordsScreen extends ConsumerStatefulWidget {
  const KeywordsScreen({super.key});

  @override
  ConsumerState<KeywordsScreen> createState() => _KeywordsScreenState();
}

class _KeywordsScreenState extends ConsumerState<KeywordsScreen> {
  final _searchController = TextEditingController();
  String _localQuery = '';
  _KeywordSort _sort = _KeywordSort.frequency;
  int _levelFilter = -1;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Keywords')),
      body: paginated.when(
        data: (_) {
          final keywords = ref.watch(keywordsProvider);
          if (keywords.isEmpty) {
            return EmptyState(
              icon: Icons.label_outline,
              message: isDefaultView
                  ? 'No keyword data is available for trending publications'
                  : 'No keyword data available for "$query"',
            );
          }
          final localQuery = _localQuery.trim().toLowerCase();
          final levelOptions = _levelOptions(keywords);
          if (_levelFilter != -1 && !levelOptions.contains(_levelFilter)) {
            _levelFilter = -1;
          }
          final visibleKeywords = _sortKeywords(
            (localQuery.isEmpty
                    ? keywords
                    : keywords.where(
                        (k) => k.name.toLowerCase().contains(localQuery),
                      ))
                .where(_matchesFilter)
                .toList(),
          );

          final trending = visibleKeywords
              .where((k) => k.trendRatio > 0.5 && k.frequency >= 2)
              .take(10)
              .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _KeywordsHero(
                  isDefaultView: isDefaultView,
                  query: query,
                  keywords: keywords,
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
                  child: _KeywordControls(
                    controller: _searchController,
                    query: _localQuery,
                    sort: _sort,
                    levelFilter: _levelFilter,
                    levelOptions: levelOptions,
                    onChanged: (value) => setState(() => _localQuery = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _localQuery = '');
                    },
                    onSortChanged: (value) => setState(() => _sort = value),
                    onFilterChanged: (value) =>
                        setState(() => _levelFilter = value),
                  ),
                ),
              ),
              if (visibleKeywords.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.base,
                    ),
                    child: _SoftEmptyMessage(
                      message: 'No keywords match "$_localQuery".',
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.base,
                      AppDimensions.md,
                      AppDimensions.base,
                      AppDimensions.sm,
                    ),
                    child: _KeywordChipCloud(keywords: visibleKeywords),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.base,
                      AppDimensions.lg,
                      AppDimensions.base,
                      AppDimensions.sm,
                    ),
                    child: _KeywordFrequencyPanel(keywords: visibleKeywords),
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
                      title: 'Trending',
                      subtitle: trending.isEmpty
                          ? 'No recent keyword spikes in this result set'
                          : 'Keywords with more than 50% recent papers',
                    ),
                  ),
                ),
                if (trending.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.base,
                      ),
                      child: _SoftEmptyMessage(
                        message:
                            'No trending keywords match the current threshold.',
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: trending.length,
                    itemBuilder: (context, index) {
                      final keyword = trending[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.base,
                          vertical: AppDimensions.xs,
                        ),
                        child: _KeywordListTile(
                          rank: index + 1,
                          keyword: keyword,
                          onTap: () => _openKeyword(context, keyword),
                        ),
                      );
                    },
                  ),
              ],
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

  bool _matchesFilter(KeywordItem keyword) {
    return _levelFilter == -1 || keyword.level == _levelFilter;
  }

  List<int> _levelOptions(List<KeywordItem> keywords) {
    return keywords.map((k) => k.level).toSet().toList()..sort();
  }

  List<KeywordItem> _sortKeywords(List<KeywordItem> keywords) {
    final sorted = List<KeywordItem>.from(keywords);
    switch (_sort) {
      case _KeywordSort.frequency:
        sorted.sort((a, b) => b.frequency.compareTo(a.frequency));
      case _KeywordSort.relevance:
        sorted.sort((a, b) => b.avgScore.compareTo(a.avgScore));
      case _KeywordSort.recent:
        sorted.sort((a, b) => b.trendRatio.compareTo(a.trendRatio));
      case _KeywordSort.name:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    return sorted;
  }
}

class _KeywordControls extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final _KeywordSort sort;
  final int levelFilter;
  final List<int> levelOptions;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<_KeywordSort> onSortChanged;
  final ValueChanged<int> onFilterChanged;

  const _KeywordControls({
    required this.controller,
    required this.query,
    required this.sort,
    required this.levelFilter,
    required this.levelOptions,
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
            hintText: 'Search keywords...',
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
              child: DropdownButtonFormField<int>(
                initialValue: levelFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.filter_list, size: 20),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: -1,
                    child: Text('All levels'),
                  ),
                  ...levelOptions.map(
                    (level) => DropdownMenuItem<int>(
                      value: level,
                      child: Text('Level $level'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onFilterChanged(value);
                },
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: DropdownButtonFormField<_KeywordSort>(
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
                    value: _KeywordSort.frequency,
                    child: Text('Frequency'),
                  ),
                  DropdownMenuItem(
                    value: _KeywordSort.relevance,
                    child: Text('Relevance'),
                  ),
                  DropdownMenuItem(
                    value: _KeywordSort.recent,
                    child: Text('Recent'),
                  ),
                  DropdownMenuItem(
                    value: _KeywordSort.name,
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

void _openKeyword(BuildContext context, KeywordItem keyword) {
  context.push('/keyword/${Uri.encodeComponent(keyword.name)}', extra: keyword);
}

class _KeywordsHero extends StatelessWidget {
  final bool isDefaultView;
  final String query;
  final List<KeywordItem> keywords;

  const _KeywordsHero({
    required this.isDefaultView,
    required this.query,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) {
    final topKeyword = keywords.first;
    final avgRelevance =
        keywords.fold<double>(0, (sum, k) => sum + k.avgScore) /
        keywords.length;

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
          _ContextPill(
            icon: isDefaultView ? Icons.trending_up : Icons.search,
            label: isDefaultView ? 'Live OpenAlex trending set' : query,
          ),
          const SizedBox(height: AppDimensions.base),
          Text(
            isDefaultView ? 'Trending Keyword Landscape' : 'Keyword Landscape',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            isDefaultView
                ? 'Concepts extracted from the default trending publication feed.'
                : 'Concepts extracted from OpenAlex results, ranked by frequency and relevance.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.base),
          _FeaturedKeyword(keyword: topKeyword),
          const SizedBox(height: AppDimensions.base),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Keywords',
                  value: keywords.length.toString(),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _MiniStat(
                  label: 'Top Freq',
                  value: topKeyword.frequency.toString(),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _MiniStat(
                  label: 'Avg Score',
                  value: avgRelevance.toStringAsFixed(2),
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedKeyword extends StatelessWidget {
  final KeywordItem keyword;

  const _FeaturedKeyword({required this.keyword});

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
            child: Icon(Icons.label, color: AppColors.onPrimary),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dominant keyword',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  keyword.name,
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
            'x${keyword.frequency}',
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

class _KeywordChipCloud extends StatelessWidget {
  final List<KeywordItem> keywords;

  const _KeywordChipCloud({required this.keywords});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Keyword Cloud',
          subtitle:
              'Tap a keyword to inspect its journals, authors, and papers',
        ),
        const SizedBox(height: AppDimensions.md),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: keywords.take(20).map((keyword) {
            return ActionChip(
              label: Text('${keyword.name}  x${keyword.frequency}'),
              avatar: const Icon(Icons.label_outline, size: 16),
              onPressed: () => _openKeyword(context, keyword),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _KeywordFrequencyPanel extends StatelessWidget {
  final List<KeywordItem> keywords;

  const _KeywordFrequencyPanel({required this.keywords});

  @override
  Widget build(BuildContext context) {
    final topKeywords = keywords.take(10).toList();
    final maxFrequency = topKeywords.first.frequency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Keyword Frequency',
          subtitle: 'Top concepts by number of matching publications',
        ),
        const SizedBox(height: AppDimensions.md),
        for (var i = 0; i < topKeywords.length; i++) ...[
          _KeywordBar(keyword: topKeywords[i], maxFrequency: maxFrequency),
          if (i != topKeywords.length - 1)
            const SizedBox(height: AppDimensions.md),
        ],
      ],
    );
  }
}

class _KeywordBar extends StatelessWidget {
  final KeywordItem keyword;
  final int maxFrequency;

  const _KeywordBar({required this.keyword, required this.maxFrequency});

  @override
  Widget build(BuildContext context) {
    final ratio = maxFrequency == 0 ? 0.0 : keyword.frequency / maxFrequency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                keyword.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              keyword.frequency.toString(),
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

class _KeywordListTile extends StatelessWidget {
  final int rank;
  final KeywordItem keyword;
  final VoidCallback onTap;

  const _KeywordListTile({
    required this.rank,
    required this.keyword,
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
          child: Row(
            children: [
              _RankBadge(rank: rank),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keyword.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      '${keyword.frequency} publications · ${(keyword.trendRatio * 100).round()}% recent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
