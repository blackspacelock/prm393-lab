// Domain layer — computes all KPIs shown on the dashboard screen.
import '../entities/publication.dart';
import 'get_trend_data.dart';

class DashboardSummary {
  final int totalPublications;
  final double avgCitations;
  final int? mostActiveYear;
  final int? topGrowthYear;
  final Publication? mostInfluentialPaper;
  final String? topJournalName;
  final String? topAuthorName;
  final List<YearTrendData> sparklineData;

  const DashboardSummary({
    required this.totalPublications,
    required this.avgCitations,
    this.mostActiveYear,
    this.topGrowthYear,
    this.mostInfluentialPaper,
    this.topJournalName,
    this.topAuthorName,
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

    final totalCitations =
        publications.fold<int>(0, (s, p) => s + p.citedByCount);

    return DashboardSummary(
      totalPublications: publications.length,
      avgCitations: totalCitations / publications.length,
      mostActiveYear: mostActiveYear,
      topGrowthYear: _topGrowthYear(trendData),
      mostInfluentialPaper:
          sortedByCitations.isNotEmpty ? sortedByCitations.first : null,
      topJournalName: journalCounts.isEmpty
          ? null
          : journalCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key,
      topAuthorName: authorCounts.isEmpty
          ? null
          : authorCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key,
      sparklineData: trendData,
    );
  }

  // Returns the year with the largest year-over-year increase in publication count.
  int? _topGrowthYear(List<YearTrendData> data) {
    if (data.length < 2) return null;
    int maxGrowth = 0;
    int? bestYear;
    for (int i = 1; i < data.length; i++) {
      final growth = data[i].publicationCount - data[i - 1].publicationCount;
      if (growth > maxGrowth) {
        maxGrowth = growth;
        bestYear = data[i].year;
      }
    }
    return bestYear;
  }
}
