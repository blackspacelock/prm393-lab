// Data layer — raw API calls. Returns model objects; never domain entities.
import 'package:dio/dio.dart';
import '../api/openalex_api_client.dart';
import '../models/publication_model.dart';

/// Raw paginated response from the API.
class PaginatedApiResponse {
  final List<PublicationModel> results;
  final int totalCount;

  const PaginatedApiResponse({required this.results, required this.totalCount});
}

abstract class PublicationRemoteDataSource {
  /// Free-text search.
  Future<PaginatedApiResponse> searchPublications(
    String query, {
    int page = 1,
    int perPage = 25,
  });

  /// Filter-based search using topic hierarchy ID.
  /// [filterKey] e.g. "topics.domain.id", [filterId] e.g. "https://openalex.org/domains/3"
  Future<PaginatedApiResponse> searchByTopicFilter(
    String filterKey,
    String filterId, {
    int page = 1,
    int perPage = 25,
  });

  Future<List<PublicationModel>> getTopPapers({String? topic});

  /// High-impact articles from the latest 10-year window, optionally scoped to a domain.
  Future<List<PublicationModel>> getTrending({
    String? domainId,
    int perPage = 50,
  });

  /// Returns {year → paper count} for the latest 10-year window using OpenAlex group_by.
  /// [filterString] is a raw OpenAlex filter clause (may be null).
  /// [searchQuery] is an optional free-text search term.
  Future<Map<int, int>> getYearlyPublicationCounts({
    String? filterString,
    String? searchQuery,
  });
}

class PublicationRemoteDataSourceImpl implements PublicationRemoteDataSource {
  final OpenAlexApiClient _apiClient;

  PublicationRemoteDataSourceImpl(this._apiClient);

  @override
  Future<PaginatedApiResponse> searchPublications(
    String query, {
    int page = 1,
    int perPage = 25,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: {
          'search': query,
          'per_page': perPage,
          'page': page,
          'sort': 'relevance_score:desc',
        },
      );

      final data = response.data;
      final meta = data?['meta'] as Map<String, dynamic>? ?? {};
      final totalCount = meta['count'] as int? ?? 0;
      final results = _parseResults(data);

      return PaginatedApiResponse(results: results, totalCount: totalCount);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  @override
  Future<PaginatedApiResponse> searchByTopicFilter(
    String filterKey,
    String filterId, {
    int page = 1,
    int perPage = 25,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'per_page': perPage,
        'page': page,
      };

      // Use 'search' param for text-based searches (avoids comma issues in names)
      if (filterKey == 'default.search') {
        queryParameters['search'] = filterId;
        queryParameters['sort'] = 'relevance_score:desc';
      } else {
        queryParameters['filter'] = '$filterKey:$filterId';
        queryParameters['sort'] = 'cited_by_count:desc';
      }

      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: queryParameters,
      );

      final data = response.data;
      final meta = data?['meta'] as Map<String, dynamic>? ?? {};
      final totalCount = meta['count'] as int? ?? 0;
      final results = _parseResults(data);

      return PaginatedApiResponse(results: results, totalCount: totalCount);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  @override
  Future<List<PublicationModel>> getTopPapers({String? topic}) async {
    try {
      final params = <String, dynamic>{
        'per_page': 50,
        'sort': 'cited_by_count:desc',
      };
      if (topic != null && topic.isNotEmpty) {
        params['filter'] = 'concepts.display_name:$topic';
      }

      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: params,
      );
      return _parseResults(response.data);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  @override
  Future<List<PublicationModel>> getTrending({
    String? domainId,
    int perPage = 50,
  }) async {
    try {
      final cutoffYear = DateTime.now().year - 10;
      final cutoffDate = '$cutoffYear-01-01';
      final filter = domainId != null
          ? 'from_publication_date:$cutoffDate,type:article,primary_topic.domain.id:$domainId'
          : 'from_publication_date:$cutoffDate,type:article';
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: {
          'filter': filter,
          'sort': 'cited_by_count:desc',
          'per_page': perPage,
        },
      );
      return _parseResults(response.data);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  @override
  Future<Map<int, int>> getYearlyPublicationCounts({
    String? filterString,
    String? searchQuery,
  }) async {
    try {
      final currentYear = DateTime.now().year;
      final cutoffYear = currentYear - 10;
      final baseFilter = 'from_publication_date:$cutoffYear-01-01,type:article';
      final params = <String, dynamic>{
        'filter': filterString != null
            ? '$baseFilter,$filterString'
            : baseFilter,
        'group_by': 'publication_year',
      };
      if (searchQuery != null && searchQuery.isNotEmpty) {
        params['search'] = searchQuery;
      }

      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: params,
      );

      final groupBy = response.data?['group_by'] as List<dynamic>? ?? [];
      final result = <int, int>{};

      for (final entry in groupBy.whereType<Map<String, dynamic>>()) {
        final year = int.tryParse(entry['key'] as String? ?? '');
        final count = entry['count'] as int?;
        if (year != null &&
            count != null &&
            year >= cutoffYear &&
            year <= currentYear) {
          result[year] = count;
        }
      }
      return result;
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  List<PublicationModel> _parseResults(Map<String, dynamic>? data) {
    final results = data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(PublicationModel.fromJson)
        .toList();
  }
}
