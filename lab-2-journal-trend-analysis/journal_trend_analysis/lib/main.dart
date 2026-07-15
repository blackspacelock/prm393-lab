import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'firebase/notification_service.dart';
import 'presentation/providers/auth_providers.dart';
import 'presentation/providers/remote_config_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (firebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // FCM & Crashlytics are available on both Android and iOS
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await NotificationService.instance.initialize();
  }

  runApp(const ProviderScope(child: JournalTrendAnalyzerApp()));
}

class JournalTrendAnalyzerApp extends ConsumerWidget {
  const JournalTrendAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (firebaseSupported) ref.watch(remoteLimitsProvider);
    return MaterialApp.router(
      title: 'Journal Trend Analyzer',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
