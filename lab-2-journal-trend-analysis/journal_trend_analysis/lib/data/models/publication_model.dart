// Data layer — maps the full OpenAlex /works JSON object to a typed model.
import '../../domain/entities/publication.dart';
import '../../domain/entities/concept.dart';
import 'author_model.dart';

class PublicationModel {
  final String id;
  final String title;
  final int? publicationYear;
  final int citedByCount;
  final String? doi;
  final String? journalName;
  final List<AuthorModel> authors;
  final Map<String, dynamic>? abstractInvertedIndex;
  final List<Concept> concepts;
  final List<YearlyCitation> countsByYear;

  const PublicationModel({
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

  factory PublicationModel.fromJson(Map<String, dynamic> json) {
    // Journal name lives inside primary_location → source
    String? journalName;
    final primaryLocation = json['primary_location'] as Map<String, dynamic>?;
    if (primaryLocation != null) {
      final source = primaryLocation['source'] as Map<String, dynamic>?;
      journalName = source?['display_name'] as String?;
    }

    final authorships = (json['authorships'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AuthorModel.fromJson)
        .toList();

    final concepts = (json['concepts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (c) => Concept(
            displayName: c['display_name'] as String? ?? '',
            score: (c['score'] as num?)?.toDouble() ?? 0.0,
            level: c['level'] as int? ?? 0,
          ),
        )
        .where((c) => c.displayName.isNotEmpty)
        .toList();

    // Parse counts_by_year
    final countsByYearRaw = json['counts_by_year'] as List<dynamic>? ?? [];
    final countsByYear =
        countsByYearRaw
            .whereType<Map<String, dynamic>>()
            .map(
              (e) => YearlyCitation(
                year: e['year'] as int? ?? 0,
                citedByCount: e['cited_by_count'] as int? ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.year.compareTo(b.year));

    return PublicationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      publicationYear: json['publication_year'] as int?,
      citedByCount: json['cited_by_count'] as int? ?? 0,
      doi: json['doi'] as String?,
      journalName: journalName,
      authors: authorships,
      abstractInvertedIndex:
          json['abstract_inverted_index'] as Map<String, dynamic>?,
      concepts: concepts,
      countsByYear: countsByYear,
    );
  }

  Publication toEntity() => Publication(
    id: id,
    title: title,
    publicationYear: publicationYear,
    citedByCount: citedByCount,
    doi: doi,
    journalName: journalName,
    authors: authors.map((a) => a.toEntity()).toList(),
    abstractInvertedIndex: abstractInvertedIndex,
    concepts: concepts,
    countsByYear: countsByYear,
  );
}
