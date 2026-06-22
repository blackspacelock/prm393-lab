import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  int _selectedIndex = 0;

  // Accumulated publications for pagination
  List<Publication> _allPubs = [];
  int _totalCount = 0;
  bool _hasMore = true;
  int _currentPage = 1;
  int _lastProcessedPage = 0;
  String? _lastDomainId;

  @override
  void initState() {
    super.initState();
    // Reset page to 1 when entering the screen to avoid stale accumulated state
    // after navigating away and back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final categories =
          ref.read(trendingCategoriesProvider).value ??
          const <TopicHierarchyItem>[];
      final domainId = _selectedIndex == 0 || _selectedIndex > categories.length
          ? null
          : categories[_selectedIndex - 1].id;
      ref.read(trendingPageProvider(domainId).notifier).state = 1;
    });
  }

  void _onCategoryChanged(int index) {
    setState(() {
      _selectedIndex = index;
      _resetList();
    });
    // Reset page provider for the new domain
    final categories =
        ref.read(trendingCategoriesProvider).value ??
        const <TopicHierarchyItem>[];
    final newDomainId = index == 0 || index > categories.length
        ? null
        : categories[index - 1].id;
    ref.read(trendingPageProvider(newDomainId).notifier).state = 1;
  }

  void _resetList() {
    _allPubs = [];
    _totalCount = 0;
    _hasMore = true;
    _currentPage = 1;
    _lastProcessedPage = 0;
  }

  void _showMore(String? domainId) {
    _currentPage++;
    ref.read(trendingPageProvider(domainId).notifier).state = _currentPage;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(trendingCategoriesProvider);
    final categories = categoriesAsync.value ?? const <TopicHierarchyItem>[];
    if (_selectedIndex > categories.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = 0);
      });
    }
    final selectedDomainId =
        _selectedIndex == 0 || _selectedIndex > categories.length
        ? null
        : categories[_selectedIndex - 1].id;

    // Reset accumulated list when domain changes
    if (selectedDomainId != _lastDomainId) {
      _lastDomainId = selectedDomainId;
      _resetList();
    }

    final pubAsync = ref.watch(trendingPublicationsProvider(selectedDomainId));

    // Accumulate results
    pubAsync.whenData((paginated) {
      if (paginated.page <= _lastProcessedPage && _currentPage != 1) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _totalCount = paginated.totalCount;
          if (paginated.page == 1) {
            _allPubs = List.from(paginated.items);
          } else {
            _allPubs = [..._allPubs, ...paginated.items];
          }
          _lastProcessedPage = paginated.page;
          _hasMore = paginated.hasNextPage;
        });
      });
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: AppColors.surfaceContainerLowest,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _CategoryChips(
            categoriesAsync: categoriesAsync,
            selectedIndex: _selectedIndex,
            onSelected: _onCategoryChanged,
          ),
        ),
      ),
      body: pubAsync.when(
        loading: () => _allPubs.isEmpty
            ? const ShimmerLoader()
            : _buildBody(selectedDomainId),
        error: (e, _) => _allPubs.isEmpty
            ? ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(
                  trendingPublicationsProvider(selectedDomainId),
                ),
              )
            : _buildBody(selectedDomainId),
        data: (_) => _allPubs.isEmpty
            ? const EmptyState(
                icon: Icons.trending_up,
                message: 'No trending papers found for this category.',
              )
            : _buildBody(selectedDomainId),
      ),
    );
  }

  Widget _buildBody(String? domainId) {
    // +1 for dashboard, +1 for title, +1 for show more button
    final itemCount = _allPubs.length + 2 + (_hasMore ? 1 : 0);

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, i) {
        // Dashboard at the top
        if (i == 0) {
          return _TrendingDashboard(
            publications: _allPubs,
            totalPapersInDomain: _totalCount,
          );
        }
        // "Trending" title with count
        if (i == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.base,
              AppDimensions.sm,
              AppDimensions.base,
              AppDimensions.xs,
            ),
            child: Row(
              children: [
                Text(
                  'Trending',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Showing ${_allPubs.length} of ${Formatter.formatCitationCount(_totalCount)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final pubIndex = i - 2;

        // "Show more" button at the end
        if (pubIndex >= _allPubs.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.base,
              vertical: AppDimensions.base,
            ),
            child: Center(
              child: pubAsync.isLoading
                  ? const CircularProgressIndicator()
                  : FilledButton.tonal(
                      onPressed: () => _showMore(domainId),
                      child: const Text('Show more'),
                    ),
            ),
          );
        }

        final pub = _allPubs[pubIndex];
        return Column(
          children: [
            if (pubIndex > 0)
              const Divider(
                height: 1,
                indent: AppDimensions.base,
                endIndent: AppDimensions.base,
                color: AppColors.outlineVariant,
              ),
            _RankedPublicationTile(
              rank: pubIndex + 1,
              publication: pub,
              onTap: () => context.push(
                '/publication/${Uri.encodeComponent(pub.id)}',
                extra: pub,
              ),
            ),
          ],
        );
      },
    );
  }

  AsyncValue get pubAsync {
    final categories =
        ref.read(trendingCategoriesProvider).value ??
        const <TopicHierarchyItem>[];
    final selectedDomainId =
        _selectedIndex == 0 || _selectedIndex > categories.length
        ? null
        : categories[_selectedIndex - 1].id;
    return ref.watch(trendingPublicationsProvider(selectedDomainId));
  }
}

// ── Ranked Publication Tile ───────────────────────────────────────────────────

class _RankedPublicationTile extends StatelessWidget {
  final int rank;
  final Publication publication;
  final VoidCallback? onTap;

