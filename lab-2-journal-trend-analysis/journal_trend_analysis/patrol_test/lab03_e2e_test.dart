import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analysis/core/router/app_router.dart';
import 'package:journal_trend_analysis/firebase_options.dart';
import 'package:journal_trend_analysis/main.dart';
import 'package:patrol/patrol.dart';

const _wait = Duration(seconds: 45);

Future<void> _pumpApp(PatrolIntegrationTester $) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  appRouter.go('/home');
  await $.tester.pumpWidget(
    const ProviderScope(child: JournalTrendAnalyzerApp()),
  );
  await $(NavigationBar).waitUntilVisible(timeout: _wait);
}

Future<void> _ensureSignedIn(PatrolIntegrationTester $) async {
  await $(NavigationDestination).at(3).tap();
  if ($(#signOutButton).exists) {
    await $(NavigationDestination).at(0).tap();
    return;
  }
  await $(#guestSignInButton).tap();
  await $(#googleSignInButton).tap();
  await Future<void>.delayed(const Duration(seconds: 2));
  try {
    await $.platform.android.tap(
      AndroidSelector(textContains: '@', instance: 0),
      timeout: const Duration(seconds: 5),
    );
  } on Exception {
    // Google may sign in immediately without showing the account chooser.
  }
  await $(#signOutButton).waitUntilVisible(timeout: _wait);
  await $(NavigationDestination).at(0).tap();
}

Future<void> _searchTopic(PatrolIntegrationTester $, String topic) async {
  await $(NavigationDestination).at(2).tap();
  await $(#topicSearchField).enterText(topic);
  final field = $.tester.widget<TextField>(
    find.byKey(const Key('topicSearchField')),
  );
  field.onSubmitted?.call(topic);
  await $.tester.pump();
  await $(const Key('publicationResult-1')).waitUntilVisible(timeout: _wait);
}

Future<void> _openProfile(PatrolIntegrationTester $) async {
  await $(NavigationDestination).at(3).tap();
  await $('Profile').waitUntilVisible(timeout: _wait);
}

void main() {
  patrolTest('TC01 guest can browse and Google Sign-In unlocks profile', (
    $,
  ) async {
    await _pumpApp($);
    await _ensureSignedIn($);
    expect($('Home'), findsWidgets);
  });

  patrolTest('TC02 topic search displays publication results', ($) async {
    await _pumpApp($);
    await _searchTopic($, 'artificial intelligence');
    expect($(const Key('publicationResult-1')), findsOneWidget);
  });

  patrolTest('TC03 publication opens complete details', ($) async {
    await _pumpApp($);
    await _searchTopic($, 'artificial intelligence');
    final card = $.tester.widget<InkWell>(
      find.byKey(const Key('publicationResult-1')),
    );
    card.onTap?.call();
    await $.tester.pump();
    await $('Publication Details').waitUntilVisible(timeout: _wait);
    expect($('Year'), findsWidgets);
    expect($('Authors'), findsWidgets);
    expect($('Journal'), findsWidgets);
  });

  patrolTest('TC04 Journals tab displays journal statistics', ($) async {
    await _pumpApp($);
    await $(NavigationDestination).at(1).tap();
    await $(const Key('journalResult-1')).waitUntilVisible(timeout: _wait);
    expect($('Journals'), findsWidgets);
    expect($(const Key('journalResult-1')), findsOneWidget);
  });

  patrolTest('TC05 journal opens journal details', ($) async {
    await _pumpApp($);
    await $(NavigationDestination).at(1).tap();
    await $(const Key('journalResult-1')).waitUntilVisible(timeout: _wait);
    await $(const Key('journalResult-1')).tap();
    await $('Filter by Topic').waitUntilVisible(timeout: _wait);
    expect($('Authors'), findsWidgets);
    expect($('Papers'), findsWidgets);
  });

  patrolTest('TC06 Keywords tab displays keyword analysis navigation', (
    $,
  ) async {
    await _pumpApp($);
    await $(NavigationDestination).at(2).tap();
    await $('Keywords').waitUntilVisible(timeout: _wait);
    expect($('Papers'), findsOneWidget);
    expect($('Dashboard'), findsOneWidget);
    expect($(#topicSearchField), findsOneWidget);
  });

  patrolTest('TC07 keyword dashboard displays required analysis', ($) async {
    await _pumpApp($);
    await _searchTopic($, 'machine learning');
    await $('Dashboard').tap();
    await $('Publications per year').waitUntilVisible(timeout: _wait);
    expect($('Top Journals'), findsOneWidget);
    expect($('Top Authors'), findsOneWidget);
  });

  patrolTest('TC08 Profile displays authenticated user information', ($) async {
    await _pumpApp($);
    await _ensureSignedIn($);
    await _openProfile($);
    expect($(#signOutButton), findsOneWidget);
    expect($('Export PDF Report'), findsOneWidget);
  });

  patrolTest('TC09 PDF report uploads and can be opened', ($) async {
    await _pumpApp($);
    await _ensureSignedIn($);
    await _searchTopic($, 'artificial intelligence');
    await _openProfile($);
    await $(#exportPdfButton).scrollTo().tap();
    await $(
      #openPdfButton,
    ).waitUntilVisible(timeout: const Duration(seconds: 90));
    expect($(#openPdfButton), findsOneWidget);
  });

  patrolTest('TC10 Remote Config diagnostics stay hidden from users', (
    $,
  ) async {
    await _pumpApp($);
    await _ensureSignedIn($);
    await _openProfile($);
    expect($('Remote Config'), findsNothing);
  });

  patrolTest('TC11 logout returns to guest profile', ($) async {
    await _pumpApp($);
    await _ensureSignedIn($);
    await _openProfile($);
    await $(#signOutButton).tap();
    await $(#guestSignInButton).waitUntilVisible(timeout: _wait);
    expect($(#guestSignInButton), findsOneWidget);
  });
}
