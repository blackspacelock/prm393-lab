import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analysis/domain/usecases/get_dashboard_summary.dart';
import 'package:journal_trend_analysis/firebase/report_service.dart';

void main() {
  test('generates a PDF report', () async {
    final bytes = await ReportService.buildPdf(
      topic: 'Artificial intelligence',
      summary: const DashboardSummary(
        totalPublications: 0,
        avgCitations: 0,
        sparklineData: [],
      ),
      authors: const [],
      journals: const [],
      publications: const [],
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
