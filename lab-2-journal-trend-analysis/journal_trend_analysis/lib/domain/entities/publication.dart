// Domain layer — clean entity with no JSON or framework dependencies.
import 'package:equatable/equatable.dart';
import 'author.dart';

/// Yearly citation count for a publication.
class YearlyCitation {
  final int year;
  final int citedByCount;

  const YearlyCitation({required this.year, required this.citedByCount});
}

class Publication extends Equatable {
  final String id;
  final String title;
  final int? publicationYear;
  final int citedByCount;
  final String? doi;
  final String? journalName;
  final List<Author> authors;
  // Kept as raw map so formatter.dart can reconstruct the abstract on demand.
  final Map<String, dynamic>? abstractInvertedIndex;
  final List<String> concepts;

  /// Citation counts per year (from OpenAlex counts_by_year).
  final List<YearlyCitation> countsByYear;

  const Publication({
    required this.id,
    required this.title,
    this.publicationYear,
    required this.citedByCount,
    this.doi,
    this.journalName,
    required this.authors,
    this.abstractInvertedIndex,
    required this.concepts,
    this.countsByYear = const [],
  });

  @override
  List<Object?> get props => [id, title, publicationYear, citedByCount];
}
