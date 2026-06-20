import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/heatmap_data.dart';
import '../providers/heatmap_providers.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_loader.dart';

/// Display mode for country data: grid tiles or world map.
enum CountryDisplayMode { grid, worldMap }

final countryDisplayModeProvider = StateProvider<CountryDisplayMode>(
  (_) => CountryDisplayMode.worldMap,
);

class HeatmapScreen extends ConsumerWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final viewMode = ref.watch(heatmapViewModeProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Current topic indicator
          if (query.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.base,
                vertical: AppDimensions.sm,
              ),
              color: AppColors.citationChipBg,
              child: Row(
                children: [
                  const Icon(Icons.topic, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      'Topic: $query',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.citationChipText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // View mode toggle
          Padding(
            padding: const EdgeInsets.all(AppDimensions.base),
            child: SegmentedButton<HeatmapViewMode>(
              segments: const [
                ButtonSegment(
                  value: HeatmapViewMode.country,
                  icon: Icon(Icons.public, size: 18),
                  label: Text('Countries'),
                ),
                ButtonSegment(
                  value: HeatmapViewMode.institution,
                  icon: Icon(Icons.school, size: 18),
                  label: Text('Institutions'),
                ),
              ],
              selected: {viewMode},
              onSelectionChanged: (selected) {
                ref.read(heatmapViewModeProvider.notifier).state =
                    selected.first;
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.secondaryContainer,
                selectedForegroundColor: AppColors.onSecondaryContainer,
              ),
            ),
          ),

          // Content
          Expanded(
            child: query.isEmpty
                ? const EmptyState(
                    icon: Icons.map_outlined,
                    message:
                        'Search for a topic in the Keywords tab to see the geographic distribution of research.',
                  )
                : viewMode == HeatmapViewMode.country
                ? const _CountryHeatmapView()
                : const _InstitutionListView(),
          ),
        ],
      ),
    );
  }
}

// ── Country Heatmap View ──────────────────────────────────────────────────────

class _CountryHeatmapView extends ConsumerWidget {
  const _CountryHeatmapView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(countryDistributionProvider);

    return asyncData.when(
      loading: () => const ShimmerLoader(itemCount: 8),
      error: (err, _) => ErrorState(
        message: err.toString(),
        onRetry: () => ref.invalidate(countryDistributionProvider),
      ),
      data: (countries) {
        if (countries.isEmpty) {
          return const EmptyState(
            icon: Icons.public_off,
            message: 'No geographic data available for this topic.',
          );
        }
        return _CountryHeatmapContent(countries: countries);
      },
    );
  }
}

class _CountryHeatmapContent extends ConsumerWidget {
  final List<CountryHeatmapData> countries;

  const _CountryHeatmapContent({required this.countries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = ref.watch(countryDisplayModeProvider);
    final maxCount = countries.first.worksCount;

    return CustomScrollView(
      slivers: [
        // Summary header + display mode toggle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${countries.length} countries contributing',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            'Ranked by number of publications',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Display mode toggle
                    SegmentedButton<CountryDisplayMode>(
                      segments: const [
                        ButtonSegment(
                          value: CountryDisplayMode.worldMap,
                          icon: Icon(Icons.map, size: 16),
                        ),
                        ButtonSegment(
                          value: CountryDisplayMode.grid,
                          icon: Icon(Icons.grid_view, size: 16),
                        ),
                      ],
                      selected: {displayMode},
                      onSelectionChanged: (selected) {
                        ref.read(countryDisplayModeProvider.notifier).state =
                            selected.first;
                      },
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        selectedBackgroundColor: AppColors.secondaryContainer,
                        selectedForegroundColor: AppColors.onSecondaryContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.base),
                // Color scale legend
                _buildColorLegend(),
                const SizedBox(height: AppDimensions.base),
              ],
            ),
          ),
        ),

