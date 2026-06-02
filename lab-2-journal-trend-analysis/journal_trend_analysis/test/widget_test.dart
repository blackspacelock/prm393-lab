import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analysis/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: JournalTrendAnalyzerApp()),
    );
    expect(find.byType(JournalTrendAnalyzerApp), findsOneWidget);
  });
}
