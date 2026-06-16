// Domain layer — abstract contract; data layer provides the implementation.
import '../entities/paginated_result.dart';
import '../entities/publication.dart';

abstract class PublicationRepository {
  Future<PaginatedResult<Publication>> searchPublications(
    String query, {
    int page = 1,
    int perPage = 25,
  });

  Future<PaginatedResult<Publication>> searchByTopicFilter(
    String filterKey,
    String filterId, {
    int page = 1,
    int perPage = 25,
  });

  Future<List<Publication>> getTopPapers({String? topic});
}
