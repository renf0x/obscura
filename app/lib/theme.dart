import 'package:flutter/material.dart';

/// Night-vision palette from the design mockup: near-black greens with a mint signal colour.
abstract final class Palette {
  static const bg = Color(0xFF060A09);
  static const surface = Color(0xFF0C1311);
  static const surfaceHigh = Color(0xFF111B18);
  static const border = Color(0xFF1C2B26);
  static const accent = Color(0xFF34E3A4);
  static const accentDim = Color(0xFF1B7A5A);
  static const text = Color(0xFFE4F1EC);
  static const muted = Color(0xFF8BA39C); // 7:1 on bg, still readable at small sizes
  static const danger = Color(0xFFFF5A5A);
  static const warning = Color(0xFFFFB547);
}

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.accent,
    onPrimary: Color(0xFF00150D),
    secondary: Palette.accentDim,
    surface: Palette.surface,
    onSurface: Palette.text,
    error: Palette.danger,
    outline: Palette.border,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final text = base.textTheme.apply(bodyColor: Palette.text, displayColor: Palette.text);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: const BorderSide(color: Palette.border),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Palette.bg,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.2),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w500),
      bodySmall: text.bodySmall?.copyWith(color: Palette.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(color: Palette.surface, shape: rounded, margin: EdgeInsets.zero, elevation: 0),
    dividerTheme: const DividerThemeData(color: Palette.border, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.surface,
      indicatorColor: Palette.accent.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontSize: 12, color: s.contains(WidgetState.selected) ? Palette.accent : Palette.muted),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Palette.accent : Palette.muted),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surfaceHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.border)),
      // Visible focus ring: brighter, thicker border.
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.accent, width: 2)),
      labelStyle: const TextStyle(color: Palette.muted),
      hintStyle: const TextStyle(color: Palette.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: Palette.accent,
        side: const BorderSide(color: Palette.accentDim),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.bg : Palette.muted),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.accent : Palette.surfaceHigh,
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Palette.accent, minVerticalPadding: 12),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Palette.surfaceHigh,
        contentTextStyle: TextStyle(color: Palette.text)),
  );
}
