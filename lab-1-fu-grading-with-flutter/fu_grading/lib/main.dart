import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/app_state.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop window configuration (desktop only)
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      title: 'FU Grading',
      minimumSize: Size(1024, 600),
      size: Size(1280, 720),
      center: true,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const FuGradingApp(),
    ),
  );
}

class FuGradingApp extends StatelessWidget {
  const FuGradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FU Grading',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4A90D9),
          surface: Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        cardColor: const Color(0xFF2A2A3E),
      ),
      home: const HomeScreen(),
    );
  }
}
