// Presentation layer — dependency injection and reactive state via Riverpod.
// All infrastructure is wired here; screens only see typed providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/openalex_api_client.dart';
import '../../data/datasources/publication_remote_datasource.dart';
import '../../data/repositories/publication_repository_impl.dart';
import '../../domain/entities/publication.dart';
import '../../domain/repositories/publication_repository.dart';
import '../../domain/usecases/get_dashboard_summary.dart';
import '../../domain/usecases/get_top_authors.dart';
import '../../domain/usecases/get_top_journals.dart';
import '../../domain/usecases/get_trend_data.dart';
import '../../domain/usecases/search_publications.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final apiClientProvider = Provider<OpenAlexApiClient>(
  (_) => OpenAlexApiClient(),
);

final remoteDataSourceProvider = Provider<PublicationRemoteDataSource>(
  (ref) => PublicationRemoteDataSourceImpl(ref.read(apiClientProvider)),
);

final publicationRepositoryProvider = Provider<PublicationRepository>(
  (ref) => PublicationRepositoryImpl(ref.read(remoteDataSourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────

final searchPublicationsUseCaseProvider = Provider<SearchPublications>(
  (ref) => SearchPublications(ref.read(publicationRepositoryProvider)),
);

final getTrendDataUseCaseProvider = Provider<GetTrendData>((_) => GetTrendData());

final getTopAuthorsUseCaseProvider = Provider<GetTopAuthors>((_) => GetTopAuthors());

final getTopJournalsUseCaseProvider = Provider<GetTopJournals>((_) => GetTopJournals());

final getDashboardSummaryUseCaseProvider = Provider<GetDashboardSummary>(
  (ref) => GetDashboardSummary(ref.read(getTrendDataUseCaseProvider)),
);

// ── State ─────────────────────────────────────────────────────────────────────

/// The current search query. Updating this triggers a new API call.
final searchQueryProvider = StateProvider<String>((_) => '');

/// All publications for the current query, fetched from OpenAlex.
final publicationsProvider = FutureProvider<List<Publication>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(searchPublicationsUseCaseProvider)(query);
});

/// Year-by-year trend derived from the current publication list.
final trendDataProvider = Provider<List<YearTrendData>>((ref) {
  final pubs = ref.watch(publicationsProvider).value ?? [];
  return ref.read(getTrendDataUseCaseProvider)(pubs);
});

/// Dashboard KPIs derived from the current publication list.
final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final pubs = ref.watch(publicationsProvider).value ?? [];
  return ref.read(getDashboardSummaryUseCaseProvider)(pubs);
});

/// Top authors ranked by publication count.
final topAuthorsProvider = Provider<List<AuthorWithCount>>((ref) {
  final pubs = ref.watch(publicationsProvider).value ?? [];
  return ref.read(getTopAuthorsUseCaseProvider)(pubs);
});

/// Top journals ranked by publication count.
final topJournalsProvider = Provider<List<JournalWithCount>>((ref) {
  final pubs = ref.watch(publicationsProvider).value ?? [];
  return ref.read(getTopJournalsUseCaseProvider)(pubs);
});

// ── Top Papers sort ───────────────────────────────────────────────────────────

enum PaperSortOption { citationCount, year, relevance, title }

final paperSortOptionProvider =
    StateProvider<PaperSortOption>((_) => PaperSortOption.citationCount);

final sortedPublicationsProvider = Provider<List<Publication>>((ref) {
  final pubs = List<Publication>.from(
    ref.watch(publicationsProvider).value ?? [],
  );
  final sort = ref.watch(paperSortOptionProvider);

  switch (sort) {
    case PaperSortOption.citationCount:
      pubs.sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
    case PaperSortOption.year:
      pubs.sort(
        (a, b) =>
            (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0),
      );
    case PaperSortOption.relevance:
      // Sort by year descending as a relevance proxy.
      pubs.sort(
        (a, b) =>
            (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0),
      );
    case PaperSortOption.title:
      pubs.sort((a, b) => a.title.compareTo(b.title));
  }

  return pubs;
});
