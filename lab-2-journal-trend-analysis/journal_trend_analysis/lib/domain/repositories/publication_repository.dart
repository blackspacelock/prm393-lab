// Domain layer — abstract contract; data layer provides the implementation.
// Open/closed: new data sources can be wired in without changing use cases.
import '../entities/paginated_result.dart';
import '../entities/publication.dart';

abstract class PublicationRepository {
  Future<PaginatedResult<Publication>> searchPublications(
    String query, {
    int page = 1,
    int perPage = 25,
  });
  Future<List<Publication>> getTopPapers({String? topic});
}
