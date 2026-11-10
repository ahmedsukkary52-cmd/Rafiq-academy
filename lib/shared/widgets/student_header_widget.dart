import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../shared/theme/app_theme.dart';

/// Student home header — Figma: teal header, avatar, Hijri date, soft icon chips, stats row.
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
    return Container(
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
              _HeaderCircleButton(
                icon: Icons.notifications_outlined,
                showDot: unreadNotificationsCount > 0,
                onTap: onNotificationsTap,
              ),
              if (onSearchTap != null) ...[
                const SizedBox(width: 8),
                _HeaderCircleButton(
                  icon: Icons.search_rounded,
                  onTap: onSearchTap!,
                ),
              ],
              // Audit fix: Spacer+Expanded split the row and pushed the avatar
              // group off the header edge; Expanded alone + end alignment keeps it pinned.
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                onTap: onAvatarTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$name 👋',
                          key: const Key('student-header-name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hijriToday(),
                          key: const Key('student-header-hijri'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(avatarEmoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ],
                ),
              ),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
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
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 11,
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
