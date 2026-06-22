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

  /// Recent (2022-present) high-impact papers, optionally scoped to a domain.
  /// Returns paginated results with total count.
  Future<PaginatedApiResponse> getTrending({
    String? domainId,
    int page = 1,
    int perPage = 50,
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
  Future<PaginatedApiResponse> getTrending({
    String? domainId,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final filter = domainId != null
          ? 'from_publication_date:2022-01-01,type:article,primary_topic.domain.id:$domainId'
          : 'from_publication_date:2022-01-01,type:article';
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: {
          'filter': filter,
          'sort': 'cited_by_count:desc',
          'per_page': perPage,
          'page': page,
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

  List<PublicationModel> _parseResults(Map<String, dynamic>? data) {
    final results = data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(PublicationModel.fromJson)
        .toList();
  }
}
