// Domain layer — single responsibility: validate query and delegate to repository.
import '../entities/paginated_result.dart';
import '../entities/publication.dart';
import '../repositories/publication_repository.dart';

class SearchPublications {
  final PublicationRepository repository;

  SearchPublications(this.repository);

  Future<PaginatedResult<Publication>> call(
    String query, {
    int page = 1,
    int perPage = 25,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const PaginatedResult(
        items: [],
        totalCount: 0,
        page: 1,
        perPage: 25,
      );
    }
    return repository.searchPublications(trimmed, page: page, perPage: perPage);
  }
}
