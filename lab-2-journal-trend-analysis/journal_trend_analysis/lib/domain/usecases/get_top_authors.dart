// Domain layer — aggregates author statistics from a publication list.
import '../entities/author.dart';
import '../entities/publication.dart';

class AuthorWithCount {
  final Author author;
  final int publicationCount;
  final int totalCitations;

  const AuthorWithCount({
    required this.author,
    required this.publicationCount,
    required this.totalCitations,
  });
}

class GetTopAuthors {
  List<AuthorWithCount> call(List<Publication> publications, {int? limit}) {
    final Map<String, AuthorWithCount> byId = {};

    for (final pub in publications) {
      for (final author in pub.authors) {
        final key = author.id.isNotEmpty ? author.id : author.displayName;
        final existing = byId[key];
        byId[key] = AuthorWithCount(
          author: author,
          publicationCount: (existing?.publicationCount ?? 0) + 1,
          totalCitations: (existing?.totalCitations ?? 0) + pub.citedByCount,
        );
      }
    }

    final sorted = byId.values.toList()
      ..sort((a, b) => b.publicationCount.compareTo(a.publicationCount));
    return limit != null ? sorted.take(limit).toList() : sorted;
  }
}
