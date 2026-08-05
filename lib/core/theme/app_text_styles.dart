import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography tokens extracted directly from the Stitch design export.
/// Font: Sora, 2 weights only (400 regular, 600 semibold) — matches
/// design.md §3's "2 weights max per screen" rule.
///
/// Usage: Text('Hello', style: AppTextStyles.headlineMd)
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get headlineLg => GoogleFonts.sora(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLgMobile => GoogleFonts.sora(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.sora(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.sora(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get bodySm => GoogleFonts.sora(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
      );

  /// All-caps label style — used for section headers, status badge text,
  /// category chip labels.
  static TextStyle get labelCaps => GoogleFonts.sora(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6, // 0.05em at 12px
        color: AppColors.onSurfaceVariant,
      );
}
