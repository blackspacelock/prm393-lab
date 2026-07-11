import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> login() => _analytics.logEvent(
    name: 'login',
    parameters: const {'method': 'google'},
  );

  Future<void> searchTopic(String keyword) => _analytics.logEvent(
    name: 'search_topic',
    parameters: {'keyword': keyword},
  );

  Future<void> viewPublication(String title, int? year) =>
      _analytics.logEvent(
        name: 'view_publication',
        parameters: {
          'publication_title': title,
          if (year != null) 'publication_year': year,
        },
      );

  Future<void> viewJournal(String name) => _analytics.logEvent(
    name: 'view_journal',
    parameters: {'journal_name': name},
  );

  Future<void> viewKeyword(String keyword) => _analytics.logEvent(
    name: 'view_keyword',
    parameters: {'keyword': keyword},
  );

  Future<void> exportPdf(String topic) => _analytics.logEvent(
    name: 'export_pdf',
    parameters: {'topic': topic},
  );

  Future<void> logout() => _analytics.logEvent(name: 'logout');
}

final analyticsService = AnalyticsService(FirebaseAnalytics.instance);
