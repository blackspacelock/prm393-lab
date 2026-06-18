// Data layer — API calls for heatmap data using OpenAlex group_by endpoint.
import 'package:dio/dio.dart';
import '../../domain/entities/heatmap_data.dart';
import '../api/openalex_api_client.dart';

abstract class HeatmapRemoteDataSource {
  /// Get works count grouped by country for a given search query or topic filter.
  Future<List<CountryHeatmapData>> getCountryDistribution({
    String? searchQuery,
    String? filterKey,
    String? filterId,
  });

  /// Get works count grouped by institution for a given search query or topic filter.
  Future<List<InstitutionHeatmapData>> getInstitutionDistribution({
    String? searchQuery,
    String? filterKey,
    String? filterId,
  });
}

class HeatmapRemoteDataSourceImpl implements HeatmapRemoteDataSource {
  final OpenAlexApiClient _apiClient;

  HeatmapRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<CountryHeatmapData>> getCountryDistribution({
    String? searchQuery,
    String? filterKey,
    String? filterId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'group_by': 'authorships.countries',
      };

      _applySearchOrFilter(
        queryParameters,
        searchQuery: searchQuery,
        filterKey: filterKey,
        filterId: filterId,
      );

      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: queryParameters,
      );

      final groupBy = response.data?['group_by'] as List<dynamic>? ?? [];

      return groupBy
          .whereType<Map<String, dynamic>>()
          .where(
            (item) =>
                item['key'] != null &&
                item['key'] != 'unknown' &&
                item['key'] != '',
          )
          .map((item) {
            final rawKey = item['key'] as String;
            final countryCode = _extractCountryCode(rawKey);
            return CountryHeatmapData(
              countryCode: countryCode,
              countryName: item['key_display_name'] as String? ?? countryCode,
              worksCount: item['count'] as int? ?? 0,
            );
          })
          .where((d) => d.worksCount > 0 && d.countryCode.isNotEmpty)
          .toList()
        ..sort((a, b) => b.worksCount.compareTo(a.worksCount));
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  @override
  Future<List<InstitutionHeatmapData>> getInstitutionDistribution({
    String? searchQuery,
    String? filterKey,
    String? filterId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'group_by': 'authorships.institutions.lineage',
      };

      _applySearchOrFilter(
        queryParameters,
        searchQuery: searchQuery,
        filterKey: filterKey,
        filterId: filterId,
      );

      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: queryParameters,
      );

      final groupBy = response.data?['group_by'] as List<dynamic>? ?? [];

      return groupBy
          .whereType<Map<String, dynamic>>()
          .where(
            (item) =>
                item['key'] != null &&
                item['key'] != 'unknown' &&
                item['key'] != '',
          )
          .map(
            (item) => InstitutionHeatmapData(
              id: item['key'] as String? ?? '',
              displayName:
                  item['key_display_name'] as String? ??
                  (item['key'] as String? ?? 'Unknown'),
              countryCode: _extractCountryFromId(item['key'] as String? ?? ''),
              worksCount: item['count'] as int? ?? 0,
            ),
          )
          .where((d) => d.worksCount > 0)
          .toList()
        ..sort((a, b) => b.worksCount.compareTo(a.worksCount));
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  void _applySearchOrFilter(
    Map<String, dynamic> params, {
    String? searchQuery,
    String? filterKey,
    String? filterId,
  }) {
    if (filterKey != null &&
        filterId != null &&
        filterKey != 'default.search') {
      params['filter'] = '$filterKey:$filterId';
    } else if (searchQuery != null && searchQuery.isNotEmpty) {
      params['search'] = searchQuery;
    }
  }

  /// Extract 2-letter country code from OpenAlex URL or raw key.
  /// e.g. "https://openalex.org/countries/US" → "US"
  String _extractCountryCode(String rawKey) {
    // If it's a URL like https://openalex.org/countries/US
    if (rawKey.contains('/')) {
      final segments = rawKey.split('/');
      return segments.last.toUpperCase();
    }
    // Already a plain code
    return rawKey.toUpperCase();
  }

  /// Best-effort country extraction — OpenAlex institution IDs don't carry
  /// country info directly, so we default to empty string.
  String _extractCountryFromId(String id) => '';
}
