// Data layer — fetches topic hierarchy data from OpenAlex API.
import 'package:dio/dio.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../api/openalex_api_client.dart';

abstract class TopicRemoteDataSource {
  /// Autocomplete search across topics, subfields, fields, and domains.
  Future<List<TopicHierarchyItem>> autocomplete(String query);

  /// Get all 4 domains.
  Future<List<TopicHierarchyItem>> getDomains();

  /// Get fields under a specific domain.
  Future<List<TopicHierarchyItem>> getFields({String? domainId});

  /// Get subfields under a specific field.
  Future<List<TopicHierarchyItem>> getSubfields({String? fieldId});

  /// Get topics under a specific subfield.
  Future<List<TopicHierarchyItem>> getTopics({String? subfieldId});
}

class TopicRemoteDataSourceImpl implements TopicRemoteDataSource {
  final OpenAlexApiClient _apiClient;

  TopicRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<TopicHierarchyItem>> autocomplete(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Domains and fields use regular search (few items, no autocomplete endpoint).
      // Subfields and topics use the autocomplete endpoint for better partial matching.
      final results = await Future.wait([
        _searchLevel('/domains', query, TopicLevel.domain),
        _searchLevel('/fields', query, TopicLevel.field),
        _autocompleteLevel(
          '/autocomplete/subfields',
          query,
          TopicLevel.subfield,
        ),
        _autocompleteLevel('/autocomplete/topics', query, TopicLevel.topic),
      ]);

      // Merge and return (domains first, then fields, subfields, topics)
      return results.expand((e) => e).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TopicHierarchyItem>> _searchLevel(
    String endpoint,
    String query,
    TopicLevel level,
  ) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: {
          'search': query,
          'per_page': 5,
          'select': 'id,display_name,works_count',
        },
      );
      return _parseItems(response.data, level);
    } catch (_) {
      return [];
    }
  }

  Future<List<TopicHierarchyItem>> _autocompleteLevel(
    String endpoint,
    String query,
    TopicLevel level,
  ) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: {'q': query},
      );
      final results = response.data?['results'] as List<dynamic>? ?? [];
      return results.whereType<Map<String, dynamic>>().take(5).map((json) {
        return TopicHierarchyItem(
          id: json['id'] as String? ?? '',
          displayName: json['display_name'] as String? ?? '',
          level: level,
          worksCount: json['works_count'] as int?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<TopicHierarchyItem>> getDomains() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/domains',
        queryParameters: {
          'per_page': 10,
          'select': 'id,display_name,works_count',
        },
      );
      return _parseItems(response.data, TopicLevel.domain);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  @override
  Future<List<TopicHierarchyItem>> getFields({String? domainId}) async {
    try {
      final params = <String, dynamic>{
        'per_page': 50,
        'select': 'id,display_name,works_count',
      };
      if (domainId != null) {
        params['filter'] = 'domain.id:$domainId';
      }
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fields',
        queryParameters: params,
      );
      return _parseItems(response.data, TopicLevel.field);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  @override
  Future<List<TopicHierarchyItem>> getSubfields({String? fieldId}) async {
    try {
      final params = <String, dynamic>{
        'per_page': 100,
        'select': 'id,display_name,works_count',
      };
      if (fieldId != null) {
        params['filter'] = 'field.id:$fieldId';
      }
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/subfields',
        queryParameters: params,
      );
      return _parseItems(response.data, TopicLevel.subfield);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  @override
  Future<List<TopicHierarchyItem>> getTopics({String? subfieldId}) async {
    try {
      final params = <String, dynamic>{
        'per_page': 100,
        'select': 'id,display_name,works_count',
      };
      if (subfieldId != null) {
        params['filter'] = 'subfield.id:$subfieldId';
      }
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/topics',
        queryParameters: params,
      );
      return _parseItems(response.data, TopicLevel.topic);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  List<TopicHierarchyItem> _parseItems(
    Map<String, dynamic>? data,
    TopicLevel level,
  ) {
    final results = data?['results'] as List<dynamic>? ?? [];
    return results.whereType<Map<String, dynamic>>().map((json) {
      return TopicHierarchyItem(
        id: json['id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        level: level,
        worksCount: json['works_count'] as int?,
      );
    }).toList();
  }
}
