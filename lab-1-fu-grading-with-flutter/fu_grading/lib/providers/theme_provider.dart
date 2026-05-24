import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyThemes {
  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4A90D9),
      surface: Color(0xFF1E1E2E),
    ),
    scaffoldBackgroundColor: const Color(0xFF1E1E2E),
    cardColor: const Color(0xFF2A2A3E),
  );

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Colors.cyan, 
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.cyan.shade100,
  );
}
