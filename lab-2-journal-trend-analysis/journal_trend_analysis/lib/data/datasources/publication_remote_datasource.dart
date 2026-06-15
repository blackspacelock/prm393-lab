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
  Future<PaginatedApiResponse> searchPublications(
    String query, {
    int page = 1,
    int perPage = 25,
  });
  Future<List<PublicationModel>> getTopPapers({String? topic});
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
          'filter': 'default.search:$query',
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

  List<PublicationModel> _parseResults(Map<String, dynamic>? data) {
    final results = data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(PublicationModel.fromJson)
        .toList();
  }
}
