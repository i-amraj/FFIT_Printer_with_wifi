import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FFit Design System — Dark premium theme
/// Inspired by the Android FFit BT app aesthetic
class FFitTheme {
  // ── Color palette ─────────────────────────────────────────────────────────
  static const Color bg          = Color(0xFF0D0F14);   // Deep dark background
  static const Color surface     = Color(0xFF161A23);   // Card surface
  static const Color surfaceAlt  = Color(0xFF1E2330);   // Elevated surface
  static const Color accent      = Color(0xFF4F8EF7);   // Primary blue accent
  static const Color accentGlow  = Color(0x334F8EF7);   // Glow version
  static const Color success     = Color(0xFF2ECC71);
  static const Color successGlow = Color(0x332ECC71);
  static const Color warning     = Color(0xFFE67E22);
  static const Color error       = Color(0xFFE74C3C);
  static const Color errorGlow   = Color(0x33E74C3C);
  static const Color textPrimary = Color(0xFFECF0F1);
  static const Color textSub     = Color(0xFF8A929F);
  static const Color border      = Color(0xFF252C3A);
  static const Color usbColor    = Color(0xFF00B4D8);
  static const Color netColor    = Color(0xFF48CAE4);
  static const Color btColor     = Color(0xFF7B61FF);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF4F8EF7), Color(0xFF7B61FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF0D0F14), Color(0xFF111520)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get theme {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.inter(
        color: textPrimary, fontSize: 28, fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.inter(
        color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.inter(
        color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.inter(
        color: textPrimary, fontSize: 14, fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        color: textSub, fontSize: 13, fontWeight: FontWeight.w400,
      ),
      labelSmall: GoogleFonts.inter(
        color: textSub, fontSize: 11, fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface:   surface,
        primary:   accent,
        secondary: btColor,
        error:     error,
      ),
      textTheme:       textTheme,
      primaryTextTheme: textTheme,
      cardTheme: CardThemeData(
        color:     surface,
        elevation: 0,
        shape:     RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: textSub),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: textSub,
        textColor: textPrimary,
        subtitleTextStyle: TextStyle(color: textSub, fontSize: 12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : textSub,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accentGlow : border,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceAlt,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Reusable decorations ─────────────────────────────────────────────────────

BoxDecoration glowBox({Color color = FFitTheme.accent, double radius = 16}) =>
    BoxDecoration(
      color:        FFitTheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border:       Border.all(color: color.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(
          color:       color.withOpacity(0.12),
          blurRadius:  20,
          spreadRadius: 0,
        ),
      ],
    );

BoxDecoration cardBox({double radius = 16}) => BoxDecoration(
  color:        FFitTheme.surface,
  borderRadius: BorderRadius.circular(radius),
  border:       Border.all(color: FFitTheme.border, width: 1),
);
