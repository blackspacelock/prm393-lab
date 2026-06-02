// Domain layer — single responsibility: validate query and delegate to repository.
import '../entities/publication.dart';
import '../repositories/publication_repository.dart';

class SearchPublications {
  final PublicationRepository repository;

  SearchPublications(this.repository);

  Future<List<Publication>> call(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    return repository.searchPublications(trimmed);
  }
}
