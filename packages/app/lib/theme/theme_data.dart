// Generated ThemeData builder for WireTuner
// Uses tokens from tokens.dart to build Material ThemeData

import 'package:flutter/material.dart';
import 'tokens.dart';

/// Build Material ThemeData from WireTuner design tokens
///
/// This creates a ThemeData that integrates our custom design tokens
/// with Flutter's Material Design system, ensuring consistency across
/// both custom and standard Material components.
ThemeData buildWireTunerTheme({Brightness brightness = Brightness.dark}) {
  final tokens = brightness == Brightness.dark
      ? WireTunerTokens.dark
      : WireTunerTokens.light;

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,

    // Color scheme derived from tokens
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: tokens.accent.primary.value,
      onPrimary: tokens.text.onAccent,
      primaryContainer: tokens.accent.primary.pressed,
      onPrimaryContainer: tokens.text.onAccent,
      secondary: tokens.accent.secondary.value,
      onSecondary: tokens.text.onAccent,
      secondaryContainer: tokens.accent.secondary.hover,
      onSecondaryContainer: tokens.text.onAccent,
      tertiary: tokens.accent.tertiary.value,
      onTertiary: tokens.text.onAccent,
      tertiaryContainer: tokens.accent.tertiary.value,
      onTertiaryContainer: tokens.text.onAccent,
      error: tokens.semantic.error.value,
      onError: tokens.semantic.error.onColor,
      errorContainer: tokens.semantic.error.value,
      onErrorContainer: tokens.semantic.error.onColor,
      surface: tokens.surface.base,
      onSurface: tokens.text.primary,
      surfaceContainerHighest: tokens.surface.raised,
      onSurfaceVariant: tokens.text.secondary,
      outline: tokens.canvas.artboardBorder,
      outlineVariant: tokens.grid.minor,
      shadow: const Color(0xFF000000),
      scrim: tokens.surface.overlay,
      inverseSurface: tokens.canvas.artboardDefault,
      onInverseSurface: tokens.text.onAccent,
      inversePrimary: tokens.accent.primary.pressed,
    ),

    // Scaffold background
    scaffoldBackgroundColor: tokens.surface.base,

    // App bar theme
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.surface.base,
      foregroundColor: tokens.text.primary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: tokens.typography.lg.toTextStyle(
        color: tokens.text.primary,
      ),
    ),

    // Card theme
    cardTheme: CardTheme(
      color: tokens.surface.raised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
      ),
      margin: EdgeInsets.all(tokens.spacing.spacing8),
    ),

    // Elevated button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.accent.primary.value,
        foregroundColor: tokens.text.onAccent,
        minimumSize: Size(
          tokens.sizing.buttonDefault.paddingHorizontal * 2,
          tokens.sizing.buttonDefault.height,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sizing.buttonDefault.paddingHorizontal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
        elevation: 0,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return tokens.accent.primary.pressed;
          }
          if (states.contains(WidgetState.hovered)) {
            return tokens.accent.primary.hover.withOpacity(0.1);
          }
          return null;
        }),
      ),
    ),

    // Text button theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent.primary.value,
        minimumSize: Size(
          tokens.sizing.buttonCompact.paddingHorizontal * 2,
          tokens.sizing.buttonCompact.height,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sizing.buttonCompact.paddingHorizontal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
      ),
    ),

    // Outlined button theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.text.primary,
        minimumSize: Size(
          tokens.sizing.buttonDefault.paddingHorizontal * 2,
          tokens.sizing.buttonDefault.height,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sizing.buttonDefault.paddingHorizontal,
        ),
        side: BorderSide(
          color: tokens.accent.primary.value,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
      ),
    ),

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface.raised,
      contentPadding: EdgeInsets.all(tokens.sizing.inputSlot.padding),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(
          color: tokens.canvas.artboardBorder,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(
          color: tokens.canvas.artboardBorder,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(
          color: tokens.accent.primary.value,
          width: tokens.focus.width,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(
          color: tokens.semantic.error.value,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(
          color: tokens.semantic.error.value,
          width: tokens.focus.width,
        ),
      ),
      labelStyle: tokens.typography.sm.toTextStyle(
        color: tokens.text.secondary,
      ),
      hintStyle: tokens.typography.sm.toTextStyle(
        color: tokens.text.tertiary,
      ),
      errorStyle: tokens.typography.xs.toTextStyle(
        color: tokens.semantic.error.value,
      ),
    ),

    // Icon theme
    iconTheme: IconThemeData(
      color: tokens.text.primary,
      size: tokens.sizing.iconMd,
    ),

    // Tooltip theme
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: tokens.surface.overlay,
        borderRadius: BorderRadius.circular(tokens.radius.sm),
      ),
      textStyle: tokens.typography.xxs.toTextStyle(
        color: tokens.text.primary,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.spacing8,
        vertical: tokens.spacing.spacing4,
      ),
      waitDuration: const Duration(milliseconds: 500),
    ),

    // Divider theme
    dividerTheme: DividerThemeData(
      color: tokens.canvas.artboardBorder,
      thickness: 1,
      space: tokens.spacing.spacing16,
    ),

    // Dialog theme
    dialogTheme: DialogTheme(
      backgroundColor: tokens.surface.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
      ),
      elevation: 0,
      titleTextStyle: tokens.typography.xl.toTextStyle(
        color: tokens.text.primary,
      ),
      contentTextStyle: tokens.typography.md.toTextStyle(
        color: tokens.text.secondary,
      ),
    ),

    // Snackbar theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.surface.raised,
      contentTextStyle: tokens.typography.sm.toTextStyle(
        color: tokens.text.primary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),

    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.accent.primary.value;
        }
        return tokens.text.tertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.accent.primary.value.withOpacity(0.5);
        }
        return tokens.canvas.artboardBorder;
      }),
    ),

    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.accent.primary.value;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(tokens.text.onAccent),
      side: BorderSide(
        color: tokens.canvas.artboardBorder,
        width: 1,
      ),
    ),

    // Radio theme
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.accent.primary.value;
        }
        return tokens.canvas.artboardBorder;
      }),
    ),

    // Slider theme
    sliderTheme: SliderThemeData(
      activeTrackColor: tokens.accent.primary.value,
      inactiveTrackColor: tokens.canvas.artboardBorder,
      thumbColor: tokens.accent.primary.value,
      overlayColor: tokens.accent.primary.value.withOpacity(0.1),
      valueIndicatorColor: tokens.surface.overlay,
      valueIndicatorTextStyle: tokens.typography.xs.toTextStyle(
        color: tokens.text.primary,
      ),
    ),

    // Progress indicator theme
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: tokens.accent.primary.value,
      linearTrackColor: tokens.canvas.artboardBorder,
      circularTrackColor: tokens.canvas.artboardBorder,
    ),

    // Tab bar theme
    tabBarTheme: TabBarTheme(
      labelColor: tokens.accent.primary.value,
      unselectedLabelColor: tokens.text.secondary,
      indicatorColor: tokens.accent.primary.value,
      labelStyle: tokens.typography.sm.toTextStyle(),
      unselectedLabelStyle: tokens.typography.sm.toTextStyle(),
    ),

    // Text theme
    textTheme: TextTheme(
      displayLarge: tokens.typography.xxl.toTextStyle(color: tokens.text.primary),
      displayMedium: tokens.typography.xl.toTextStyle(color: tokens.text.primary),
      displaySmall: tokens.typography.lg.toTextStyle(color: tokens.text.primary),
      headlineLarge: tokens.typography.lg.toTextStyle(color: tokens.text.primary),
      headlineMedium: tokens.typography.md.toTextStyle(color: tokens.text.primary),
      headlineSmall: tokens.typography.sm.toTextStyle(color: tokens.text.primary),
      titleLarge: tokens.typography.lg.toTextStyle(color: tokens.text.primary),
      titleMedium: tokens.typography.md.toTextStyle(color: tokens.text.primary),
      titleSmall: tokens.typography.sm.toTextStyle(color: tokens.text.primary),
      bodyLarge: tokens.typography.md.toTextStyle(color: tokens.text.primary),
      bodyMedium: tokens.typography.sm.toTextStyle(color: tokens.text.primary),
      bodySmall: tokens.typography.xs.toTextStyle(color: tokens.text.secondary),
      labelLarge: tokens.typography.md.toTextStyle(color: tokens.text.primary),
      labelMedium: tokens.typography.sm.toTextStyle(color: tokens.text.primary),
      labelSmall: tokens.typography.xs.toTextStyle(color: tokens.text.secondary),
    ),

    // Add our custom token extension
    extensions: <ThemeExtension<dynamic>>[
      tokens,
    ],
  );
}
