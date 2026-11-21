import 'package:flutter/material.dart';

/// Mushaf-local visual tokens (Paper / Night / Emerald / Sepia).
/// Reader-scoped — not app ThemeMode.
class MushafReaderTokens {
  const MushafReaderTokens._({
    required this.isNight,
    required this.canvas,
    required this.ink,
    required this.inkMuted,
    required this.chrome,
    required this.chromeInk,
    required this.chromeMuted,
    required this.selection,
    required this.ayahMarker,
    required this.divider,
    required this.accent,
    required this.onAccent,
    required this.error,
  });

  final bool isNight;
  final Color canvas;
  final Color ink;
  final Color inkMuted;
  final Color chrome;
  final Color chromeInk;
  final Color chromeMuted;
  final Color selection;
  final Color ayahMarker;
  final Color divider;
  final Color accent;

  /// Foreground on [accent] fills (e.g. the play button).
  final Color onAccent;

  /// Quiet error text / icons — not an alarm red.
  final Color error;

  /// Default calm daytime reading surface.
  static const paper = MushafReaderTokens._(
    isNight: false,
    canvas: Color(0xFFF4EFE3),
    ink: Color(0xFF1C1A17),
    inkMuted: Color(0xFF6B655C),
    chrome: Color(0xFFF8F4EA),
    chromeInk: Color(0xFF2A2620),
    chromeMuted: Color(0xFF8A8478),
    selection: Color(0x3320A090),
    ayahMarker: Color(0xFF1F7A6E),
    divider: Color(0x332D6B4F),
    accent: Color(0xFF1F8F83),
    onAccent: Color(0xFFFFFFFF),
    error: Color(0xFFB0473C),
  );

  /// Low-glare night reading — not global dark theme.
  static const night = MushafReaderTokens._(
    isNight: true,
    canvas: Color(0xFF17191C),
    ink: Color(0xFFE6E2D8),
    inkMuted: Color(0xFF9A958C),
    chrome: Color(0xFF1F2328),
    chromeInk: Color(0xFFE8E4DA),
    chromeMuted: Color(0xFF8E8880),
    selection: Color(0x4020A090),
    ayahMarker: Color(0xFF5CB8AC),
    divider: Color(0x33FFFFFF),
    accent: Color(0xFF3DB8A8),
    onAccent: Color(0xFF10201E),
    error: Color(0xFFE39A8F),
  );

  /// Soft teal-tinted daytime page — easy on the eyes.
  static const emerald = MushafReaderTokens._(
    isNight: false,
    canvas: Color(0xFFEEF6F4),
    ink: Color(0xFF1A2422),
    inkMuted: Color(0xFF5C6B66),
    chrome: Color(0xFFF2F9F7),
    chromeInk: Color(0xFF24302D),
    chromeMuted: Color(0xFF7A8A84),
    selection: Color(0x3328A89A),
    ayahMarker: Color(0xFF1A8A7D),
    divider: Color(0x332A6B5C),
    accent: Color(0xFF28A89A),
    onAccent: Color(0xFFFFFFFF),
    error: Color(0xFFB0473C),
  );

  /// Warm sepia tones — vintage book feel.
  static const sepia = MushafReaderTokens._(
    isNight: false,
    canvas: Color(0xFFEDE4D4),
    ink: Color(0xFF2C2218),
    inkMuted: Color(0xFF7A6B5A),
    chrome: Color(0xFFF3EBDD),
    chromeInk: Color(0xFF3A2E22),
    chromeMuted: Color(0xFF9A8876),
    selection: Color(0x33B8860B),
    ayahMarker: Color(0xFF8B6914),
    divider: Color(0x338B7355),
    accent: Color(0xFFC49A3C),
    onAccent: Color(0xFF2C2218),
    error: Color(0xFFB0473C),
  );

  static const Set<String> styleIds = {'paper', 'night', 'emerald', 'sepia'};

  static MushafReaderTokens of({required bool isNight}) =>
      isNight ? night : paper;

  static MushafReaderTokens styleOf(String id) {
    switch (id) {
      case 'night':
        return night;
      case 'emerald':
        return emerald;
      case 'sepia':
        return sepia;
      case 'paper':
      default:
        return paper;
    }
  }

  /// Responsive horizontal page margin.
  static double horizontalMargin(double width) {
    if (width < 360) return 16;
    if (width < 600) return 22;
    return 40;
  }

  /// Vertical page padding.
  static double verticalPadding(double width) {
    if (width < 360) return 12;
    if (width < 600) return 18;
    return 22;
  }

  /// Cap readable measure on wide screens.
  static double maxTextWidth(double width) {
    if (width >= 720) return 600;
    return width;
  }

  TextStyle bodyStyle({
    required double fontSize,
    double lineHeight = 1.45,
  }) {
    return TextStyle(
      fontFamily: 'Amiri',
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: 0,
      color: ink,
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle basmalaStyle({required double fontSize}) {
    return TextStyle(
      fontFamily: 'Amiri',
      fontSize: fontSize,
      height: 1.6,
      color: ink,
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle surahTitleStyle() {
    return TextStyle(
      fontFamily: 'Amiri',
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: ink,
    );
  }

  TextStyle surahMetaStyle() {
    return TextStyle(
      fontFamily: 'Amiri',
      fontSize: 13,
      height: 1.4,
      color: inkMuted,
    );
  }

  TextStyle chromeLabelStyle({double size = 14, FontWeight? weight}) {
    return TextStyle(
      fontFamily: 'NotoNaskhArabic',
      fontSize: size,
      fontWeight: weight ?? FontWeight.w600,
      color: chromeInk,
      height: 1.3,
    );
  }

  TextStyle pageNumberStyle() {
    return TextStyle(
      fontFamily: 'Amiri',
      fontSize: 13,
      color: inkMuted,
      height: 1.2,
    );
  }

  static String arabicDigits(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}

/// Local prefs key for reader-only Paper/Night (not app ThemeMode).
const kMushafNightModePrefsKey = 'mushaf_reader_night_mode';

/// Reader color theme: paper | night | emerald | sepia.
const kMushafStylePrefsKey = 'mushaf_reader_style';

/// Reader ayah line height multiplier (typically 1.25–1.9).
const kMushafLineHeightPrefsKey = 'mushaf_reader_line_height';