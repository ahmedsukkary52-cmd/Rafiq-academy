import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان التطبيق الأساسية
class AppColors {
  const AppColors._();

  // Primary - أخضر إسلامي
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF0A3D0A);

  // Secondary - ذهبي
  static const Color secondary = Color(0xFFB8860B);
  static const Color secondaryLight = Color(0xFFFFD700);

  // Background
  static const Color background = Color(0xFFF5F5F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF2EE);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFFAAAAAA);

  // Status
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF01579B);

  // Grades
  static const Color gradeExcellent = Color(0xFF2E7D32);
  static const Color gradeVeryGood = Color(0xFF1565C0);
  static const Color gradeGood = Color(0xFFF57F17);
  static const Color gradeNeedsRetry = Color(0xFFC62828);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: _buildAppBarTheme(),
      cardTheme: _buildCardTheme(),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      bottomNavigationBarTheme: _buildBottomNavTheme(),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    // Noto Naskh Arabic أفضل خط للقرآن والعربية
    final arabicTextTheme = GoogleFonts.notoNaskhArabicTextTheme(base);
    return arabicTextTheme.copyWith(
      headlineLarge: arabicTextTheme.headlineLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 28,
      ),
      headlineMedium: arabicTextTheme.headlineMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 22,
      ),
      titleLarge: arabicTextTheme.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleMedium: arabicTextTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      bodyLarge: arabicTextTheme.bodyLarge?.copyWith(
        color: AppColors.textPrimary,
        fontSize: 15,
        height: 1.7, // مسافة بين الأسطر مناسبة للعربي
      ),
      bodyMedium: arabicTextTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
        fontSize: 13,
        height: 1.6,
      ),
      labelLarge: arabicTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme() {
    return const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static CardThemeData _buildCardTheme() {
    return CardThemeData(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textHint),
    );
  }

  static BottomNavigationBarThemeData _buildBottomNavTheme() {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    );
  }
}
