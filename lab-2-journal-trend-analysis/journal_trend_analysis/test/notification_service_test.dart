import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analysis/firebase/notification_service.dart';

void main() {
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
}
