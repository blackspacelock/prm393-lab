import '../entities/keyword.dart';
import '../entities/publication.dart';

class GetKeywordAnalysis {
  List<KeywordItem> call(List<Publication> publications) {
    final cutoff = DateTime.now().year - 2;
    final frequencies = <String, int>{};
    final scoreSums = <String, double>{};
    final recentFrequencies = <String, int>{};
    final levels = <String, int>{};

    for (final publication in publications) {
      final year = publication.publicationYear ?? 0;
      for (final concept in publication.concepts) {
        final name = concept.displayName.trim();
        if (name.isEmpty) continue;

        frequencies[name] = (frequencies[name] ?? 0) + 1;
        scoreSums[name] = (scoreSums[name] ?? 0) + concept.score;
        levels.putIfAbsent(name, () => concept.level);

        if (year >= cutoff) {
          recentFrequencies[name] = (recentFrequencies[name] ?? 0) + 1;
        }
      }
    }

    final keywords =
        frequencies.entries.map((entry) {
          final name = entry.key;
          final frequency = entry.value;
          return KeywordItem(
            name: name,
            frequency: frequency,
            avgScore: (scoreSums[name] ?? 0) / frequency,
            trendRatio: (recentFrequencies[name] ?? 0) / frequency,
            level: levels[name] ?? 0,
          );
        }).toList()..sort((a, b) {
          final frequencyCompare = b.frequency.compareTo(a.frequency);
          if (frequencyCompare != 0) return frequencyCompare;
          return b.avgScore.compareTo(a.avgScore);
        });

    return keywords;
  }
}
