// Data layer — concrete repository; converts data models to domain entities.
import '../../domain/entities/paginated_result.dart';
import '../../domain/entities/publication.dart';
import '../../domain/repositories/publication_repository.dart';
import '../datasources/publication_remote_datasource.dart';

class PublicationRepositoryImpl implements PublicationRepository {
  final PublicationRemoteDataSource _remoteDataSource;

  PublicationRepositoryImpl(this._remoteDataSource);

  @override
  Future<PaginatedResult<Publication>> searchPublications(
    String query, {
    int page = 1,
    int perPage = 25,
  }) async {
    final response = await _remoteDataSource.searchPublications(
      query,
      page: page,
      perPage: perPage,
    );
    return PaginatedResult<Publication>(
      items: response.results.map((m) => m.toEntity()).toList(),
      totalCount: response.totalCount,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<PaginatedResult<Publication>> searchByTopicFilter(
    String filterKey,
    String filterId, {
    int page = 1,
    int perPage = 25,
  }) async {
    final response = await _remoteDataSource.searchByTopicFilter(
      filterKey,
      filterId,
      page: page,
      perPage: perPage,
    );
    return PaginatedResult<Publication>(
      items: response.results.map((m) => m.toEntity()).toList(),
      totalCount: response.totalCount,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<List<Publication>> getTopPapers({String? topic}) async {
    final models = await _remoteDataSource.getTopPapers(topic: topic);
    return models.map((m) => m.toEntity()).toList();
  }
}
