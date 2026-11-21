import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One destination in the shared floating bottom navigation.
class AppNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget? badge;

  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
  });
}

/// App-wide floating glass bottom nav — same skin, role-specific destinations.
///
/// Pair with [Scaffold.extendBody] `true` so content can scroll under the bar.
class AppFloatingBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final List<AppNavDestination> destinations;

  const AppFloatingBottomNav({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.destinations,
  });

  /// Clearance under scroll content when [Scaffold.extendBody] is on.
  /// Floating bar (~64) + small margin — keep minimal so pages don't show a
  /// huge empty white band above the nav.
  static const double contentClearance = 72;

  /// Reserves space under home-shell bodies so the last section clears the
  /// floating nav. Uses a single hard [Padding] only — does **not** inflate
  /// [MediaQuery.padding] (that doubled with tab [SafeArea] and left a huge
  /// white gap).
  ///
  /// When the keyboard is open, clearance collapses so search fields / forms
  /// are not pushed into overflow under the floating bar.
  static Widget padBody(BuildContext context, {required Widget child}) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final clearance = keyboardOpen ? 8.0 : contentClearance;
    return Padding(
      padding: EdgeInsets.only(bottom: clearance),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(destinations.isNotEmpty);
    final bottom = MediaQuery.paddingOf(context).bottom;

    // Isolate expensive blur from shell tab setState rebuilds (BASMA-106 / D4).
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom : 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.88),
                    AppColors.primaryLight.withValues(alpha: 0.72),
                    Colors.white.withValues(alpha: 0.78),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.55),
                    blurRadius: 1,
                    offset: const Offset(0, -0.5),
                  ),
                ],
              ),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _NavItem(
                          destination: destinations[i],
                          selected: i == selected,
                          onTap: () => onChanged(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : AppColors.textSecondary;
    final label = destination.label.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      size: 22,
                      color: color,
                    ),
                  ),
                  if (destination.badge != null)
                    Positioned(top: -4, left: -6, child: destination.badge!),
                ],
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    height: 1.1,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared rounded icon sets per role shell (unified weight/feel).
abstract final class AppNavIcons {
  // Cupertino glyphs read cleaner than default Material outlines on glass bars.
  static List<AppNavDestination> supervisor(List<String> labels) => [
    AppNavDestination(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: labels[0],
    ),
    AppNavDestination(
      icon: CupertinoIcons.person_3,
      selectedIcon: CupertinoIcons.person_3_fill,
      label: labels[1],
    ),
    AppNavDestination(
      icon: CupertinoIcons.chat_bubble,
      selectedIcon: CupertinoIcons.chat_bubble_fill,
      label: labels[2],
    ),
    AppNavDestination(
      icon: CupertinoIcons.chart_pie,
      selectedIcon: CupertinoIcons.chart_pie_fill,
      label: labels[3],
    ),
    AppNavDestination(
      icon: CupertinoIcons.person_crop_circle,
      selectedIcon: CupertinoIcons.person_crop_circle_fill,
      label: labels[4],
    ),
  ];

  static List<AppNavDestination> admin(List<String> labels) => [
    AppNavDestination(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: labels[0],
    ),
    AppNavDestination(
      icon: CupertinoIcons.person_2_square_stack,
      selectedIcon: CupertinoIcons.person_2_square_stack_fill,
      label: labels[1],
    ),
    AppNavDestination(
      icon: CupertinoIcons.square_grid_2x2,
      selectedIcon: CupertinoIcons.square_grid_2x2_fill,
      label: labels[2],
    ),
    AppNavDestination(
      icon: CupertinoIcons.creditcard,
      selectedIcon: CupertinoIcons.creditcard_fill,
      label: labels[3],
    ),
    AppNavDestination(
      icon: CupertinoIcons.gear,
      selectedIcon: CupertinoIcons.gear_alt_fill,
      label: labels[4],
    ),
  ];

  static List<AppNavDestination> teacher(List<String> labels) => [
    AppNavDestination(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: labels[0],
    ),
    AppNavDestination(
      icon: CupertinoIcons.person_3,
      selectedIcon: CupertinoIcons.person_3_fill,
      label: labels[1],
    ),
    AppNavDestination(
      icon: CupertinoIcons.rosette,
      selectedIcon: CupertinoIcons.rosette,
      label: labels[2],
    ),
    AppNavDestination(
      icon: CupertinoIcons.chat_bubble,
      selectedIcon: CupertinoIcons.chat_bubble_fill,
      label: labels[3],
    ),
    AppNavDestination(
      icon: CupertinoIcons.person_crop_circle,
      selectedIcon: CupertinoIcons.person_crop_circle_fill,
      label: labels[4],
    ),
  ];

  static List<AppNavDestination> parent(List<String> labels) => [
    AppNavDestination(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: labels[0],
    ),
    AppNavDestination(
      icon: CupertinoIcons.person_2,
      selectedIcon: CupertinoIcons.person_2_fill,
      label: labels[1],
    ),
    AppNavDestination(
      icon: CupertinoIcons.chat_bubble,
      selectedIcon: CupertinoIcons.chat_bubble_fill,
      label: labels[2],
    ),
    AppNavDestination(
      icon: CupertinoIcons.money_dollar_circle,
      selectedIcon: CupertinoIcons.money_dollar_circle_fill,
      label: labels[3],
    ),
    AppNavDestination(
      icon: CupertinoIcons.person_crop_circle,
      selectedIcon: CupertinoIcons.person_crop_circle_fill,
      label: labels[4],
    ),
  ];

  static List<AppNavDestination> student(List<String> labels) => [
    AppNavDestination(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: labels[0],
    ),
    AppNavDestination(
      icon: CupertinoIcons.book,
      selectedIcon: CupertinoIcons.book_fill,
      label: labels[1],
    ),
    AppNavDestination(
      icon: CupertinoIcons.star,
      selectedIcon: CupertinoIcons.star_fill,
      label: labels[2],
    ),
    AppNavDestination(
      icon: CupertinoIcons.map,
      selectedIcon: CupertinoIcons.map_fill,
      label: labels[3],
    ),
    AppNavDestination(
      icon: CupertinoIcons.person_crop_circle,
      selectedIcon: CupertinoIcons.person_crop_circle_fill,
      label: labels[4],
    ),
  ];
}