        // World Map or Grid view
        SliverToBoxAdapter(
          child: displayMode == CountryDisplayMode.worldMap
              ? _WorldMapWidget(countries: countries, maxCount: maxCount)
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
                  ),
                  child: _buildHeatmapGrid(
                    countries.take(30).toList(),
                    maxCount,
                  ),
                ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.lg)),

        // Full ranked list
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.base),
            child: Text(
              'Full Ranking',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.sm)),

        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final country = countries[index];
            final ratio = country.worksCount / maxCount;
            return _CountryRankTile(
              rank: index + 1,
              country: country,
              ratio: ratio,
            );
          }, childCount: countries.length),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.xxl)),
      ],
    );
  }

  Widget _buildColorLegend() {
    return Row(
      children: [
        Text('Low', style: AppTextStyles.labelSmall),
        const SizedBox(width: AppDimensions.xs),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE3F2FD),
                  Color(0xFF90CAF9),
                  Color(0xFF42A5F5),
                  Color(0xFF1565C0),
                  Color(0xFF0D47A1),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.xs),
        Text('High', style: AppTextStyles.labelSmall),
      ],
    );
  }

  Widget _buildHeatmapGrid(List<CountryHeatmapData> top, int maxCount) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: top.map((country) {
        final ratio = country.worksCount / maxCount;
        final color = _heatColor(ratio);
        return Tooltip(
          message: '${country.countryName}: ${country.worksCount} works',
          child: Container(
            width: 72,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  country.countryCode,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: ratio > 0.5 ? Colors.white : AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatCount(country.worksCount),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: ratio > 0.5
                        ? Colors.white70
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── World Map Widget ──────────────────────────────────────────────────────────

class _WorldMapWidget extends StatefulWidget {
  final List<CountryHeatmapData> countries;
  final int maxCount;

  const _WorldMapWidget({required this.countries, required this.maxCount});

  @override
  State<_WorldMapWidget> createState() => _WorldMapWidgetState();
}

class _WorldMapWidgetState extends State<_WorldMapWidget> {
  String? _hoveredCountry;
  int? _hoveredCount;

  Map<String, Color> _buildColorMap() {
    final colorMap = <String, Color>{};
    for (final country in widget.countries) {
      // Convert ISO code (e.g. "US") to lowercase key used by countries_world_map ("us")
      final key = country.countryCode.toLowerCase();
      final ratio = country.worksCount / widget.maxCount;
      colorMap[key] = _heatColor(ratio);
    }
    return colorMap;
  }

  Color _heatColor(double ratio) {
    if (ratio > 0.8) return const Color(0xFF0D47A1);
    if (ratio > 0.6) return const Color(0xFF1565C0);
    if (ratio > 0.4) return const Color(0xFF1E88E5);
    if (ratio > 0.2) return const Color(0xFF42A5F5);
    if (ratio > 0.1) return const Color(0xFF90CAF9);
    if (ratio > 0.05) return const Color(0xFFBBDEFB);
    return const Color(0xFFE3F2FD);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tooltip area
        Container(
          height: 32,
          alignment: Alignment.center,
          child: _hoveredCountry != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.onSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
                  ),
                  child: Text(
                    '$_hoveredCountry: ${_formatCount(_hoveredCount ?? 0)} works',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(
                  'Tap a country to see details',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
        ),
        const SizedBox(height: AppDimensions.sm),
        // Map
        SizedBox(
          height: 260,
          child: InteractiveViewer(
            maxScale: 5.0,
            minScale: 1.0,
            child: SimpleMap(
              instructions: SMapWorld.instructions,
              defaultColor: AppColors.surfaceContainerHigh,
              countryBorder: const CountryBorder(
                color: Colors.white,
                width: 0.5,
              ),
              colors: _buildColorMap(),
              callback: (id, name, tapDetails) {
                final code = id.toUpperCase();
                final match = widget.countries
                    .where((c) => c.countryCode == code)
                    .toList();
                setState(() {
                  if (match.isNotEmpty) {
                    _hoveredCountry = match.first.countryName;
                    _hoveredCount = match.first.worksCount;
                  } else {
                    _hoveredCountry = name.isNotEmpty ? name : code;
                    _hoveredCount = 0;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ── Country Rank Tile ─────────────────────────────────────────────────────────

class _CountryRankTile extends StatelessWidget {
  final int rank;
  final CountryHeatmapData country;
  final double ratio;

  const _CountryRankTile({
    required this.rank,
    required this.country,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.base,
        vertical: AppDimensions.xs,
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: AppTextStyles.labelMedium.copyWith(
                color: _rankColor(rank),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          // Country code chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm,
              vertical: AppDimensions.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
            ),
            child: Text(
              country.countryCode,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          // Country name
          Expanded(
            child: Text(
              country.countryName,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          // Bar + count
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(_barColor(ratio)),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  _formatCount(country.worksCount),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return AppColors.rankGold;
    if (rank == 2) return AppColors.rankSilver;
    if (rank == 3) return AppColors.rankBronze;
    return AppColors.onSurfaceVariant;
  }

  Color _barColor(double ratio) {
    if (ratio > 0.6) return const Color(0xFF1565C0);
    if (ratio > 0.3) return const Color(0xFF42A5F5);
    return const Color(0xFF90CAF9);
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ── Shared helper ─────────────────────────────────────────────────────────────

Color _heatColor(double ratio) {
  if (ratio > 0.8) return const Color(0xFF0D47A1);
  if (ratio > 0.6) return const Color(0xFF1565C0);
  if (ratio > 0.4) return const Color(0xFF42A5F5);
  if (ratio > 0.2) return const Color(0xFF90CAF9);
  return const Color(0xFFE3F2FD);
}

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

// ── Institution List View ─────────────────────────────────────────────────────

class _InstitutionListView extends ConsumerWidget {
  const _InstitutionListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(institutionDistributionProvider);

    return asyncData.when(
      loading: () => const ShimmerLoader(itemCount: 8),
      error: (err, _) => ErrorState(
        message: err.toString(),
        onRetry: () => ref.invalidate(institutionDistributionProvider),
      ),
      data: (institutions) {
        if (institutions.isEmpty) {
          return const EmptyState(
            icon: Icons.school_outlined,
            message: 'No institution data available for this topic.',
          );
        }
        return _InstitutionListContent(institutions: institutions);
      },
    );
  }
}

class _InstitutionListContent extends StatelessWidget {
  final List<InstitutionHeatmapData> institutions;

  const _InstitutionListContent({required this.institutions});

  @override
  Widget build(BuildContext context) {
    final maxCount = institutions.isNotEmpty
        ? institutions.first.worksCount
        : 1;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top ${institutions.length} institutions',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'Ranked by number of publications',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.base),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final inst = institutions[index];
            final ratio = inst.worksCount / maxCount;
            return _InstitutionTile(
              rank: index + 1,
              institution: inst,
              ratio: ratio,
            );
          }, childCount: institutions.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.xxl)),
      ],
    );
  }
}

class _InstitutionTile extends StatelessWidget {
  final int rank;
  final InstitutionHeatmapData institution;
  final double ratio;

  const _InstitutionTile({
    required this.rank,
    required this.institution,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.base,
        vertical: AppDimensions.xs,
      ),
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
        side: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            // Rank medal
            _buildRankBadge(rank),
            const SizedBox(width: AppDimensions.md),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    institution.displayName,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            // Works count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCount(institution.worksCount),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'works',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color bgColor;
    Color textColor;
    if (rank == 1) {
      bgColor = AppColors.rankGold;
      textColor = AppColors.rankGoldText;
    } else if (rank == 2) {
      bgColor = AppColors.rankSilver;
      textColor = AppColors.rankSilverText;
    } else if (rank == 3) {
      bgColor = AppColors.rankBronze;
      textColor = AppColors.rankBronzeText;
    } else {
      bgColor = AppColors.surfaceContainer;
      textColor = AppColors.onSurfaceVariant;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: AppTextStyles.labelLarge.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
