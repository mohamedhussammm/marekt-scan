import 'package:flutter/material.dart';

class AppColors {
  // ── Luminous Retail Palette ──────────────────────────────────────────────

  // Primary — Deep Teal / Electric Cyan
  static const Color primary = Color(0xFF00677E);
  static const Color primaryLight = Color(0xFF3CD7FF);
  static const Color primaryDark = Color(0xFF004E5F);
  static const Color primaryContainer = Color(0xFFB4EBFF);

  // Secondary
  static const Color secondary = Color(0xFF545F73);
  static const Color secondaryLight = Color(0xFF8B96AA);
  static const Color secondaryContainer = Color(0xFFD5E0F8);

  // Surfaces — Crystal White / Frosted Glass layers
  static const Color background = Color(0xFFF6F9FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFDDE3EB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEEF4FC);
  static const Color surfaceContainer = Color(0xFFE8EEF6);
  static const Color surfaceContainerHigh = Color(0xFFE3E9F1);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Glass card color — semi-transparent white for frosted panels
  static const Color glassCard = Color(0xF0FFFFFF); // 94% white
  static const Color glassBorder = Color(0x50BBC9CF); // silver at 31% opacity

  // Status Colors
  static const Color success = Color(0xFF1A7A4A);
  static const Color error = Color(0xFFBA1A1A);
  static const Color warning = Color(0xFFB06000);
  static const Color info = Color(0xFF006494);

  // Text
  static const Color textPrimary = Color(0xFF161C22);
  static const Color textSecondary = Color(0xFF3C494E);
  static const Color textHint = Color(0xFF6C797F);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFBBC9CF);
  static const Color divider = Color(0x30BBC9CF); // silver at 19% opacity

  // Chart colors — cyan-based palette
  static const Color chart1 = Color(0xFF00677E);
  static const Color chart2 = Color(0xFF3CD7FF);
  static const Color chart3 = Color(0xFF00B4D8);
  static const Color chart4 = Color(0xFF545F73);
  static const Color chart5 = Color(0xFF5A5F62);

  // Low stock severity
  static const Color criticalStock = Color(0xFFBA1A1A);
  static const Color lowStock = Color(0xFFB06000);
  static const Color goodStock = Color(0xFF1A7A4A);

  // Glow / Accent tint for active states
  static const Color accentGlow = Color(0xFF3CD7FF);
  static const Color accentGlowFaded = Color(0x203CD7FF); // 12% opacity
}
