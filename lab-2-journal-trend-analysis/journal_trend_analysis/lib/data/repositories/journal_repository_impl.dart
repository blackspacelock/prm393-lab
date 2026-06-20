// Data layer — concrete journal repository; converts models to domain entities.
import '../../domain/entities/journal.dart';
import '../../domain/entities/paginated_result.dart';
import '../../domain/entities/publication.dart';
import '../../domain/repositories/journal_repository.dart';
import '../datasources/journal_remote_datasource.dart';

class JournalRepositoryImpl implements JournalRepository {
  final JournalRemoteDataSource _remoteDataSource;

  JournalRepositoryImpl(this._remoteDataSource);

  @override
  Future<PaginatedResult<Journal>> searchJournals(
    String query, {
    int page = 1,
    int perPage = 25,
    String sort = 'works_count:desc',
  }) async {
    final response = await _remoteDataSource.searchJournals(
      query,
      page: page,
      perPage: perPage,
      sort: sort,
    );
    return PaginatedResult<Journal>(
      items: response.results.map((m) => m.toEntity()).toList(),
      totalCount: response.totalCount,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<Journal> getJournalById(String id) async {
    final model = await _remoteDataSource.getJournalById(id);
    return model.toEntity();
  }

  @override
  Future<PaginatedResult<Publication>> getJournalPublications(
    String sourceId, {
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _remoteDataSource.getJournalPublications(
      sourceId,
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
  Future<PaginatedResult<Journal>> getRecentJournals({
    int page = 1,
    int perPage = 25,
    String sort = 'works_count:desc',
    String filter = 'type:journal',
  }) async {
    final response = await _remoteDataSource.getRecentJournals(
      page: page,
      perPage: perPage,
      sort: sort,
      filter: filter,
    );
    return PaginatedResult<Journal>(
      items: response.results.map((m) => m.toEntity()).toList(),
      totalCount: response.totalCount,
      page: page,
      perPage: perPage,
    );
  }
}
