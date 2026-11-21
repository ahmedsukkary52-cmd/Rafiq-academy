import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../shared/theme/app_theme.dart';

/// Student home header — RTL: avatar+name on the right, search+notifications left.
class StudentHeaderWidget extends StatelessWidget {
  final String name;
  final String avatarEmoji;
  final int coins;
  final int totalStars;
  final int streakDays;
  final VoidCallback onNotificationsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback onAvatarTap;
  final VoidCallback? onCoinsTap;
  final VoidCallback? onStarsTap;
  final VoidCallback? onStreakTap;
  final int unreadNotificationsCount;

  /// False while `streakDays` has no writer, so no fabricated count is shown.
  final bool showStreak;

  const StudentHeaderWidget({
    super.key,
    required this.name,
    required this.avatarEmoji,
    required this.coins,
    required this.totalStars,
    required this.streakDays,
    required this.onNotificationsTap,
    this.onSearchTap,
    required this.onAvatarTap,
    this.onCoinsTap,
    this.onStarsTap,
    this.onStreakTap,
    this.unreadNotificationsCount = 0,
    this.showStreak = true,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          bottom: 20,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // RIGHT (first in RTL): avatar + name
                Expanded(
                  child: GestureDetector(
                    onTap: onAvatarTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              avatarEmoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name 👋',
                                key: const Key('student-header-name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _hijriToday(),
                                key: const Key('student-header-hijri'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // LEFT: search + notifications
                if (onSearchTap != null) ...[
                  _HeaderCircleButton(
                    icon: Icons.search_rounded,
                    onTap: onSearchTap!,
                  ),
                  const SizedBox(width: 8),
                ],
                _HeaderCircleButton(
                  icon: Icons.notifications_outlined,
                  showDot: unreadNotificationsCount > 0,
                  onTap: onNotificationsTap,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    icon: Icons.monetization_on_rounded,
                    iconColor: const Color(0xFFFFD54F),
                    value: _eastern('$coins'),
                    label: 'عملة',
                    onTap: onCoinsTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFFD54F),
                    value: _eastern('$totalStars'),
                    label: 'نجمة',
                    onTap: onStarsTap,
                  ),
                ),
                if (showStreak) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFFF8A65),
                      value: _eastern('$streakDays'),
                      label: 'يوم متواصل',
                      onTap: onStreakTap,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _hijriToday() {
    HijriCalendar.setLocal('ar');
    final h = HijriCalendar.now();
    const weekdays = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final weekday = weekdays[DateTime.now().weekday - 1];
    return '$weekday ${_eastern(h.toFormat('dd MMMM'))}';
  }

  String _eastern(String input) {
    const western = '0123456789';
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    return input.split('').map((c) {
      final i = western.indexOf(c);
      return i >= 0 ? eastern[i] : c;
    }).join();
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderCircleButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (showDot)
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDark, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 18,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
