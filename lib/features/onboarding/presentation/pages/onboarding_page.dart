import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/theme/app_theme.dart';

const String onboardingSeenPrefKey = 'onboarding_seen';

class _OnboardingSlide {
  final IconData icon;
  final Color bgColor;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String ctaLabel;

  const _OnboardingSlide({
    required this.icon,
    required this.bgColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
  });
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.mosque_rounded,
    bgColor: AppColors.primaryLight,
    accentColor: AppColors.primary,
    title: 'ابدأ رحلتك مع القرآن الكريم 📖',
    subtitle:
        'تعلم الحفظ والتجويد بطريقة ممتعة وتفاعلية تناسب الأطفال من كل الأعمار',
    ctaLabel: 'التالي',
  ),
  _OnboardingSlide(
    icon: Icons.emoji_events_rounded,
    bgColor: AppColors.secondaryBg,
    accentColor: AppColors.secondary,
    title: 'اكسب النقاط والجوائز 🌟',
    subtitle:
        'احفظ سورة جديدة كل يوم وابن عاداتك بطريقة ممتعة. اكسب نجوماً وعملات واكتشف كنوزاً مخفية!',
    ctaLabel: 'التالي',
  ),
  _OnboardingSlide(
    icon: Icons.groups_2_rounded,
    bgColor: AppColors.primaryLight,
    accentColor: AppColors.primary,
    title: 'تواصل مع معلمك وتابع تقدمك 👨‍🏫',
    subtitle:
        'راجع تقييماتك، تواصل مع معلمك مباشرة، وخلّي أهلك يتابعوا رحلتك خطوة بخطوة',
    ctaLabel: 'ابدأ الآن',
  ),
];

class OnboardingPage extends StatefulWidget {
  final ValueNotifier<bool> onboardingSeen;

  const OnboardingPage({super.key, required this.onboardingSeen});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingSeenPrefKey, true);
    // بيحدّث الـ notifier اللي الراوتر بيراقبه عشان الـ redirect
    // يسمح بالخروج من الأونبوردنج فورًا.
    widget.onboardingSeen.value = true;
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    child: const Text(
                      'تخطى',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
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
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      '${_index + 1}/${_slides.length}',
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
                vertical: AppSizes.paddingL,
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
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _slides[_index].accentColor
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _slides[_index].accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _slides[_index].ctaLabel,
                            style: const TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_back_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (_index == 0) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _finish,
                      child: const Text(
                        'أو تسجيل الدخول',
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
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
                color: slide.bgColor,
                borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    top: 24,
                    left: 24,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.amber,
                      size: 22,
                    ),
                  ),
                  const Positioned(
                    top: 40,
                    right: 32,
                    child: Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 26,
                    ),
                  ),
                  const Positioned(
                    bottom: 32,
                    right: 40,
                    child: Icon(
                      Icons.nightlight_round,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: slide.accentColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        slide.icon,
                        size: 72,
                        color: slide.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
