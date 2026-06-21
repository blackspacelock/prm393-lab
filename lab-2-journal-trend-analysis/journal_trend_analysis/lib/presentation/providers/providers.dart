// Presentation layer — dependency injection and reactive state via Riverpod.
// All infrastructure is wired here; screens only see typed providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/openalex_api_client.dart';
import '../../data/datasources/publication_remote_datasource.dart';
import '../../data/datasources/topic_remote_datasource.dart';
import '../../data/repositories/publication_repository_impl.dart';
import '../../domain/entities/paginated_result.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../../domain/repositories/publication_repository.dart';
import '../../domain/usecases/get_dashboard_summary.dart';
import '../../domain/usecases/get_keyword_analysis.dart';
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

final getKeywordAnalysisProvider = Provider<GetKeywordAnalysis>(
  (_) => GetKeywordAnalysis(),
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
        final models = await ref
            .read(remoteDataSourceProvider)
            .getTrending(domainId: null);
        final items = models.map((m) => m.toEntity()).toList();
        return PaginatedResult(
          items: items,
          totalCount: items.length,
          page: 1,
          perPage: items.length,
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

/// Analysis views focus on the most recent 10-year window, matching Home trend.
final recentPublicationsProvider = Provider<List<Publication>>((ref) {
  final pubs = ref.watch(publicationsProvider).value ?? [];
  final cutoffYear = DateTime.now().year - 10;
  return pubs.where((p) => (p.publicationYear ?? 0) >= cutoffYear).toList();
});

/// Year-by-year trend derived from the current publication list.
final trendDataProvider = Provider<List<YearTrendData>>((ref) {
  final pubs = ref.watch(recentPublicationsProvider);
  return ref.read(getTrendDataUseCaseProvider)(pubs);
});

/// Dashboard KPIs derived from the current publication list.
final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final pubs = ref.watch(recentPublicationsProvider);
  return ref.read(getDashboardSummaryUseCaseProvider)(pubs);
});

/// Top authors ranked by publication count.
final topAuthorsProvider = Provider<List<AuthorWithCount>>((ref) {
  final pubs = ref.watch(recentPublicationsProvider);
  return ref.read(getTopAuthorsUseCaseProvider)(pubs);
});

/// Top journals ranked by publication count.
final topJournalsProvider = Provider<List<JournalWithCount>>((ref) {
  final pubs = ref.watch(recentPublicationsProvider);
  return ref.read(getTopJournalsUseCaseProvider)(pubs);
});

/// Publications from one journal in the current result set, sorted by citations.
final journalPublicationsProvider = Provider.family<List<Publication>, String>((
  ref,
  journalName,
) {
  final pubs = ref.watch(recentPublicationsProvider);
  return pubs.where((p) => p.journalName == journalName).toList()
    ..sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
});

final keywordsProvider = Provider<List<KeywordItem>>((ref) {
  final pubs = ref.watch(recentPublicationsProvider);
  return ref.read(getKeywordAnalysisProvider)(pubs);
});

final keywordPublicationsProvider = Provider.family<List<Publication>, String>((
  ref,
  name,
) {
  final pubs = ref.watch(recentPublicationsProvider);
  return pubs
      .where((p) => p.concepts.any((c) => c.displayName == name))
      .toList()
    ..sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
});

final keywordTrendProvider = Provider.family<List<YearTrendData>, String>((
  ref,
  name,
) {
  return ref.read(getTrendDataUseCaseProvider)(
    ref.watch(keywordPublicationsProvider(name)),
  );
});

final keywordJournalsProvider = Provider.family<List<JournalWithCount>, String>(
  (ref, name) {
    return ref.read(getTopJournalsUseCaseProvider)(
      ref.watch(keywordPublicationsProvider(name)),
      limit: 5,
    );
  },
);

final keywordAuthorsProvider = Provider.family<List<AuthorWithCount>, String>((
  ref,
  name,
) {
  return ref.read(getTopAuthorsUseCaseProvider)(
    ref.watch(keywordPublicationsProvider(name)),
  );
});

/// Year-by-year publication counts for 2016–present using OpenAlex group_by.
/// Reacts to the active search query / topic filter so the chart updates on demand.
final yearlyTrendProvider = FutureProvider<List<YearTrendData>>((ref) async {
  final topicFilter = ref.watch(selectedTopicFilterProvider);
  final query = ref.watch(searchQueryProvider);

  String? filterString;
  String? searchQuery;

  if (topicFilter != null) {
    if (topicFilter.filterKey == 'default.search') {
      searchQuery = topicFilter.id;
    } else {
      filterString = '${topicFilter.filterKey}:${topicFilter.id}';
    }
  } else if (query.isNotEmpty) {
    searchQuery = query;
  }

  final counts = await ref
      .read(remoteDataSourceProvider)
      .getYearlyPublicationCounts(
        filterString: filterString,
        searchQuery: searchQuery,
      );

  return (counts.entries
      .map(
        (e) => YearTrendData(
          year: e.key,
          publicationCount: e.value,
          totalCitations: 0,
        ),
      )
      .toList()
    ..sort((a, b) => a.year.compareTo(b.year)));
});

/// Top concept names extracted from the current publication list, ranked by frequency.
final trendingTopicsProvider = Provider<List<String>>((ref) {
  final pubs = ref.watch(recentPublicationsProvider);
  final counts = <String, int>{};
  for (final pub in pubs) {
    for (final concept in pub.concepts) {
      final name = concept.displayName;
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(16).map((e) => e.key).toList();
});

// ── Trending ──────────────────────────────────────────────────────────────────

/// Fetches live domain categories for the trending chips.
final trendingCategoriesProvider = domainsProvider;

/// Fetches trending publications filtered by an optional OpenAlex domain ID.
final trendingPublicationsProvider =
    FutureProvider.family<List<Publication>, String?>((ref, domainId) async {
      final models = await ref
          .read(remoteDataSourceProvider)
          .getTrending(domainId: domainId);
      return models.map((m) => m.toEntity()).toList();
    });

// ── Sort ──────────────────────────────────────────────────────────────────────

enum PaperSortOption { relevance, citationCount, year, title }

final paperSortOptionProvider = StateProvider<PaperSortOption>(
  (_) => PaperSortOption.citationCount,
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
