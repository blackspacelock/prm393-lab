import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashlyticsService {
  CrashlyticsService(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  Future<void> recordHandledException() async {
    await _crashlytics.recordError(
      StateError('Handled Crashlytics demonstration'),
      StackTrace.current,
      reason: 'User requested the handled exception demo',
      fatal: false,
    );
  }

  void testCrash() => _crashlytics.crash();
}

final crashlyticsService = CrashlyticsService(
  FirebaseCrashlytics.instance,
);
