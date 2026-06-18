import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/author.dart';
import '../../domain/entities/publication.dart';

class BookmarkLocalDatasource {
  static const _key = 'bookmarks_v1';

  Future<List<Publication>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => _decode(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<Publication> pubs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, pubs.map((p) => jsonEncode(_encode(p))).toList());
  }

  Map<String, dynamic> _encode(Publication p) => {
    'id': p.id,
    'title': p.title,
    'publicationYear': p.publicationYear,
    'citedByCount': p.citedByCount,
    'doi': p.doi,
    'journalName': p.journalName,
    'authors': p.authors
        .map((a) => {'id': a.id, 'displayName': a.displayName})
        .toList(),
    'abstractInvertedIndex': p.abstractInvertedIndex,
    'concepts': p.concepts,
    'countsByYear': p.countsByYear
        .map((c) => {'year': c.year, 'citedByCount': c.citedByCount})
        .toList(),
  };

  Publication _decode(Map<String, dynamic> j) => Publication(
    id: j['id'] as String,
    title: j['title'] as String,
    publicationYear: j['publicationYear'] as int?,
    citedByCount: j['citedByCount'] as int,
    doi: j['doi'] as String?,
    journalName: j['journalName'] as String?,
    authors: (j['authors'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((a) => Author(id: a['id'] as String, displayName: a['displayName'] as String))
        .toList(),
    abstractInvertedIndex: j['abstractInvertedIndex'] as Map<String, dynamic>?,
    concepts: (j['concepts'] as List<dynamic>).cast<String>(),
    countsByYear: (j['countsByYear'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((c) => YearlyCitation(year: c['year'] as int, citedByCount: c['citedByCount'] as int))
        .toList(),
  );
}
