import '../../domain/entities/publication.dart';

/// Generates reference export strings from a list of [Publication] objects.
class ExportHelper {
  ExportHelper._();

  static String toBibTeX(List<Publication> pubs) {
    final buffer = StringBuffer();
    for (final pub in pubs) {
      final key = _bibtexKey(pub);
      final authors = pub.authors.map((a) => a.displayName).join(' and ');
      buffer.writeln('@article{$key,');
      buffer.writeln('  title = {${_escape(pub.title)}},');
      if (authors.isNotEmpty) buffer.writeln('  author = {$authors},');
      if (pub.journalName != null) {
        buffer.writeln('  journal = {${_escape(pub.journalName!)}},');
      }
      if (pub.publicationYear != null) {
        buffer.writeln('  year = {${pub.publicationYear}},');
      }
      if (pub.doi != null) buffer.writeln('  doi = {${pub.doi}},');
      buffer.writeln('}');
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static String toRIS(List<Publication> pubs) {
    final buffer = StringBuffer();
    for (final pub in pubs) {
      buffer.writeln('TY  - JOUR');
      buffer.writeln('TI  - ${pub.title}');
      for (final author in pub.authors) {
        buffer.writeln('AU  - ${author.displayName}');
      }
      if (pub.journalName != null) buffer.writeln('JO  - ${pub.journalName}');
      if (pub.publicationYear != null) buffer.writeln('PY  - ${pub.publicationYear}');
      if (pub.doi != null) buffer.writeln('DO  - ${pub.doi}');
      buffer.writeln('ER  -');
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static String toCSV(List<Publication> pubs) {
    final buffer = StringBuffer();
    buffer.writeln('Title,Authors,Journal,Year,Citations,DOI');
    for (final pub in pubs) {
      final authors = pub.authors.map((a) => a.displayName).join('; ');
      buffer.writeln([
        _csvCell(pub.title),
        _csvCell(authors),
        _csvCell(pub.journalName ?? ''),
        pub.publicationYear?.toString() ?? '',
        pub.citedByCount.toString(),
        _csvCell(pub.doi ?? ''),
      ].join(','));
    }
    return buffer.toString().trim();
  }

  /// Plain-text APA-style citation for clipboard copy.
  static String toPlainCitation(Publication pub) {
    final buffer = StringBuffer();

    if (pub.authors.isNotEmpty) {
      final names = pub.authors.map((a) => a.displayName).toList();
      if (names.length <= 3) {
        buffer.write(names.join(', '));
      } else {
        buffer.write('${names.take(3).join(', ')}, et al.');
      }
    }

    if (pub.publicationYear != null) {
      buffer.write(' (${pub.publicationYear}).');
    } else {
      buffer.write('.');
    }

    buffer.write(' ${pub.title}.');

    if (pub.journalName != null) buffer.write(' ${pub.journalName}.');

    if (pub.doi != null) {
      final doi = pub.doi!;
      buffer.write(' ${doi.startsWith('http') ? doi : 'https://doi.org/$doi'}');
    }

    return buffer.toString();
  }

  static String _bibtexKey(Publication pub) {
    final firstAuthor = pub.authors.isNotEmpty
        ? pub.authors.first.displayName.split(' ').last.toLowerCase()
        : 'unknown';
    final year = pub.publicationYear?.toString() ?? '0000';
    final titleWord = pub.title.split(' ').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$firstAuthor$year$titleWord';
  }

  static String _escape(String s) => s.replaceAll('{', r'\{').replaceAll('}', r'\}');

  static String _csvCell(String s) {
    final escaped = s.replaceAll('"', '""');
    return '"$escaped"';
  }
}
