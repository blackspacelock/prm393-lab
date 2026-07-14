import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analysis/firebase/remote_config_service.dart';

void main() {
  test('remote display limits stay within safe bounds', () {
    final limits = RemoteLimits.fromValues(
      maxJournals: -1,
      maxKeywords: 1000,
    );

    expect(limits.maxJournals, 1);
    expect(limits.maxKeywords, 100);
  });
}
