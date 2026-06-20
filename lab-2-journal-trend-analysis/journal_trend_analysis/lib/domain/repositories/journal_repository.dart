// Domain layer — abstract journal repository contract.
import '../entities/journal.dart';
import '../entities/paginated_result.dart';
import '../entities/publication.dart';

abstract class JournalRepository {
  /// Search journals by name.
  Future<PaginatedResult<Journal>> searchJournals(
    String query, {
    int page = 1,
    int perPage = 25,
    String sort = 'works_count:desc',
  });

  /// Get a single journal by ID.
  Future<Journal> getJournalById(String id);

  /// Get publications belonging to a journal.
  Future<PaginatedResult<Publication>> getJournalPublications(
    String sourceId, {
    int page = 1,
    int perPage = 50,
  });

  /// Get journals with configurable sort and filter.
  Future<PaginatedResult<Journal>> getRecentJournals({
    int page = 1,
    int perPage = 25,
    String sort = 'works_count:desc',
    String filter = 'type:journal',
  });
}
