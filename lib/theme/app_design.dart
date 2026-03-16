import 'package:flutter/material.dart';

/// Design System for Private Local AI
///
/// A premium, WCAG 2.1 AA compliant dark theme with carefully
/// curated colors, typography, and spacing.
class AppDesign {
  AppDesign._();

  // ─── Color Palette ───
  // Primary: Electric Teal — trust, technology, intelligence
  static const Color primary = Color(0xFF00D9A6);
  static const Color primaryDark = Color(0xFF00B88C);
  static const Color primaryLight = Color(0xFF33E3BA);

  // Surface colors — layered dark with subtle depth
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF1C2333);
  static const Color surfaceHighlight = Color(0xFF242D3D);

  // Text — high contrast for readability (WCAG AA)
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textTertiary = Color(0xFF6E7681);

  // Accents
  static const Color accent = Color(0xFF58A6FF);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D9A6), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF161B22), Color(0xFF1C2333)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Spacing ───
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ─── Border Radius ───
  static final BorderRadius radiusSm = BorderRadius.circular(8);
  static final BorderRadius radiusMd = BorderRadius.circular(12);
  static final BorderRadius radiusLg = BorderRadius.circular(16);
  static final BorderRadius radiusXl = BorderRadius.circular(24);

  // ─── Shadows ───
  static List<BoxShadow> get elevationLow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevationMed => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── ThemeData ───
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: surface,
      error: error,
      onPrimary: Color(0xFF0D1117),
      onSecondary: textPrimary,
      onSurface: textPrimary,
      onError: textPrimary,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: textSecondary),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: surface),
    cardTheme: CardThemeData(
      color: surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radiusMd),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: radiusLg),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHighlight,
      border: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide(color: surfaceHighlight, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF21262D),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: surfaceHighlight,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceElevated,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: radiusMd),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: radiusMd),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}

/// Reusable UI Components
class AppComponents {
  AppComponents._();

  /// Status chip for model/connection state
  static Widget statusChip({
    required String label,
    required IconData icon,
    Color? color,
  }) {
    final c = color ?? AppDesign.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: AppDesign.radiusXl,
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  /// Section header for lists
  static Widget sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppDesign.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Empty state placeholder
  static Widget emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesign.surfaceHighlight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppDesign.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppDesign.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppDesign.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }
}
