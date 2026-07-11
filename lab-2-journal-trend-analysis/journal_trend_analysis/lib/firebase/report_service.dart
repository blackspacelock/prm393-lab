import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/entities/publication.dart';
import '../domain/usecases/get_dashboard_summary.dart';
import '../domain/usecases/get_top_authors.dart';
import '../domain/usecases/get_top_journals.dart';
import 'analytics_service.dart';

class ReportService {
  ReportService(this._storage);

  final FirebaseStorage _storage;

  Future<String> export({
    required String userId,
    required String topic,
    required DashboardSummary summary,
    required List<AuthorWithCount> authors,
    required List<JournalWithCount> journals,
    required List<Publication> publications,
  }) async {
    final bytes = await ReportService.buildPdf(
      topic: topic,
      summary: summary,
      authors: authors,
      journals: journals,
      publications: publications,
    );
    final ref = _storage.ref(
      'reports/$userId/report-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {'topic': topic},
      ),
    );
    final url = await ref.getDownloadURL();
    await analyticsService.exportPdf(topic);
    return url;
  }

  static Future<Uint8List> buildPdf({
    required String topic,
    required DashboardSummary summary,
    required List<AuthorWithCount> authors,
    required List<JournalWithCount> journals,
    required List<Publication> publications,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('Journal Trend Analyzer')),
          pw.Text('Topic: $topic'),
          pw.Text('Generated: ${DateTime.now().toLocal()}'),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, child: pw.Text('Dashboard summary')),
          pw.Bullet(text: 'Publications: ${summary.totalPublications}'),
          pw.Bullet(
            text: 'Average citations: ${summary.avgCitations.toStringAsFixed(1)}',
          ),
          pw.Bullet(text: 'Most active year: ${summary.mostActiveYear ?? 'N/A'}'),
          pw.Bullet(text: 'Top author: ${summary.topAuthorName ?? 'N/A'}'),
          pw.Bullet(text: 'Top journal: ${summary.topJournalName ?? 'N/A'}'),
          pw.Bullet(
            text:
                'Most influential publication: ${summary.mostInfluentialPaper?.title ?? 'N/A'}',
          ),
          pw.Header(level: 1, child: pw.Text('Publication trend')),
          pw.TableHelper.fromTextArray(
            headers: const ['Year', 'Publications', 'Citations'],
            data: summary.sparklineData
                .map(
                  (item) => [
                    item.year,
                    item.publicationCount,
                    item.totalCitations,
                  ],
                )
                .toList(),
          ),
          pw.Header(level: 1, child: pw.Text('Top journals')),
          ...journals.take(10).map(
            (item) => pw.Bullet(
              text:
                  '${item.name}: ${item.publicationCount} publications, ${item.totalCitations} citations',
            ),
          ),
          pw.Header(level: 1, child: pw.Text('Top authors')),
          ...authors.take(10).map(
            (item) => pw.Bullet(
              text:
                  '${item.author.displayName}: ${item.publicationCount} publications, ${item.totalCitations} citations',
            ),
          ),
          pw.Header(level: 1, child: pw.Text('Most influential publications')),
          ...([...publications]
                ..sort((a, b) => b.citedByCount.compareTo(a.citedByCount)))
              .take(10)
              .map(
                (item) => pw.Bullet(
                  text:
                      '${item.title} (${item.publicationYear ?? 'N/A'}) - ${item.citedByCount} citations',
                ),
              ),
        ],
      ),
    );
    return pdf.save();
  }
}
