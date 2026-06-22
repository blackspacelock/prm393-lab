// Presentation layer — dependency injection and reactive state via Riverpod.
// All infrastructure is wired here; screens only see typed providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/openalex_api_client.dart';
import '../../data/datasources/publication_remote_datasource.dart';
import '../../data/datasources/topic_remote_datasource.dart';
import '../../data/repositories/publication_repository_impl.dart';
import '../../domain/entities/paginated_result.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/topic_hierarchy.dart';
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

final topicDataSourceProvider = Provider<TopicRemoteDataSource>(
  (ref) => TopicRemoteDataSourceImpl(ref.read(apiClientProvider)),
);

final publicationRepositoryProvider = Provider<PublicationRepository>(
  (ref) => PublicationRepositoryImpl(ref.read(remoteDataSourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────

final searchPublicationsUseCaseProvider = Provider<SearchPublications>(
  (ref) => SearchPublications(ref.read(publicationRepositoryProvider)),
);

final getTrendDataUseCaseProvider = Provider<GetTrendData>(
  (_) => GetTrendData(),
);

final getTopAuthorsUseCaseProvider = Provider<GetTopAuthors>(
  (_) => GetTopAuthors(),
);

final getTopJournalsUseCaseProvider = Provider<GetTopJournals>(
  (_) => GetTopJournals(),
);

final getDashboardSummaryUseCaseProvider = Provider<GetDashboardSummary>(
  (ref) => GetDashboardSummary(ref.read(getTrendDataUseCaseProvider)),
);

// ── Search State ──────────────────────────────────────────────────────────────

/// The current search query (free text).
final searchQueryProvider = StateProvider<String>((_) => '');

/// If user selected a topic hierarchy item, this is set instead of free-text search.
final selectedTopicFilterProvider = StateProvider<TopicHierarchyItem?>(
  (_) => null,
);

/// Current page for infinite scroll (internal, incremented by "Read more").
final searchPageProvider = StateProvider<int>((_) => 1);

/// Results per page — fixed at 50 for "read more" loading.
final searchPerPageProvider = StateProvider<int>((_) => 50);

// ── Topic Autocomplete ────────────────────────────────────────────────────────

/// Autocomplete results for the current search text input.
final topicAutocompleteProvider =
    FutureProvider.family<List<TopicHierarchyItem>, String>((ref, query) async {
      if (query.trim().length < 2) return [];
      return ref.read(topicDataSourceProvider).autocomplete(query);
    });

/// Cascading filter: domains
final domainsProvider = FutureProvider<List<TopicHierarchyItem>>((ref) async {
  return ref.read(topicDataSourceProvider).getDomains();
});

/// Cascading filter: fields for a given domain
final fieldsProvider = FutureProvider.family<List<TopicHierarchyItem>, String?>(
  (ref, domainId) {
    return ref.read(topicDataSourceProvider).getFields(domainId: domainId);
  },
);

/// Cascading filter: subfields for a given field
final subfieldsProvider =
    FutureProvider.family<List<TopicHierarchyItem>, String?>((ref, fieldId) {
      return ref.read(topicDataSourceProvider).getSubfields(fieldId: fieldId);
    });

/// Cascading filter: topics for a given subfield
final topicsProvider = FutureProvider.family<List<TopicHierarchyItem>, String?>(
  (ref, subfieldId) {
    return ref.read(topicDataSourceProvider).getTopics(subfieldId: subfieldId);
  },
);

// ── Paginated Publications (internal, for fetching) ───────────────────────────

/// Fetches the current page result. Used internally for loading data.
final paginatedPublicationsProvider =
    FutureProvider<PaginatedResult<Publication>>((ref) async {
      final topicFilter = ref.watch(selectedTopicFilterProvider);
      final query = ref.watch(searchQueryProvider);
      final page = ref.watch(searchPageProvider);
      final perPage = ref.watch(searchPerPageProvider);

      if (topicFilter != null) {
        return ref
            .read(publicationRepositoryProvider)
            .searchByTopicFilter(
              topicFilter.filterKey,
              topicFilter.id,
              page: page,
              perPage: perPage,
            );
      }

      if (query.isEmpty) {
        return const PaginatedResult(
          items: [],
          totalCount: 0,
          page: 1,
          perPage: 50,
        );
      }
      return ref.read(searchPublicationsUseCaseProvider)(
        query,
        page: page,
        perPage: perPage,
      );
    });

/// Convenience: flat list of publications from the current page.
final publicationsProvider = Provider<AsyncValue<List<Publication>>>((ref) {
  return ref.watch(paginatedPublicationsProvider).whenData((r) => r.items);
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

// ── Trending ──────────────────────────────────────────────────────────────────

/// Fetches live domain categories for the trending chips.
final trendingCategoriesProvider = domainsProvider;

/// Current page for trending publications pagination.
final trendingPageProvider = StateProvider.family<int, String?>((_, _) => 1);

/// Fetches trending publications filtered by an optional OpenAlex domain ID.
/// Now returns paginated result with totalCount from the API.
final trendingPublicationsProvider =
    FutureProvider.family<PaginatedResult<Publication>, String?>((
      ref,
      domainId,
    ) async {
      final page = ref.watch(trendingPageProvider(domainId));
      final response = await ref
          .read(remoteDataSourceProvider)
          .getTrending(domainId: domainId, page: page, perPage: 50);
      final pubs = response.results.map((m) => m.toEntity()).toList();
      return PaginatedResult(
        items: pubs,
        totalCount: response.totalCount,
        page: page,
        perPage: 50,
      );
    });

/// Fetches yearly publication counts for a domain (or all fields) from OpenAlex group_by API.
final trendingYearlyCountsProvider =
    FutureProvider.family<List<YearCountData>, String?>((ref, domainId) async {
      final results = await ref
          .read(remoteDataSourceProvider)
          .getYearlyCountsForDomain(domainId: domainId);
      return results
          .map((r) => YearCountData(year: r.year, count: r.count))
          .toList();
    });

/// Simple year-count data class for the trending chart.
class YearCountData {
  final int year;
  final int count;
  const YearCountData({required this.year, required this.count});
}

// ── Sort ──────────────────────────────────────────────────────────────────────

enum PaperSortOption { relevance, citationCount, year, title }

final paperSortOptionProvider = StateProvider<PaperSortOption>(
  (_) => PaperSortOption.relevance,
);

final sortedPublicationsProvider = Provider<List<Publication>>((ref) {
  final pubs = List<Publication>.from(
    ref.watch(publicationsProvider).value ?? [],
  );
  final sort = ref.watch(paperSortOptionProvider);

  switch (sort) {
    case PaperSortOption.relevance:
      break;
    case PaperSortOption.citationCount:
      pubs.sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
    case PaperSortOption.year:
      pubs.sort(
        (a, b) => (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0),
      );
    case PaperSortOption.title:
      pubs.sort((a, b) => a.title.compareTo(b.title));
  }

  return pubs;
});
