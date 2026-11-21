import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';

const String onboardingSeenPrefKey = 'onboarding_seen';

class _OnboardingSlide {
  final IconData icon;
  final Color canvasColor;
  final Color accentColor;
  final Color accentDeep;
  final String titleLead;
  final String titleAccent;
  final String subtitle;
  final String ctaLabel;

  const _OnboardingSlide({
    required this.icon,
    required this.canvasColor,
    required this.accentColor,
    required this.accentDeep,
    required this.titleLead,
    required this.titleAccent,
    required this.subtitle,
    required this.ctaLabel,
  });

  Gradient get buttonGradient => LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [accentDeep, accentColor],
      );
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.menu_book_rounded,
    canvasColor: AppColors.primaryLight,
    accentColor: AppColors.primaryGradientMid,
    accentDeep: AppColors.primaryGradientStart,
    titleLead: 'ابدأ رحلتك مع ',
    titleAccent: 'أكاديمية بصمة',
    subtitle:
        'إدارة الحلقات والطلاب وأولياء الأمور في مكان واحد بطريقة واضحة ومنظّمة',
    ctaLabel: 'التالي',
  ),
  _OnboardingSlide(
    icon: Icons.emoji_events_rounded,
    canvasColor: AppColors.secondaryBg,
    accentColor: AppColors.secondary,
    accentDeep: AppColors.secondaryDeep,
    titleLead: 'تابع ',
    titleAccent: 'التقدم والجوائز',
    subtitle:
        'حضور، تقييمات، ونقاط — كل دور يرى ما يخصه بوضوح ويدعم استمرار التعلم',
    ctaLabel: 'التالي',
  ),
  _OnboardingSlide(
    icon: Icons.groups_2_rounded,
    canvasColor: AppColors.primaryLight,
    accentColor: AppColors.primaryGradientMid,
    accentDeep: AppColors.primaryGradientStart,
    titleLead: 'تواصل ومتابعة ',
    titleAccent: 'أولياء الأمور',
    subtitle:
        'رسائل، جداول، واشتراكات — رحلة مترابطة بين الطالب والمعلم وولي الأمر',
    ctaLabel: 'تسجيل الدخول',
  ),
];

class OnboardingPage extends StatefulWidget {
  final ValueNotifier<bool> onboardingSeen;

  const OnboardingPage({super.key, required this.onboardingSeen});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  // LTR PageView so "next" animates toward the left (الشمال) in Arabic UI.
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingSeenPrefKey, true);
    widget.onboardingSeen.value = true;
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
                vertical: AppSizes.paddingM,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'تخطى',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: slide.canvasColor,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      '${_index + 1}/${_slides.length}',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: slide.accentDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: _SlideView(slide: _slides[i]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.paddingL,
                8,
                AppSizes.paddingL,
                AppSizes.paddingL,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final isActive = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? slide.accentColor
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  AppButton(
                    label: slide.ctaLabel,
                    onPressed: _next,
                    gradient: slide.buttonGradient,
                    leading: const AppForwardIcon(
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  if (_index == 0) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'أو تسجيل الدخول',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: slide.canvasColor,
                borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              ),
              child: Center(
                child: _ModernHeroCard(
                  accent: slide.accentColor,
                  accentDeep: slide.accentDeep,
                  icon: slide.icon,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text.rich(
            TextSpan(
              style: AppTextStyles.headlineMedium.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
              children: [
                TextSpan(text: slide.titleLead),
                TextSpan(
                  text: slide.titleAccent,
                  style: TextStyle(color: slide.accentDeep),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.65,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Soft modern illustration card — no decorative stars/crescents.
class _ModernHeroCard extends StatelessWidget {
  final Color accent;
  final Color accentDeep;
  final IconData icon;

  const _ModernHeroCard({
    required this.accent,
    required this.accentDeep,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 168,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 112,
          height: 132,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: accentDeep.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                margin: const EdgeInsets.only(left: 24),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentDeep, accent],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
