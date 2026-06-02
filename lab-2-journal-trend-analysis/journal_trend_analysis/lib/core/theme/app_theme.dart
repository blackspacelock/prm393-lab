import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.secondaryContainer,
        onPrimaryContainer: AppColors.onSecondaryContainer,
        secondary: AppColors.primary,
        onSecondary: AppColors.onPrimary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.rankBronze,
        onTertiary: AppColors.onPrimary,
        tertiaryContainer: AppColors.citationChipBg,
        onTertiaryContainer: AppColors.citationChipText,
        error: Color(0xFFD93025),
        onError: AppColors.onPrimary,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: AppColors.surfaceContainerLowest,
        onSurface: AppColors.onSurface,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: AppColors.onSurface,
        onInverseSurface: AppColors.surface,
        inversePrimary: AppColors.secondaryContainer,
        surfaceTint: AppColors.primaryContainer,
      ),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleMedium,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTextStyles.labelMedium
                  .copyWith(color: AppColors.primaryContainer)
              : AppTextStyles.labelMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const IconThemeData(color: AppColors.primaryContainer)
              : const IconThemeData(color: AppColors.onSurfaceVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle:
            AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface),
        iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
        actionsIconTheme:
            const IconThemeData(color: AppColors.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
          side:
              const BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainer,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
          borderSide:
              const BorderSide(color: AppColors.primaryContainer, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerHighest,
        selectedColor: AppColors.secondaryContainer,
        disabledColor: AppColors.surfaceContainerHighest,
        labelStyle:
            AppTextStyles.labelLarge.copyWith(color: AppColors.onSurface),
        secondaryLabelStyle: AppTextStyles.labelLarge
            .copyWith(color: AppColors.onSecondaryContainer),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
        ),
        side: const BorderSide(color: AppColors.outlineVariant, width: 1),
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.xs),
      ),
    );
  }
}
