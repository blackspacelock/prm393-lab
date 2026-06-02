// Data layer — raw API calls. Returns model objects; never domain entities.
import 'package:dio/dio.dart';
import '../api/openalex_api_client.dart';
import '../models/publication_model.dart';
import '../../core/constants/api_constants.dart';

abstract class PublicationRemoteDataSource {
  Future<List<PublicationModel>> searchPublications(String query);
  Future<List<PublicationModel>> getTopPapers({String? topic});
}

class PublicationRemoteDataSourceImpl implements PublicationRemoteDataSource {
  final OpenAlexApiClient _apiClient;

  PublicationRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<PublicationModel>> searchPublications(String query) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/works',
        queryParameters: {
          'search': query,
          'per_page': ApiConstants.perPage,
          'sort': 'cited_by_count:desc',
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
  Future<List<PublicationModel>> getTopPapers({String? topic}) async {
    try {
      final params = <String, dynamic>{
        'per_page': ApiConstants.perPage,
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
