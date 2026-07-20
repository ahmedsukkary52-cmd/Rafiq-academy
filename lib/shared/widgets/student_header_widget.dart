import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

class StudentHeaderWidget extends StatelessWidget {
  final String name;
  final String avatarEmoji;
  final int coins;
  final int totalStars;
  final int streakDays;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAvatarTap;
  final VoidCallback? onCoinsTap;
  final VoidCallback? onStarsTap;
  final VoidCallback? onStreakTap;
  final int unreadNotificationsCount;

  const StudentHeaderWidget({
    super.key,
    required this.name,
    required this.avatarEmoji,
    required this.coins,
    required this.totalStars,
    required this.streakDays,
    required this.onNotificationsTap,
    required this.onSearchTap,
    required this.onAvatarTap,
    this.onCoinsTap,
    this.onStarsTap,
    this.onStreakTap,
    this.unreadNotificationsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.radiusXL),
          bottomRight: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: AppSizes.paddingM,
        right: AppSizes.paddingM,
        bottom: AppSizes.paddingL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── مجموعة الأيقونات (إشعارات + بحث) ─────────────────
              Row(
                children: [
                  _HeaderIconButton(
                    icon: Icons.notifications_outlined,
                    badgeCount: unreadNotificationsCount,
                    onTap: onNotificationsTap,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.search_rounded,
                    onTap: onSearchTap,
                  ),
                ],
              ),

              // ── الاسم + الأفاتار ──────────────────────────────────
              GestureDetector(
                onTap: onAvatarTap,
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '👋 $name',
                          style: const TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formattedToday(),
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          avatarEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── صف الإحصائيات (عملات / نجوم / سلسلة) ─────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '$coins',
                  label: 'عملة',
                  icon: '🌙',
                  backgroundColor: AppColors.dark,
                  onTap: onCoinsTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: '$totalStars',
                  label: 'نجمة',
                  icon: '⭐',
                  backgroundColor: Colors.white.withOpacity(0.16),
                  onTap: onStarsTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: '$streakDays يوم',
                  label: 'متواصل',
                  icon: '🔥',
                  backgroundColor: Colors.white.withOpacity(0.16),
                  onTap: onStreakTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formattedToday() {
    const weekdays = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final now = DateTime.now();
    return weekdays[now.weekday - 1];
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 10,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
