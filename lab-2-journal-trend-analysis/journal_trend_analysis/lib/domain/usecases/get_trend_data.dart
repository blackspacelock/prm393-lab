// Domain layer — groups publications by year for chart rendering.
import '../entities/publication.dart';

class YearTrendData {
  final int year;
  final int publicationCount;
  final int totalCitations;

  const YearTrendData({
    required this.year,
    required this.publicationCount,
    required this.totalCitations,
  });
}

class GetTrendData {
  List<YearTrendData> call(List<Publication> publications) {
    final Map<int, YearTrendData> byYear = {};

    for (final pub in publications) {
      final year = pub.publicationYear;
      if (year == null) continue;
      final existing = byYear[year];
      byYear[year] = YearTrendData(
        year: year,
        publicationCount: (existing?.publicationCount ?? 0) + 1,
        totalCitations: (existing?.totalCitations ?? 0) + pub.citedByCount,
      );
    }

    return (byYear.values.toList()..sort((a, b) => a.year.compareTo(b.year)));
  }
}
