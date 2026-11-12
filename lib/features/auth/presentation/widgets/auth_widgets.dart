import 'package:flutter/material.dart';

import '../../../../core/constants/academy_branding.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/academy_login_identifier.dart';

/// Rounded primary-colour backdrop shared by the Auth pages.
class AuthHeaderBackdrop extends StatelessWidget {
  const AuthHeaderBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.36,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
      ),
    );
  }
}

/// Academy mark + page title on the backdrop.
class AuthBrandHeader extends StatelessWidget {
  final String title;

  /// Task icon (password pages); null shows the academy logo.
  final IconData? icon;

  const AuthBrandHeader({super.key, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Row(
      children: [
        if (icon == null)
          const AcademyLogo(size: 52)
        else
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AcademyBranding.displayName,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The academy logo tile; same artwork as the launcher icon and native splash.
class AcademyLogo extends StatelessWidget {
  final double size;

  const AcademyLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AcademyBranding.logoAsset,
      key: const Key('academy-logo'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: AcademyBranding.displayName,
      errorBuilder: (_, __, ___) => Icon(
        Icons.menu_book_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  final String text;

  const AuthFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppTextStyles.labelLarge,
    );
  }
}

enum AuthBannerTone { error, info, success }

/// Inline, persistent Auth message (errors that must survive a rebuild,
/// e.g. a forced sign-out reason).
class AuthMessageBanner extends StatelessWidget {
  final String message;
  final AuthBannerTone tone;

  const AuthMessageBanner({
    super.key,
    required this.message,
    this.tone = AuthBannerTone.error,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      AuthBannerTone.error => (AppColors.error, Icons.error_outline_rounded),
      AuthBannerTone.info => (AppColors.primary, Icons.info_outline_rounded),
      AuthBannerTone.success => (
        AppColors.success,
        Icons.check_circle_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMedium.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class AuthValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'أدخل البريد الإلكتروني';
    if (!_email.hasMatch(v)) return 'البريد الإلكتروني غير صالح';
    return null;
  }

  static String? loginIdentifier(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'أدخل اسم المستخدم أو البريد الإلكتروني';
    if (AcademyLoginIdentifier.toAuthEmail(v) == null) {
      return 'اسم المستخدم أو البريد الإلكتروني غير صالح';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'أدخل كلمة المرور';
    if (value.length < 6) return 'كلمة المرور قصيرة جداً';
    return null;
  }
}
