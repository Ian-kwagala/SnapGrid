import 'package:flutter/material.dart';

/// Visual theme constants for SnapGrid's "Cozy Neon Arcade" look.
///
/// All colors match the design specs from the SnapGrid blueprint so the board
/// stays easy on the eyes during dark or night play sessions.
class SnapGridColors {
  SnapGridColors._();

  /// Deep Midnight Navy app background.
  static const Color background = Color(0xFF121629);

  /// Elevated card / panel surface behind HUD and tray.
  static const Color surface = Color(0xFF181E38);

  /// 8x8 board cell fill color.
  static const Color boardCell = Color(0xFF1E2542);

  /// 8x8 board grid border / cell line color.
  static const Color boardLine = Color(0xFF2A3359);

  /// Outer frame behind the 8x8 grid.
  static const Color boardFrame = Color(0xFF161B33);

  /// White/Gold glow used to preview rows or columns about to clear.
  static const Color lineClearGlow = Color(0xFFFFE082);
  static const Color lineClearBorder = Color(0xFFFFF8E1);

  /// Jewel-toned block palette.
  static const Color coral = Color(0xFFFF6B6B);
  static const Color sky = Color(0xFF38BDF8);
  static const Color mint = Color(0xFF34D399);
  static const Color amber = Color(0xFFFBBF24);
  static const Color violet = Color(0xFFA78BFA);

  /// UI text and accent colors.
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color validGhost = Color(0x55FFFFFF);
  static const Color invalidGhost = Color(0x44EF4444);
  static const Color bombGlow = Color(0xFFFF8A65);
}

/// Shared ThemeData for SnapGrid: Block Puzzle.
ThemeData buildSnapGridTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SnapGridColors.background,
    colorScheme: const ColorScheme.dark(
      surface: SnapGridColors.surface,
      primary: SnapGridColors.sky,
      secondary: SnapGridColors.amber,
      error: SnapGridColors.coral,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
  );
}
