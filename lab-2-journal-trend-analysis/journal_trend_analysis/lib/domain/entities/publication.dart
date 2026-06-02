// Domain layer — clean entity with no JSON or framework dependencies.
import 'package:equatable/equatable.dart';
import 'author.dart';

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
  });

  @override
  List<Object?> get props => [id, title, publicationYear, citedByCount];
}
