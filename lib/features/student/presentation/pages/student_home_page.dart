import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/widgets/student_daily_task_widget.dart';
import '../../../../shared/widgets/student_header_widget.dart';
import '../../../../shared/widgets/student_last_evaluation_widget.dart';
import '../../../../shared/widgets/student_progress_widget.dart';
import '../../../../shared/widgets/student_quick_action_widget.dart';
import '../../../../shared/widgets/student_session_card_widget.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../domain/entities/avatar_catalog.dart';
import '../../domain/entities/halaqa_entity.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';
import 'student_badges_page.dart';
import 'student_mushaf_dashboard.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _currentTab = 0;

  // ترتيب القائمة يطابق التصميم في RTL: الرئيسية (يمين) ... حسابي (يسار)
  final _tabs = const [
    _StudentTab(icon: Icons.home_rounded, label: 'الرئيسية'),
    _StudentTab(icon: Icons.menu_book_outlined, label: 'مصحفي'),
    _StudentTab(icon: Icons.star_rounded, label: '', isElevated: true),
    _StudentTab(icon: Icons.map_outlined, label: 'خريطتي'),
    _StudentTab(icon: Icons.person_outline_rounded, label: 'حسابي'),
  ];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  void _loadStudentData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.uid;

    context.read<StudentBloc>()
      ..add(LoadStudentProfileEvent(uid))
      ..add(LoadRecitationRecordsEvent(uid))
      ..add(StartWatchingAssignmentEvent(uid));

    // ابدأ مراقبة الإشعارات
    sl<NotificationsBloc>().add(
      StartWatchingNotificationsEvent(uid: uid, role: AppRoles.student),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StudentBloc, StudentState>(
      listenWhen: (previous, current) {
        final currentHalaqaId = current.profile?.halaqaId;
        if (currentHalaqaId == null || currentHalaqaId.isEmpty) return false;

        final idChanged = previous.profile?.halaqaId != currentHalaqaId;
        final profileJustLoaded =
            previous.profileStatus != SectionStatus.loaded &&
            current.profileStatus == SectionStatus.loaded &&
            current.halaqaStatus == SectionStatus.initial;

        return idChanged || profileJustLoaded;
      },
      listener: (context, state) {
        final halaqaId = state.profile?.halaqaId;
        if (halaqaId == null || halaqaId.isEmpty) return;
        context.read<StudentBloc>().add(LoadStudentHalaqaEvent(halaqaId));
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentTab,
          children: [
            _StudentHomeTab(
              onTabChanged: (index) => setState(() => _currentTab = index),
              onRetryProfile: _loadStudentData,
            ),
            const StudentMushafDashboard(),
            const StudentBadgesPage(),
            const _StudentMapTab(),
            const _StudentProfileTab(),
          ],
        ),
        bottomNavigationBar: _StudentBottomNav(
          tabs: _tabs,
          selected: _currentTab,
          onChanged: (i) => setState(() => _currentTab = i),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// الـ Tab الرئيسي - يطابق Image 1 بالكامل
// ══════════════════════════════════════════════════════════════════════════════

class _StudentHomeTab extends StatelessWidget {
  final ValueChanged<int> onTabChanged;
  final VoidCallback onRetryProfile;

  const _StudentHomeTab({
    required this.onTabChanged,
    required this.onRetryProfile,
  });

  void _retryHalaqa(BuildContext context, String halaqaId) {
    context.read<StudentBloc>().add(LoadStudentHalaqaEvent(halaqaId));
  }

  Future<void> _onRefresh(BuildContext context) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final bloc = context.read<StudentBloc>();
    bloc.add(RefreshStudentDashboardEvent(authState.user.uid));

    final halaqaId = bloc.state.profile?.halaqaId;
    if (halaqaId != null && halaqaId.isNotEmpty) {
      bloc.add(LoadStudentHalaqaEvent(halaqaId));
    }

    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentBloc, StudentState>(
      buildWhen: (previous, current) =>
          previous.profile != current.profile ||
          previous.profileStatus != current.profileStatus ||
          previous.profileError != current.profileError ||
          previous.halaqa != current.halaqa ||
          previous.halaqaStatus != current.halaqaStatus ||
          previous.halaqaError != current.halaqaError ||
          previous.latestAssignment != current.latestAssignment ||
          previous.latestAssignmentStatus != current.latestAssignmentStatus ||
          previous.latestAssignmentError != current.latestAssignmentError ||
          previous.recitationRecords != current.recitationRecords ||
          previous.recitationStatus != current.recitationStatus,
      builder: (context, state) {
        final waitingForProfile =
            state.profile == null &&
            (state.profileStatus == SectionStatus.initial ||
                state.profileStatus == SectionStatus.loading);

        if (waitingForProfile) {
          return const AppLoadingWidget();
        }

        if (state.profileStatus == SectionStatus.error &&
            state.profile == null) {
          return AppErrorWidget(
            message: state.profileError ?? 'تعذر تحميل بيانات الطالب',
            onRetry: onRetryProfile,
          );
        }

        final profile = state.profile;
        final avatarEmoji = AvatarCatalog.byId(
          profile?.avatarId ?? 'fox',
        ).emoji;
        final halaqaId = profile?.halaqaId;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _onRefresh(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header: عملة / نجوم / ستريك من بروفايل Firestore ──
              // TODO: منطق حساب النقاط والاستريك (gamification) يُصمَّم لاحقاً —
              // هنا نقرأ القيم فقط من studentProfiles بدون حساب محلي.
              SliverToBoxAdapter(
                child: BlocSelector<NotificationsBloc, NotificationsState, int>(
                  bloc: sl<NotificationsBloc>(),
                  selector: (state) => state.unreadCount,
                  builder: (context, unreadCount) {
                    return StudentHeaderWidget(
                      name: profile?.name ?? '...',
                      avatarEmoji: avatarEmoji,
                      coins: profile?.coins ?? 0,
                      totalStars: profile?.totalStars ?? 0,
                      streakDays: profile?.streakDays ?? 0,
                      unreadNotificationsCount: unreadCount,
                      onNotificationsTap: () =>
                          context.push('/student/notifications'),
                      onAvatarTap: () => context.push('/student/avatar'),
                      onCoinsTap: () => onTabChanged(2),
                      onStarsTap: () => context.push(AppRoutes.studentAchieve),
                      onStreakTap: () => context.push(AppRoutes.studentStreak),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Quick Actions (3 عناصر — المصحف من الـ bottom nav فقط)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                  ),
                  child: StudentQuickActionsWidget(
                    onClassesTap: () => context.push(AppRoutes.studentSchedule),
                    onReviewScheduleTap: () =>
                        context.push(AppRoutes.studentReviewSchedule),
                    onHomeworkTap: () =>
                        context.push(AppRoutes.studentHomework),
                    onProgressReportTap: () =>
                        context.push(AppRoutes.studentProgressReport),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── حفظ اليوم (يُقرأ من assignments عبر StartWatchingAssignment) ─
              // TODO: ينتظر نظام خطة الحفظ — هيتصمم لاحقاً مع دور المعلم.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                  ),
                  child: StudentDailyTaskWidget(
                    assignment: state.latestAssignment,
                    status: state.latestAssignmentStatus,
                    errorMessage: state.latestAssignmentError,
                    onCardTap: () => context.push(AppRoutes.studentHomework),
                    onReadTap: () => context.push(AppRoutes.studentHomework),
                    onListenTap: () => context.push(
                      state.latestAssignment != null
                          ? AppRoutes.studentHomework
                          : AppRoutes.studentAudio,
                    ),
                    onRetry: () {
                      final auth = context.read<AuthBloc>().state;
                      if (auth is AuthAuthenticated) {
                        context.read<StudentBloc>().add(
                          StartWatchingAssignmentEvent(auth.user.uid),
                        );
                      }
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── تقدم الحفظ: نسبة السورة الحالية + سور مكتملة (منفصلان) ─
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                  ),
                  child: StudentProgressWidget(
                    progressPercent: profile?.overallProgressPercent ?? 0,
                    planName: profile?.currentPlanName ?? '',
                    totalVerses: profile?.totalVersesMemorized ?? 0,
                    completedSurahs: profile?.completedSurahs ?? 0,
                    onTap: () => context.push(AppRoutes.studentProgressReport),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── كارت الجلسة القادمة ────────────────────────────────
              ..._halaqaSectionSlivers(context, state, halaqaId),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── آخر تقييم ─────────────────────────────────────────
              if (state.recitationRecords.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                    ),
                    child: StudentLastEvaluationWidget(
                      record: state.recitationRecords.first,
                      onDetailsTap: () => context.push('/student/evaluations'),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── حديث اليوم ────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
                  child: StudentHadithWidget(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _halaqaSectionSlivers(
    BuildContext context,
    StudentState state,
    String? halaqaId,
  ) {
    final hasHalaqaId = halaqaId != null && halaqaId.isNotEmpty;

    if (state.halaqaStatus == SectionStatus.loaded && state.halaqa != null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
            child: StudentSessionCardWidget(
              halaqa: state.halaqa!,
              onJoinTap: () => _openHalaqaMeeting(context, state.halaqa!),
              onDetailsTap: () => context.push(AppRoutes.studentSchedule),
            ),
          ),
        ),
      ];
    }

    if (hasHalaqaId &&
        (state.halaqaStatus == SectionStatus.loading ||
            state.halaqaStatus == SectionStatus.initial)) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
            child: SizedBox(height: 120, child: AppLoadingWidget()),
          ),
        ),
      ];
    }

    if (hasHalaqaId && state.halaqaStatus == SectionStatus.error) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
            child: AppCard(
              child: Column(
                children: [
                  Text(
                    state.halaqaError ?? 'تعذر تحميل بيانات الحلقة',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'إعادة المحاولة',
                    width: 160,
                    height: 44,
                    onPressed: () => _retryHalaqa(context, halaqaId),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
          child: AppCard(
            onTap: () => context.push(AppRoutes.studentSchedule),
            child: Row(
              children: [
                const Icon(Icons.chevron_left, color: AppColors.textHint),
                const Spacer(),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('حصة الحفظ اليومية', style: AppTextStyles.titleMedium),
                    Text(
                      'اضغط لعرض جدول الحصص',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.dark,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _openHalaqaMeeting(
    BuildContext context,
    HalaqaEntity halaqa,
  ) async {
    final link = halaqa.meetingLink.trim();
    if (link.isEmpty) {
      AppSnackBar.showInfo(
        context,
        'رابط الحصة لسه مش متاح — الحصة لسه ما بدأتش',
      );
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null ||
        !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
      AppSnackBar.showError(context, 'رابط الحصة غير صالح');
      return;
    }

    final launched =
        await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppSnackBar.showError(context, 'تعذر فتح رابط الحصة');
    }
  }
}

/// Adventure map is not backed by real progress data yet — keep the tab slot.
class _StudentMapTab extends StatelessWidget {
  const _StudentMapTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('خريطتي')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 48,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 16),
              const Text(
                'خريطة المغامرة',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Coming Soon',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'ستظهر خريطة التقدم عند تفعيل خطة الحفظ',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentProfileTab extends StatelessWidget {
  const _StudentProfileTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentBloc, StudentState>(
      buildWhen: (previous, current) =>
          previous.profile != current.profile ||
          previous.profileStatus != current.profileStatus,
      builder: (context, state) {
        final profile = state.profile;
        final avatarEmoji = AvatarCatalog.byId(
          profile?.avatarId ?? 'fox',
        ).emoji;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  bottom: AppSizes.paddingL,
                  left: AppSizes.paddingL,
                  right: AppSizes.paddingL,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppSizes.radiusXL),
                    bottomRight: Radius.circular(AppSizes.radiusXL),
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () =>
                            context.push(AppRoutes.studentSettings),
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          avatarEmoji,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile?.name ?? '...',
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if ((profile?.halaqaName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile!.halaqaName,
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                      ),
                      child: Text(
                        'المستوى ${profile?.level ?? 1} 🏅',
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingL,
                  ),
                  child: AppCard(
                    child: Row(
                      children: [
                        _ProfileStat(
                          value: '${profile?.streakDays ?? 0}',
                          label: 'يوم متواصل',
                        ),
                        _ProfileStat(
                          value: '${profile?.totalStars ?? 0}',
                          label: 'نجمة',
                        ),
                        _ProfileStat(
                          value: '${profile?.completedJuz ?? 0}',
                          label: 'جزء مكتمل',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingL,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((profile?.currentPlanName ?? '').isNotEmpty)
                      AppCard(
                        onTap: () => context.push(AppRoutes.studentMushaf),
                        child: Row(
                          children: [
                            const Text('🕌', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'السورة الحالية',
                                    style: AppTextStyles.labelSmall,
                                  ),
                                  Text(
                                    '${profile!.currentPlanName} '
                                    '${profile.overallProgressPercent.toStringAsFixed(0)}%',
                                    style: AppTextStyles.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_left_rounded,
                              color: AppColors.textHint,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSizes.paddingM),

                    _ProfileMenuGroup(
                      items: [
                        _ProfileMenuItem(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'محادثة المعلم',
                          onTap: () => context.push(AppRoutes.studentChat),
                        ),
                        _ProfileMenuItem(
                          icon: Icons.military_tech_outlined,
                          label: 'شاراتي وإنجازاتي',
                          onTap: () => context.push(AppRoutes.studentAchieve),
                        ),
                        _ProfileMenuItem(
                          icon: Icons.bar_chart_rounded,
                          label: 'تقريري الشهري',
                          onTap: () =>
                              context.push(AppRoutes.studentProgressReport),
                        ),
                        _ProfileMenuItem(
                          icon: Icons.theater_comedy_outlined,
                          label: 'تغيير الشخصية',
                          onTap: () => context.push(AppRoutes.studentAvatar),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    // موارد إضافية — مكتبة محتوى عامة (PDF / فيديو / صوت / صور)
                    _ProfileMenuGroup(
                      items: [
                        _ProfileMenuItem(
                          icon: Icons.folder_open_rounded,
                          label: 'مكتبة المحتوى',
                          onTap: () => context.push(AppRoutes.studentContent),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    _ProfileMenuGroup(
                      items: [
                        _ProfileMenuItem(
                          icon: Icons.settings_outlined,
                          label: 'الإعدادات',
                          onTap: () => context.push(AppRoutes.studentSettings),
                        ),
                        const _ProfileMenuItem(
                          icon: Icons.family_restroom_rounded,
                          label: 'حساب ولي الأمر',
                          trailing: 'Coming Soon',
                        ),
                        const _ProfileMenuItem(
                          icon: Icons.help_outline_rounded,
                          label: 'المساعدة والدعم',
                          trailing: 'Coming Soon',
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    _ProfileMenuGroup(
                      items: [
                        _ProfileMenuItem(
                          icon: Icons.logout_rounded,
                          label: 'تسجيل الخروج',
                          isDestructive: true,
                          onTap: () => _confirmLogout(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSizes.paddingXL),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(const LogoutEvent());
            },
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.headlineMedium),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  final List<_ProfileMenuItem> items;

  const _ProfileMenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;
  final String? trailing;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.textSecondary,
      ),
      title: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: color)),
      trailing: isDestructive
          ? null
          : trailing != null
          ? Text(
              trailing!,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textHint,
              ),
            )
          : const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom Navigation
// ══════════════════════════════════════════════════════════════════════════════

class _StudentTab {
  final IconData icon;
  final String label;
  final bool isElevated;

  const _StudentTab({
    required this.icon,
    required this.label,
    this.isElevated = false,
  });
}

class _StudentBottomNav extends StatelessWidget {
  final List<_StudentTab> tabs;
  final int selected;
  final void Function(int) onChanged;

  const _StudentBottomNav({
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<NotificationsBloc, NotificationsState, int>(
      bloc: sl<NotificationsBloc>(),
      selector: (state) => state.unreadCount,
      builder: (context, unreadCount) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: AppSizes.bottomNavHeight,
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final tab = tabs[i];
                  final isSelected = i == selected;

                  if (tab.isElevated) {
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onChanged(i),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.secondary
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isSelected
                                              ? AppColors.secondary
                                              : AppColors.primary)
                                          .withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              tab.icon,
                              color: Colors.white,
                              size: AppSizes.iconL,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          NotificationBadge(
                            count: i == 0 ? unreadCount : 0,
                            child: Icon(
                              tab.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: AppSizes.iconL,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}
