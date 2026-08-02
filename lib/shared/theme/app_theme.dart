import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// الألوان المستخرجة مباشرة من التصميم
class AppColors {
  AppColors._();

  // Primary — الفيروزي/التيل الظاهر في الـ header وأزرار الـ CTA
  static const Color primary = Color(0xFF2DC4B2);
  static const Color primaryDark = Color(0xFF1FA99A);
  static const Color primaryLight = Color(0xFFE8F9F7);

  /// Header / CTA gradient stops (additive tokens; does not replace [primary]).
  static const Color primaryGradientStart = Color(0xFF0A8A94);
  static const Color primaryGradientMid = Color(0xFF19C6D1);
  static const Color primaryGradientEnd = Color(0xFF1BD8E5);

  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
    colors: [primaryGradientStart, primaryGradientMid, primaryGradientEnd],
  );

  /// Soft overlays drawn on primary / gradient headers.
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryOverlay = Color(0x38FFFFFF); // ~22% white
  static const Color onPrimaryMuted = Color(0xE0FFFFFF); // ~88% white

  // Secondary — الذهبي للنقاط والـ streak والأيقونات المميزة
  static const Color secondary = Color(0xFFF5A623);
  static const Color secondaryDeep = Color(0xFFE8910F);
  static const Color secondaryBg = Color(0xFFFFF8EC);

  /// Admin announcement banner (Figma 1:432).
  static const Gradient announcementGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [secondary, secondaryDeep],
  );

  // Dark — خلفية كروت الجلسة والليلية
  static const Color dark = Color(0xFF1C1C2E);
  static const Color darkCard = Color(0xFF2A2A3E);

  // Neutrals
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGrey = Color(0xFFF0F1F6);
  static const Color border = Color(0xFFE8E9F0);
  static const Color softShadow = Color(0x0A000000);

  // Soft icon chip backgrounds (stats / badges)
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color messagesBg = Color(0xFFF3E5F5);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8A8FA8);
  static const Color textHint = Color(0xFFB0B5C8);

  // Grade Colors — من التصميم بالضبط
  static const Color gradeExcellent = Color(0xFF2DC4B2); // ممتاز — تيل
  static const Color gradeVeryGood = Color(0xFF4CAF50); // جيد جداً — أخضر
  static const Color gradeGood = Color(0xFFF5A623); // جيد — ذهبي
  static const Color gradeNeedsWork = Color(0xFFFF5252); // يحتاج تحسين — أحمر

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF2196F3);

  // Calendar Event Types
  static const Color eventSession = Color(0xFF2DC4B2);
  static const Color eventExam = Color(0xFFF5A623);
  static const Color eventHoliday = Color(0xFFFF5252);
  static const Color eventOccasion = Color(0xFF4CAF50);

  // Award Types
  static const Color awardCompletion = Color(0xFF4CAF50);
  static const Color awardPerformance = Color(0xFFF5A623);
  static const Color awardAttendance = Color(0xFF2DC4B2);
  static const Color awardWeekly = Color(0xFF9C27B0);
}

/// أبعاد ثابتة مستخرجة من التصميم
class AppSizes {
  AppSizes._();

  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 100.0;

  // Padding
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // Icon
  static const double iconS = 16.0;
  static const double iconM = 20.0;
  static const double iconL = 24.0;
  static const double iconXL = 32.0;

  // Avatar
  static const double avatarS = 32.0;
  static const double avatarM = 44.0;
  static const double avatarL = 64.0;
  static const double avatarXL = 96.0;

  // Bottom Nav
  static const double bottomNavHeight = 64.0;

  // Header (Teal section)
  static const double headerMinHeight = 200.0;
}

/// Text Styles — Cairo (global app typography via Theme + these helpers)
class AppTextStyles {
  AppTextStyles._();

  static String get fontFamily => GoogleFonts.cairo().fontFamily!;

  static TextStyle get displayLarge => GoogleFonts.cairo(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static TextStyle get displayMedium => GoogleFonts.cairo(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static TextStyle get headlineLarge => GoogleFonts.cairo(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle get headlineMedium => GoogleFonts.cairo(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle get titleLarge => GoogleFonts.cairo(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get titleMedium => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyLarge => GoogleFonts.cairo(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static TextStyle get bodyMedium => GoogleFonts.cairo(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static TextStyle get labelLarge => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  static TextStyle get labelMedium => GoogleFonts.cairo(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get labelSmall => GoogleFonts.cairo(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );
}

/// Theme كامل للتطبيق
class AppTheme {
  AppTheme._();

  static TextTheme _cairoTextTheme(TextTheme base) =>
      GoogleFonts.cairoTextTheme(base);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = _cairoTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: _cairoTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.headlineMedium.copyWith(
          color: AppColors.onPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          textStyle: AppTextStyles.titleLarge.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: 14,
        ),
        hintStyle: AppTextStyles.bodyMedium,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        unselectedLabelStyle: AppTextStyles.labelSmall,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceGrey,
        selectedColor: AppColors.primaryLight,
        labelStyle: AppTextStyles.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  /// نسخة الوضع الليلي - نفس هيكل [theme] بس بألوان غامقة،
  /// مع الحفاظ على التيل/الذهبي كألوان مميزة زي النهارية.
  static ThemeData get darkTheme {
    const darkBackground = Color(0xFF12121C);
    const darkSurface = AppColors.darkCard;
    const darkBorder = Color(0xFF3A3A50);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: darkSurface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: darkBackground,
    );

    return base.copyWith(
      textTheme: _cairoTextTheme(base.textTheme),
      primaryTextTheme: _cairoTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.headlineMedium.copyWith(
          color: AppColors.onPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          textStyle: AppTextStyles.titleLarge.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: 14,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.onPrimary.withValues(alpha: 0.38),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onPrimary.withValues(alpha: 0.54),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        unselectedLabelStyle: AppTextStyles.labelSmall.copyWith(
          color: AppColors.onPrimary.withValues(alpha: 0.54),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: AppColors.primary.withValues(alpha: 0.25),
        labelStyle: AppTextStyles.labelMedium.copyWith(
          color: AppColors.onPrimary.withValues(alpha: 0.7),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
