// Presentation layer — Riverpod providers for Journals feature.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/journal_remote_datasource.dart';
import '../../data/repositories/journal_repository_impl.dart';
import '../../domain/entities/journal.dart';
import '../../domain/entities/paginated_result.dart';
import '../../domain/entities/publication.dart';
import '../../domain/repositories/journal_repository.dart';
import 'providers.dart';
import 'remote_config_providers.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final journalDataSourceProvider = Provider<JournalRemoteDataSource>(
  (ref) => JournalRemoteDataSourceImpl(ref.read(apiClientProvider)),
);

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepositoryImpl(ref.read(journalDataSourceProvider)),
);

// ── Journal Sort ──────────────────────────────────────────────────────────────

/// Sort options for the journals list.
enum JournalSortOption { citations, papers, authors, recentlyActive }

/// Current sort option for the journals page.
final journalSortProvider = StateProvider<JournalSortOption>(
  (_) => JournalSortOption.papers,
);

// ── Journal Search State ──────────────────────────────────────────────────────

/// Current search query for journals page.
final journalSearchQueryProvider = StateProvider<String>((_) => '');

/// Current page for journal list pagination.
final journalPageProvider = StateProvider<int>((_) => 1);

// ── Journal List ──────────────────────────────────────────────────────────────

/// Fetches journals: if query is empty, shows recent journals; otherwise searches.
/// Respects the current sort option.
final journalListProvider = FutureProvider<PaginatedResult<Journal>>((
  ref,
) async {
  final query = ref.watch(journalSearchQueryProvider);
  final page = ref.watch(journalPageProvider);
  final sort = ref.watch(journalSortProvider);
  final perPage = ref.watch(remoteLimitsProvider).value?.maxJournals ?? 10;

  // Map sort enum to API sort string
  final sortParam = switch (sort) {
    JournalSortOption.citations => 'cited_by_count:desc',
    JournalSortOption.papers => 'works_count:desc',
    JournalSortOption.authors => 'summary_stats.2yr_mean_citedness:desc',
    JournalSortOption.recentlyActive => 'works_count:desc',
  };

  // For "recently active", add a date filter
  final extraFilter = sort == JournalSortOption.recentlyActive
      ? 'type:journal,has_issn:true'
      : 'type:journal';

  if (query.isEmpty) {
    return ref
        .read(journalRepositoryProvider)
        .getRecentJournals(
          page: page,
          perPage: perPage,
          sort: sortParam,
          filter: extraFilter,
        );
  }
  return ref
      .read(journalRepositoryProvider)
      .searchJournals(query, page: page, perPage: perPage, sort: sortParam);
});

// ── Journal Detail ────────────────────────────────────────────────────────────

/// Fetches a single journal by ID.
final journalDetailProvider = FutureProvider.family<Journal, String>((
  ref,
  id,
) async {
  return ref.read(journalRepositoryProvider).getJournalById(id);
});

/// Current page for journal publications pagination.
final journalPubsPageProvider = StateProvider<int>((_) => 1);

/// Fetches publications for a specific journal (by source ID).
final journalPublicationsProvider =
    FutureProvider.family<PaginatedResult<Publication>, String>((
      ref,
      sourceId,
    ) async {
      final page = ref.watch(journalPubsPageProvider);
      return ref
          .read(journalRepositoryProvider)
          .getJournalPublications(sourceId, page: page, perPage: 50);
    });
