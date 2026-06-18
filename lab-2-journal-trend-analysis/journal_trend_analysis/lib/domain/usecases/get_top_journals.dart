// Domain layer — aggregates journal statistics from a publication list.
import '../entities/publication.dart';

class JournalWithCount {
  final String name;
  final int publicationCount;
  final int totalCitations;

  const JournalWithCount({
    required this.name,
    required this.publicationCount,
    required this.totalCitations,
  });
}

class GetTopJournals {
  List<JournalWithCount> call(List<Publication> publications, {int? limit}) {
    final Map<String, JournalWithCount> byName = {};

    for (final pub in publications) {
      final name = pub.journalName;
      if (name == null || name.isEmpty) continue;
      final existing = byName[name];
      byName[name] = JournalWithCount(
        name: name,
        publicationCount: (existing?.publicationCount ?? 0) + 1,
        totalCitations: (existing?.totalCitations ?? 0) + pub.citedByCount,
      );
    }

    final sorted = byName.values.toList()
      ..sort((a, b) => b.publicationCount.compareTo(a.publicationCount));
    return limit != null ? sorted.take(limit).toList() : sorted;
  }
}
