import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
import '../../../halaqa_plan/presentation/bloc/halaqa_plan_bloc.dart';
import '../../../halaqa_plan/presentation/pages/student_halaqa_plan_page.dart';
import '../../../homework/presentation/pages/student_activities_page.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../domain/entities/avatar_catalog.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';
import '../../../mushaf/presentation/pages/mushaf_reader_host.dart';
import '../widgets/halaqa_meeting_join.dart';
import '../widgets/student_loading_skeletons.dart';
import 'student_badges_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _currentTab = 0;

  // ترتيب القائمة يطابق التصميم في RTL: الرئيسية (يمين) ... حسابي (يسار)
  // Figma: الرئيسية / مصحفي / ★ (أصفر) / خريطتي (layers) / حسابي
  final _tabs = const [
    _StudentTab(icon: Icons.home_outlined, label: 'الرئيسية'),
    _StudentTab(icon: Icons.view_list_outlined, label: 'مصحفي'),
    _StudentTab(icon: Icons.star_rounded, label: '', isElevated: true),
    _StudentTab(icon: Icons.route_outlined, label: 'خطة الحلقة'),
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
            const MushafBlocScope(child: MushafReaderHost()),
            const StudentBadgesPage(),
            const _StudentPlanTab(),
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
          return const StudentHomeBodySkeleton();
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
                      onSearchTap: () => context.push(AppRoutes.studentContent),
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
                    onMushafTap: () => onTabChanged(1),
                    onReviewTap: () =>
                        context.push(AppRoutes.studentReviewSchedule),
                    onTeacherTap: () => context.push(AppRoutes.studentChat),
                    onMapTap: () => context.push(AppRoutes.studentJourneyMap),
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

              // ── أنشطة الحلقة (separate from حفظ اليوم)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                  ),
                  child: StudentActivitiesHomeEntry(halaqaId: halaqaId),
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
                    totalStars: profile?.totalStars ?? 0,
                    onTap: () => context.push(AppRoutes.studentProgressReport),
                    onDetailsTap: () =>
                        context.push(AppRoutes.studentProgressReport),
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
              onJoinTap: () => joinHalaqaMeeting(context, state.halaqa!.id),
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
            child: SizedBox(height: 120, child: StudentHomeBodySkeleton()),
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
                Column(
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
}

class _StudentPlanTab extends StatefulWidget {
  const _StudentPlanTab();

  @override
  State<_StudentPlanTab> createState() => _StudentPlanTabState();
}

class _StudentPlanTabState extends State<_StudentPlanTab> {
  final HalaqaPlanBloc _bloc = sl<HalaqaPlanBloc>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _load() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    _bloc.add(
      LoadStudentHalaqaPlanEvent(
        studentId: auth.user.uid,
        halaqaId: context.read<StudentBloc>().state.profile?.halaqaId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<StudentBloc, StudentState>(
        listenWhen: (p, c) => p.profile?.halaqaId != c.profile?.halaqaId,
        listener: (_, __) => _load(),
        child: StudentHalaqaPlanView(onRetry: _load),
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
        final shortId = (profile?.uid ?? '').length >= 6
            ? profile!.uid.substring(0, 6).toUpperCase()
            : (profile?.uid ?? '----');
        final pct = (profile?.overallProgressPercent ?? 0)
            .clamp(0, 100)
            .toInt();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  bottom: 48,
                  left: 20,
                  right: 20,
                ),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.push(AppRoutes.studentSettings),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.settings_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          avatarEmoji,
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile?.name ?? '...',
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الطالب رقم #$shortId',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'المستوى ${profile?.level ?? 1} • حافظ مجتهد 🏆',
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3A2E00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _ProfileStat(
                          value: '${profile?.streakDays ?? 0}',
                          label: 'يوم متواصل',
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: AppColors.border,
                        ),
                        _ProfileStat(
                          value: '${profile?.totalStars ?? 0}',
                          label: 'نجمة',
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: AppColors.border,
                        ),
                        _ProfileStat(
                          value: '${profile?.completedSurahs ?? 0}',
                          label: 'سور محفوظة',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((profile?.currentPlanName ?? '').isNotEmpty) ...[
                      Row(
                        children: [
                          const Text('🕌', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            'السورة الحالية',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${profile!.currentPlanName} $pct%',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    _ProfileMenuGroup(
                      items: [
                        _ProfileMenuItem(
                          icon: Icons.emoji_events_outlined,
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

                    // موارد الحلقة — المحتوى المشترك (P0 §8) + المكتبة الصوتية (§5)
                    _ProfileMenuGroup(
                      items: [
                        _ProfileMenuItem(
                          icon: Icons.folder_open_rounded,
                          label: 'المحتوى المشترك للحلقة',
                          onTap: () {
                            final halaqaId =
                                context
                                    .read<StudentBloc>()
                                    .state
                                    .profile
                                    ?.halaqaId ??
                                '';
                            context.push(AppRoutes.studentContentFor(halaqaId));
                          },
                        ),
                        _ProfileMenuItem(
                          icon: Icons.headphones_rounded,
                          label: 'المكتبة الصوتية',
                          onTap: () => context.push(AppRoutes.studentAudio),
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
                        _ProfileMenuItem(
                          icon: Icons.family_restroom_rounded,
                          label: 'حساب ولي الأمر',
                          onTap: () => context.push(AppRoutes.studentSettings),
                        ),
                        _ProfileMenuItem(
                          icon: Icons.help_outline_rounded,
                          label: 'المساعدة والدعم',
                          onTap: () => context.push(AppRoutes.studentSettings),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _ProfileMenuGroup(
                      items: [
                        _ProfileMenuItem(
                          icon: Icons.folder_open_rounded,
                          label: 'مكتبة المحتوى',
                          onTap: () => context.push(AppRoutes.studentContent),
                        ),
                        _ProfileMenuItem(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'محادثة المعلم',
                          onTap: () => context.push(AppRoutes.studentChat),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

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

                    const SizedBox(height: 28),
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
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(
          color: color,
          fontWeight: isDestructive ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      trailing: isDestructive
          ? null
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
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.softShadow,
                blurRadius: 12,
                offset: Offset(0, -2),
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
                        child: Transform.translate(
                          offset: const Offset(0, -10),
                          child: Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                tab.icon,
                                color: Colors.white,
                                size: 28,
                              ),
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
                              isSelected && i == 0
                                  ? Icons.home_rounded
                                  : tab.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: AppSizes.iconL,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(top: 3),
                            width: isSelected ? 5 : 0,
                            height: isSelected ? 5 : 0,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
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
