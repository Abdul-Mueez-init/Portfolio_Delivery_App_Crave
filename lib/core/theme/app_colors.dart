import 'package:flutter/material.dart';

/// Color tokens extracted directly from the Stitch design export
/// (stitch_crave_mobile_design_system/crave/DESIGN.md).
/// Do not hardcode hex values anywhere else in the app — always reference
/// these constants, so a future palette change only happens in one place.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFAE3115);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFF6B4A);
  static const Color onPrimaryContainer = Color(0xFF661000);
  static const Color inversePrimary = Color(0xFFFFB4A3);

  // Secondary
  static const Color secondary = Color(0xFF5E5E63);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE0DFE4);
  static const Color onSecondaryContainer = Color(0xFF626267);

  // Tertiary (used sparingly — e.g. accent highlights, not core flows)
  static const Color tertiary = Color(0xFF006A69);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF00ACAB);
  static const Color onTertiaryContainer = Color(0xFF003939);

  // Surfaces
  static const Color background = Color(0xFFFFF8F6);
  static const Color onBackground = Color(0xFF261815);
  static const Color surface = Color(0xFFFFF8F6);
  static const Color onSurface = Color(0xFF261815);
  static const Color surfaceVariant = Color(0xFFF6DDD8);
  static const Color onSurfaceVariant = Color(0xFF59413C);
  static const Color surfaceDim = Color(0xFFEDD5CF);
  static const Color surfaceBright = Color(0xFFFFF8F6);

  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFFF0ED);
  static const Color surfaceContainer = Color(0xFFFFE9E5);
  static const Color surfaceContainerHigh = Color(0xFFFCE3DD);
  static const Color surfaceContainerHighest = Color(0xFFF6DDD8);

  static const Color inverseSurface = Color(0xFF3C2D29);
  static const Color inverseOnSurface = Color(0xFFFFEDE9);

  // Outline / borders / dividers
  static const Color outline = Color(0xFF8D716A);
  static const Color outlineVariant = Color(0xFFE1BFB8);

  // Status — these map directly to order/booking status badges (ERD enums)
  static const Color success = Color(0xFF3C9D6B); // confirmed / completed
  static const Color warning =
      Color(0xFFE8A33D); // placed / pending / preparing
  static const Color error = Color(0xFFD65A4A); // cancelled
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
}
