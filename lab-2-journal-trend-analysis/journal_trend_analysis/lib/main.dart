import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'firebase/notification_service.dart';
import 'presentation/providers/remote_config_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is only configured for Android; skip on other platforms.
  final firebaseSupported =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  if (firebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
    // On platforms without Firebase (e.g. Windows/Linux), skip auth.
    final firebaseAvailable =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (!firebaseAvailable) {
      return MaterialApp.router(
        title: 'Journal Trend Analyzer',
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      );
    }

    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user == null
          ? MaterialApp(
              title: 'Journal Trend Analyzer',
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: const LoginScreen(),
            )
          : MaterialApp.router(
              title: 'Journal Trend Analyzer',
              theme: AppTheme.lightTheme,
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
            ),
      loading: () => MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: Text('Authentication error: $error')),
        ),
      ),
    );
  }
}
