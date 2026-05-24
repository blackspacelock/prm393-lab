import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:day_night_switcher/day_night_switcher.dart';
import 'package:fu_grading/providers/theme_provider.dart';

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DayNightSwitcher(
      isDarkModeEnabled: themeProvider.isDarkMode,
      onStateChanged: (isDarkModeEnabled) {
        final provider = Provider.of<ThemeProvider>(context, listen: false);
        provider.toggleTheme(isDarkModeEnabled);
      },
    );
  }
}
