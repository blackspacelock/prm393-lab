import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analysis/main.dart';
import 'package:journal_trend_analysis/core/router/app_router.dart';
import 'package:journal_trend_analysis/firebase/remote_config_service.dart';
import 'package:journal_trend_analysis/presentation/providers/auth_providers.dart';
import 'package:journal_trend_analysis/presentation/providers/remote_config_providers.dart';

void main() {
  testWidgets('Guest can open the app but profile actions require sign-in', (
    WidgetTester tester,
  ) async {
    appRouter.go('/profile');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((_) => Stream.value(null)),
          remoteLimitsProvider.overrideWith(
            (_) => Stream.value(
              const RemoteLimits(
                maxJournals: 10,
                maxKeywords: 10,
                updated: false,
              ),
            ),
          ),
        ],
        child: const JournalTrendAnalyzerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guestSignInButton')), findsOneWidget);
    expect(find.text('Export PDF Report'), findsNothing);
  });
}
