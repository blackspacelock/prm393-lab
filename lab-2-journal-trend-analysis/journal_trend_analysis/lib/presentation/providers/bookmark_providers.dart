import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/bookmark_local_datasource.dart';
import '../../domain/entities/publication.dart';

final bookmarkDatasourceProvider = Provider<BookmarkLocalDatasource>(
  (_) => BookmarkLocalDatasource(),
);

class BookmarkNotifier extends AsyncNotifier<List<Publication>> {
  @override
  Future<List<Publication>> build() {
    return ref.read(bookmarkDatasourceProvider).loadAll();
  }

  Future<void> toggle(Publication pub) async {
    final current = state.value ?? [];
    final exists = current.any((p) => p.id == pub.id);
    final updated = exists
        ? current.where((p) => p.id != pub.id).toList()
        : [...current, pub];
    state = AsyncData(updated);
    await ref.read(bookmarkDatasourceProvider).save(updated);
  }
}

final bookmarkNotifierProvider =
    AsyncNotifierProvider<BookmarkNotifier, List<Publication>>(
  BookmarkNotifier.new,
);

/// Derived provider — true if the given publication id is bookmarked.
final isBookmarkedProvider = Provider.family<bool, String>((ref, id) {
  final bookmarks = ref.watch(bookmarkNotifierProvider).value ?? [];
  return bookmarks.any((p) => p.id == id);
});
