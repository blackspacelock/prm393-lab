import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analysis/firebase/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notification survives local JSON round trip', () {
    final original = ReceivedNotification(
      id: 'message-1',
      title: 'Trending topic',
      body: 'AI publications are rising.',
      receivedAt: DateTime.utc(2026, 7, 11),
    );

    final restored = ReceivedNotification.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.body, original.body);
    expect(restored.receivedAt, original.receivedAt);
  });

  test('refresh loads background notification history', () async {
    SharedPreferences.setMockInitialValues({
      'fcm_messages': [
        jsonEncode({
          'id': 'message-2',
          'title': 'New papers',
          'body': 'A topic update arrived.',
          'receivedAt': '2026-07-17T08:39:08.547',
        }),
      ],
    });

    final messages = await NotificationService.instance.refresh();
    expect(messages.single.title, 'New papers');
  });
}
