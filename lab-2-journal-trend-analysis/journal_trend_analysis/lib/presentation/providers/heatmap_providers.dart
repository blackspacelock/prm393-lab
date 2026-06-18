// Presentation layer — Riverpod providers for the heatmap feature.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/heatmap_remote_datasource.dart';
import '../../domain/entities/heatmap_data.dart';
import 'providers.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final heatmapDataSourceProvider = Provider<HeatmapRemoteDataSource>(
  (ref) => HeatmapRemoteDataSourceImpl(ref.read(apiClientProvider)),
);

// ── View mode ─────────────────────────────────────────────────────────────────

enum HeatmapViewMode { country, institution }

final heatmapViewModeProvider = StateProvider<HeatmapViewMode>(
  (_) => HeatmapViewMode.country,
);

// ── Country distribution ──────────────────────────────────────────────────────

/// Fetches country-level research distribution for the current search context.
final countryDistributionProvider =
    FutureProvider<List<CountryHeatmapData>>((ref) async {
  final topicFilter = ref.watch(selectedTopicFilterProvider);
  final query = ref.watch(searchQueryProvider);

  // No query or filter → empty
  if (topicFilter == null && query.isEmpty) return [];

  return ref.read(heatmapDataSourceProvider).getCountryDistribution(
        searchQuery: topicFilter == null ? query : null,
        filterKey: topicFilter?.filterKey,
        filterId: topicFilter?.id,
      );
});

// ── Institution distribution ──────────────────────────────────────────────────

/// Fetches institution-level research distribution for the current search context.
final institutionDistributionProvider =
    FutureProvider<List<InstitutionHeatmapData>>((ref) async {
  final topicFilter = ref.watch(selectedTopicFilterProvider);
  final query = ref.watch(searchQueryProvider);

  // No query or filter → empty
  if (topicFilter == null && query.isEmpty) return [];

  return ref.read(heatmapDataSourceProvider).getInstitutionDistribution(
        searchQuery: topicFilter == null ? query : null,
        filterKey: topicFilter?.filterKey,
        filterId: topicFilter?.id,
      );
});
