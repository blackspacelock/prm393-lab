// Data layer — raw API calls for journal/source data from OpenAlex.
import 'package:dio/dio.dart';
import '../api/openalex_api_client.dart';
import '../models/journal_model.dart';
import '../models/publication_model.dart';
import 'publication_remote_datasource.dart';

/// Paginated response for journal searches.
class PaginatedJournalResponse {
  final List<JournalModel> results;
  final int totalCount;

  const PaginatedJournalResponse({
    required this.results,
    required this.totalCount,
  });
}

abstract class JournalRemoteDataSource {
  /// Search journals/sources by display name.
  Future<PaginatedJournalResponse> searchJournals(
    String query, {
    int page = 1,
    int perPage = 25,
    String sort = 'works_count:desc',
  });

  /// Get a single journal/source by its OpenAlex ID.
  Future<JournalModel> getJournalById(String id);

  /// Get publications belonging to a journal/source (by source ID).
  Future<PaginatedApiResponse> getJournalPublications(
    String sourceId, {
    int page = 1,
    int perPage = 50,
  });

  /// Get journals with configurable sort and filter.
  Future<PaginatedJournalResponse> getRecentJournals({
    int page = 1,
    int perPage = 25,
    String sort = 'works_count:desc',
    String filter = 'type:journal',
  });
}

class JournalRemoteDataSourceImpl implements JournalRemoteDataSource {
  final OpenAlexApiClient _apiClient;

  JournalRemoteDataSourceImpl(this._apiClient);

  @override
  Future<PaginatedJournalResponse> searchJournals(
    String query, {
    int page = 1,
    int perPage = 25,
    String sort = 'works_count:desc',
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/sources',
        queryParameters: {
          'search': query,
          'per_page': perPage,
          'page': page,
          'sort': sort,
        },
      );

      final data = response.data;
      final meta = data?['meta'] as Map<String, dynamic>? ?? {};
      final totalCount = meta['count'] as int? ?? 0;
      final results = _parseJournalResults(data);

      return PaginatedJournalResponse(results: results, totalCount: totalCount);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  @override
  Future<JournalModel> getJournalById(String id) async {
    try {
      // OpenAlex source IDs are full URLs like https://openalex.org/S123456
      // The API accepts the short form too: /sources/S123456
      final shortId = id.contains('/') ? id.split('/').last : id;
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/sources/$shortId',
      );

      final data = response.data;
      if (data == null) throw Exception('Empty response');
      return JournalModel.fromJson(data);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  @override
  Future<PaginatedApiResponse> getJournalPublications(
    String sourceId, {
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: {
          'filter': 'primary_location.source.id:$sourceId',
          'sort': 'cited_by_count:desc',
          'per_page': perPage,
          'page': page,
        },
      );

      final data = response.data;
      final meta = data?['meta'] as Map<String, dynamic>? ?? {};
      final totalCount = meta['count'] as int? ?? 0;
      final results = _parsePublicationResults(data);

      return PaginatedApiResponse(results: results, totalCount: totalCount);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  @override
  Future<PaginatedJournalResponse> getRecentJournals({
    int page = 1,
    int perPage = 25,
    String sort = 'works_count:desc',
    String filter = 'type:journal',
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/sources',
        queryParameters: {
          'filter': filter,
          'sort': sort,
          'per_page': perPage,
          'page': page,
        },
      );

      final data = response.data;
      final meta = data?['meta'] as Map<String, dynamic>? ?? {};
      final totalCount = meta['count'] as int? ?? 0;
      final results = _parseJournalResults(data);

      return PaginatedJournalResponse(results: results, totalCount: totalCount);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Parse error: $e');
    }
  }

  List<JournalModel> _parseJournalResults(Map<String, dynamic>? data) {
    final results = data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(JournalModel.fromJson)
        .toList();
  }

  List<PublicationModel> _parsePublicationResults(Map<String, dynamic>? data) {
    final results = data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(PublicationModel.fromJson)
        .toList();
  }
}
