// Domain layer — computes all KPIs shown on the dashboard screen.
import '../entities/publication.dart';
import 'get_trend_data.dart';

class DashboardSummary {
  final int totalPublications;
  final double avgCitations;
  final int? mostActiveYear;
  final Publication? mostInfluentialPaper;
  final String? topJournalName;
  final int? topJournalPublications;
  final String? topAuthorName;
  final int? topAuthorPublications;
  final List<YearTrendData> sparklineData;

  const DashboardSummary({
    required this.totalPublications,
    required this.avgCitations,
    this.mostActiveYear,
    this.mostInfluentialPaper,
    this.topJournalName,
    this.topJournalPublications,
    this.topAuthorName,
    this.topAuthorPublications,
    required this.sparklineData,
  });
}

class GetDashboardSummary {
  final GetTrendData _getTrendData;

  GetDashboardSummary(this._getTrendData);

  DashboardSummary call(List<Publication> publications) {
    if (publications.isEmpty) {
      return const DashboardSummary(
        totalPublications: 0,
        avgCitations: 0,
        sparklineData: [],
      );
    }

    final trendData = _getTrendData(publications);

    int? mostActiveYear;
    if (trendData.isNotEmpty) {
      mostActiveYear = trendData
          .reduce((a, b) => a.publicationCount > b.publicationCount ? a : b)
          .year;
    }

    final sortedByCitations = List<Publication>.from(publications)
      ..sort((a, b) => b.citedByCount.compareTo(a.citedByCount));

    final Map<String, int> journalCounts = {};
    for (final pub in publications) {
      final j = pub.journalName;
      if (j != null && j.isNotEmpty) {
        journalCounts[j] = (journalCounts[j] ?? 0) + 1;
      }
    }

    final Map<String, int> authorCounts = {};
    for (final pub in publications) {
      for (final author in pub.authors) {
        authorCounts[author.displayName] =
            (authorCounts[author.displayName] ?? 0) + 1;
      }
    }

    final totalCitations = publications.fold<int>(
      0,
      (s, p) => s + p.citedByCount,
    );

    final topJournalEntry = journalCounts.isEmpty
        ? null
        : journalCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final topAuthorEntry = authorCounts.isEmpty
        ? null
        : authorCounts.entries.reduce((a, b) => a.value > b.value ? a : b);

    return DashboardSummary(
      totalPublications: publications.length,
      avgCitations: totalCitations / publications.length,
      mostActiveYear: mostActiveYear,
      mostInfluentialPaper: sortedByCitations.isNotEmpty
          ? sortedByCitations.first
          : null,
      topJournalName: topJournalEntry?.key,
      topJournalPublications: topJournalEntry?.value,
      topAuthorName: topAuthorEntry?.key,
      topAuthorPublications: topAuthorEntry?.value,
      sparklineData: trendData,
    );
  }
}