  const _RankedPublicationTile({
    required this.rank,
    required this.publication,
    this.onTap,
  });

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rank badge
            _RankBadge(rank: rank),
            const SizedBox(width: AppDimensions.md),
            // Publication info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    publication.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Row(
                    children: [
                      if (publication.publicationYear != null) ...[
                        Text(
                          '${publication.publicationYear}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                      ],
                      Icon(
                        Icons.format_quote,
                        size: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppDimensions.xs),
                      Text(
                        '${Formatter.formatCitationCount(publication.citedByCount)} citations',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (publication.authors.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      publication.authors
                              .map((a) => a.displayName)
                              .take(3)
                              .join(', ') +
                          (publication.authors.length > 3 ? ' et al.' : ''),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
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
      radius: 16,
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

// ── Category chip row ─────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final AsyncValue<List<TopicHierarchyItem>> categoriesAsync;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _CategoryChips({
    required this.categoriesAsync,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return categoriesAsync.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.base,
            vertical: AppDimensions.sm,
          ),
          children: [
            _CategoryChip(
              icon: Icons.auto_awesome,
              label: 'All Fields',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
          ],
        ),
      ),
      data: (categories) => SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.base,
            vertical: AppDimensions.sm,
          ),
          itemCount: categories.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.sm),
          itemBuilder: (_, i) {
            if (i == 0) {
              return _CategoryChip(
                icon: Icons.auto_awesome,
                label: 'All Fields',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              );
            }
            final category = categories[i - 1];
            return _CategoryChip(
              icon: Icons.category_outlined,
              label: category.displayName,
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected
            ? AppColors.onSecondaryContainer
            : AppColors.onSurfaceVariant,
      ),
      label: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: selected
              ? AppColors.onSecondaryContainer
              : AppColors.onSurface,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.surfaceContainerLowest,
      selectedColor: AppColors.secondaryContainer,
      side: BorderSide(
        color: selected ? AppColors.primaryContainer : AppColors.outlineVariant,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Trending Dashboard ────────────────────────────────────────────────────────

class _TrendingDashboard extends StatelessWidget {
  final List<Publication> publications;
  final int totalPapersInDomain;

  const _TrendingDashboard({
    required this.publications,
    required this.totalPapersInDomain,
  });

  @override
  Widget build(BuildContext context) {
    if (publications.isEmpty) return const SizedBox.shrink();

    // Use totalPapersInDomain from API for the "Total Papers" KPI
    final totalCitations = publications.fold<int>(
      0,
      (sum, pub) => sum + pub.citedByCount,
    );

    // Compute avg citations per year
    final Map<int, int> citationsByYear = {};
    final Map<int, int> papersByYear = {};
    for (final pub in publications) {
      final year = pub.publicationYear;
      if (year == null) continue;
      papersByYear[year] = (papersByYear[year] ?? 0) + 1;
      citationsByYear[year] = (citationsByYear[year] ?? 0) + pub.citedByCount;
    }

    final yearsWithData = papersByYear.keys.toList()..sort();
    final numYears = yearsWithData.length;
    final avgCitationsPerYear = numYears > 0 ? totalCitations / numYears : 0.0;

    // Most active year
    int? mostActiveYear;
    int maxPapers = 0;
    for (final entry in papersByYear.entries) {
      if (entry.value > maxPapers) {
        maxPapers = entry.value;
        mostActiveYear = entry.key;
      }
    }

    // Build line chart data
    final chartData = yearsWithData
        .map((year) => _YearPoint(year: year, count: papersByYear[year] ?? 0))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.base),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.base,
                AppDimensions.base,
                AppDimensions.sm,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DashboardKpi(
                        label: 'Total Papers',
                        value: Formatter.formatCitationCount(
                          totalPapersInDomain,
                        ),
                        icon: Icons.article,
                        iconColor: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _DashboardKpi(
                        label: 'Avg Citations/Year',
                        value: Formatter.formatDouble(avgCitationsPerYear),
                        icon: Icons.format_quote,
                        iconColor: AppColors.metricOrange,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _DashboardKpi(
                        label: 'Most Active Year',
                        value: mostActiveYear?.toString() ?? 'N/A',
                        icon: Icons.calendar_today,
                        iconColor: AppColors.metricGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Publications per year chart
            if (chartData.length >= 2) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  0,
                  AppDimensions.base,
                  AppDimensions.xs,
                ),
                child: Text(
                  'Publications / Year',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                height: 160,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.sm,
                    0,
                    AppDimensions.base,
                    AppDimensions.base,
                  ),
                  child: _TrendingLineChart(data: chartData),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _YearPoint {
  final int year;
  final int count;
  const _YearPoint({required this.year, required this.count});
}

class _DashboardKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _DashboardKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: AppDimensions.xs),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TrendingLineChart extends StatelessWidget {
  final List<_YearPoint> data;

  const _TrendingLineChart({required this.data});

  bool _shouldShowYearLabel(int year, int firstYear, int lastYear) {
    if (year == firstYear || year == lastYear) return true;
    return (year - firstYear) % 5 == 0;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data
        .map((e) => e.count)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    final firstYear = data.first.year;
    final lastYear = data.last.year;
    final horizontalInterval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1.0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.25,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.onSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final d = data[spot.x.toInt()];
                return LineTooltipItem(
                  '${d.year}\n${d.count} papers',
                  const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                final year = data[idx].year;
                if (!_shouldShowYearLabel(year, firstYear, lastYear)) {
                  return const SizedBox.shrink();
                }
                return Transform.rotate(
                  angle: -0.5,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      year.toString(),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: horizontalInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.surfaceContainerHigh,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) => FlSpot(i.toDouble(), data[i].count.toDouble()),
            ),
            isCurved: true,
            color: AppColors.primaryContainer,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length <= 24,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 2.5,
                color: AppColors.primaryContainer,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
