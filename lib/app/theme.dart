import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/ranks.dart';

/// Brand colours not covered by [ColorScheme].
class Brand {
  static const ember = Color(0xFFFF6A3D);
  static const amber = Color(0xFFFFB547);
  static const success = Color(0xFF3DDC84);
  static const emberGradient = LinearGradient(
    colors: [Color(0xFFFF8A3D), Color(0xFFFF4D4D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color tierColor(Tier t) => Color(t.color);
  static Color tierGlow(Tier t) => Color(t.glow);
}

const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Brand.ember,
  onPrimary: Color(0xFF1A0B05),
  primaryContainer: Color(0xFF4A1E0E),
  onPrimaryContainer: Color(0xFFFFD9CC),
  secondary: Brand.amber,
  onSecondary: Color(0xFF2A1A00),
  secondaryContainer: Color(0xFF3D2A08),
  onSecondaryContainer: Color(0xFFFFE1B0),
  tertiary: Brand.success,
  onTertiary: Color(0xFF00210F),
  tertiaryContainer: Color(0xFF0E3B23),
  onTertiaryContainer: Color(0xFFB4F5CF),
  error: Color(0xFFFF5A6E),
  onError: Color(0xFF2D0008),
  surface: Color(0xFF0D0E13),
  onSurface: Color(0xFFF1F2F5),
  onSurfaceVariant: Color(0xFF9AA0AC),
  outline: Color(0xFF3A3F4B),
  outlineVariant: Color(0xFF242832),
  surfaceContainerLowest: Color(0xFF08090C),
  surfaceContainerLow: Color(0xFF121419),
  surfaceContainer: Color(0xFF171920),
  surfaceContainerHigh: Color(0xFF1E2129),
  surfaceContainerHighest: Color(0xFF282C36),
  inverseSurface: Color(0xFFF1F2F5),
  onInverseSurface: Color(0xFF15171C),
  shadow: Colors.black,
);

const _light = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFE5541F),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFFFDBCD),
  onPrimaryContainer: Color(0xFF3A0F00),
  secondary: Color(0xFFB8740A),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFFE3B8),
  onSecondaryContainer: Color(0xFF2A1A00),
  tertiary: Color(0xFF15924F),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFC6F3D8),
  onTertiaryContainer: Color(0xFF00210F),
  error: Color(0xFFD32F45),
  onError: Colors.white,
  surface: Color(0xFFF5F5F7),
  onSurface: Color(0xFF15171C),
  onSurfaceVariant: Color(0xFF5E6470),
  outline: Color(0xFFBFC3CC),
  outlineVariant: Color(0xFFE2E4E9),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFFBFBFC),
  surfaceContainer: Colors.white,
  surfaceContainerHigh: Color(0xFFEEEFF2),
  surfaceContainerHighest: Color(0xFFE5E7EB),
  inverseSurface: Color(0xFF1E2129),
  onInverseSurface: Color(0xFFF1F2F5),
  shadow: Colors.black,
);

ThemeData buildTheme(Brightness brightness) {
  final scheme = brightness == Brightness.dark ? _dark : _light;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  final text = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final radius = BorderRadius.circular(18);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      systemOverlayStyle: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary.withValues(alpha: 0.2),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      showCheckmark: false,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary.withValues(alpha: 0.18),
        selectedForegroundColor: scheme.onSurface,
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}
