import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../student/domain/entities/achievement_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../../student/domain/entities/student_profile_entity.dart';
import '../../../student/domain/student_profile_latest_evaluation.dart';
import '../../../student/domain/usecases/get_achievements_usecase.dart';
import '../../../student/domain/usecases/get_recitation_records_usecase.dart';
import '../../../student/domain/usecases/get_student_profile_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../domain/parent_household.dart';
import '../../domain/parent_performance.dart';
import '../bloc/parent_bloc.dart';
import '../parent_child_access.dart';
import '../parent_destinations.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_user_avatar.dart';

class ParentChildProfilePage extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const ParentChildProfilePage({
    super.key,
    required this.studentId,
    this.studentName,
  });

  @override
  State<ParentChildProfilePage> createState() => _ParentChildProfilePageState();
}

class _ParentChildProfilePageState extends State<ParentChildProfilePage> {
  bool _loading = true;
  String? _error;
  StudentProfileEntity? _profile;
  StudentProfileLatestEvaluation? _latest;
  double? _performance;
  List<AchievementEntity> _achievements = const [];
  List<RecitationRecordEntity> _reviewedRecitations = const [];
  bool _startingChat = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final parentState = context.read<ParentBloc>().state;
    if (!ParentChildAccess.owns(
      state: parentState,
      studentId: widget.studentId,
    )) {
      setState(() {
        _loading = false;
        _error = ParentChildAccess.deniedMessage;
        _profile = null;
        _latest = null;
        _performance = null;
        _achievements = const [];
        _reviewedRecitations = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = StudentUidParams(widget.studentId);
    final profileResult = await sl<GetStudentProfileUseCase>()(uid);
    final recitationsResult = await sl<GetRecitationRecordsUseCase>()(uid);
    final achievementsResult = await sl<GetAchievementsUseCase>()(uid);
    if (!mounted) return;

    profileResult.fold((f) {
      setState(() {
        _loading = false;
        _error = f.message;
      });
    }, (profile) {
      final records = recitationsResult.getOrElse(
        (_) => const <RecitationRecordEntity>[],
      );
        final reviewed = records.where((r) => !r.isPendingReview).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        setState(() {
        _loading = false;
        _profile = profile;
        _latest = pickLatestStudentProfileEvaluation(records);
        _performance = ParentPerformance.averagePercent(records);
        _achievements = achievementsResult.getOrElse(
          (_) => const <AchievementEntity>[],
        );
          _reviewedRecitations = reviewed;
        });
    });
  }

  Future<void> _startTeacherChat(ParentChildSnapshot? snapshot) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated || _startingChat) return;

    final teacherId = (snapshot?.teacherId ?? '').trim();
    final supervisorId = (snapshot?.supervisorId ?? '').trim();
    final targetId = teacherId.isNotEmpty ? teacherId : supervisorId;
    if (targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد معلم أو مشرف مرتبط بهذا الابن')),
      );
      return;
    }

    final staff = context.read<ParentBloc>().state.staffContacts;
    ParentStaffContact? contact;
    for (final item in staff) {
      if (item.uid == targetId) {
        contact = item;
        break;
      }
    }
    final isTeacher = targetId == teacherId;
    contact ??= ParentStaffContact(
      uid: targetId,
      name: isTeacher
          ? ((snapshot?.teacherName.trim().isNotEmpty == true)
                ? snapshot!.teacherName.trim()
                : 'المعلم')
          : ((snapshot?.supervisorName.trim().isNotEmpty == true)
                ? snapshot!.supervisorName.trim()
                : 'المشرف'),
      role: isTeacher ? AppRoles.teacher : AppRoles.supervisor,
    );

    setState(() => _startingChat = true);
    final conversations = sl<ChatConversationsBloc>().state.conversations;
    for (final conversation in conversations) {
      final other = conversation.otherParticipant(auth.user.uid);
      if (other.uid == contact.uid) {
        setState(() => _startingChat = false);
        if (!mounted) return;
        await ParentDestinations.chat(
          context,
          conversationId: conversation.id,
          title: other.name.trim().isEmpty ? contact.name : other.name,
          imageUrl: other.profileImageUrl ?? contact.profileImageUrl,
        );
        return;
      }
    }

    sl<ChatConversationsBloc>().add(const ResetStartConversationEvent());
    sl<ChatConversationsBloc>().add(
      StartConversationEvent(
        currentUser: ChatParticipantEntity(
          uid: auth.user.uid,
          name: auth.user.name,
          role: AppRoles.parent,
          profileImageUrl: auth.user.profileImageUrl,
        ),
        otherUser: ChatParticipantEntity(
          uid: contact.uid,
          name: contact.name,
          role: contact.role,
          profileImageUrl: contact.profileImageUrl,
        ),
      ),
    );
  }

  List<_ActivityItem> _buildActivities() {
    final items = <_ActivityItem>[];
    for (final award in _achievements) {
      items.add(
        _ActivityItem(
          title: award.title.trim().isEmpty ? 'إنجاز' : award.title.trim(),
          subtitle: [
            if ((award.description ?? '').trim().isNotEmpty)
              award.description!.trim(),
            parentRelativeTime(award.date),
          ].join(' — '),
          date: award.date,
          color: AppColors.secondary,
        ),
      );
    }
    for (final record in _reviewedRecitations) {
      final grade = record.grade;
      final typeLabel = record.type == RecitationType.review
          ? 'مراجعة'
          : 'تقييم';
      final title = grade == null ? typeLabel : '$typeLabel ${grade.label}';
      items.add(
        _ActivityItem(
          title: title,
          subtitle: [
            if (record.versesRange.trim().isNotEmpty) record.versesRange.trim(),
            parentRelativeTime(record.date),
          ].join(' — '),
          date: record.date,
          color: record.type == RecitationType.review
              ? AppColors.info
              : AppColors.success,
        ),
      );
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<ParentBloc, ParentChildSnapshot?>(
      (bloc) => bloc.state.snapshotFor(widget.studentId),
    );
    final fallbackName = (widget.studentName ?? '').trim();
    final name = (_profile?.name.trim().isNotEmpty == true)
        ? _profile!.name.trim()
        : (snapshot?.displayName ??
              (fallbackName.isEmpty ? 'الطالب' : fallbackName));
    final halaqa = (_profile?.halaqaName.trim().isNotEmpty == true)
        ? _profile!.halaqaName.trim()
        : (snapshot?.halaqaName.trim() ?? '');
    final level = _profile?.level ?? 1;
    final teacher = snapshot?.teacherName.trim() ?? '';
    final supervisor = snapshot?.supervisorName.trim() ?? '';
    final progress = (_profile?.overallProgressPercent ??
        snapshot?.overallProgressPercent ??
        0)
        .clamp(0.0, 100.0);
    final verses =
        _profile?.totalVersesMemorized ?? snapshot?.totalVersesMemorized ?? 0;
    final attendanceLabel = parentPercentLabel(
      snapshot?.attendancePercentInWindow,
    );
    final performanceLabel = _performance == null
        ? '—'
        : parentPercentLabel(_performance);
    final teacherNote = (_latest?.notes ?? '').trim();
    final activities = _buildActivities();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocListener<ChatConversationsBloc, ChatConversationsState>(
        bloc: sl<ChatConversationsBloc>(),
        listenWhen: (p, c) =>
        p.startConversationStatus != c.startConversationStatus,
        listener: (context, state) async {
          if (!_startingChat) return;
          final auth = context
              .read<AuthBloc>()
              .state;
          final uid = auth is AuthAuthenticated ? auth.user.uid : '';
          if (state.startConversationStatus == SubmissionStatus.error) {
            setState(() => _startingChat = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.startConversationError ?? 'تعذر بدء المحادثة',
                ),
              ),
            );
            return;
          }
          if (state.startConversationStatus == SubmissionStatus.success &&
              state.startedConversation != null) {
            final conversation = state.startedConversation!;
            sl<ChatConversationsBloc>().add(
              const ResetStartConversationEvent(),
            );
            setState(() => _startingChat = false);
            final other = conversation.otherParticipant(uid);
            if (!mounted) return;
            await ParentDestinations.chat(
              context,
              conversationId: conversation.id,
              title: other.name,
              imageUrl: other.profileImageUrl,
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF5FAFB),
          body: _loading
              ? const ParentDashboardSkeleton()
              : _error != null
              ? AppErrorWidget(message: _error!, onRetry: _load)
              : CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _ProfileHero(
                  name: name,
                  imageUrl:
                  _profile?.profileImageUrl ??
                      snapshot?.profileImageUrl,
                  halaqa: halaqa,
                  level: level,
                  teacher: teacher,
                  supervisor: supervisor,
                  performance: performanceLabel,
                  attendance: attendanceLabel,
                  verses: parentEasternDigits('$verses'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ActionsGrid(
                      onEvaluations: () =>
                          ParentDestinations.evaluations(
                            context,
                            studentId: widget.studentId,
                            studentName: name,
                          ),
                      onReports: () =>
                          ParentDestinations.reports(
                            context,
                            studentId: widget.studentId,
                            studentName: name,
                          ),
                      onSchedule: () =>
                          ParentDestinations.schedule(
                            context,
                            studentId: widget.studentId,
                            studentName: name,
                          ),
                      onContact: _startingChat
                          ? null
                          : () => _startTeacherChat(snapshot),
                    ),
                    const SizedBox(height: 20),
                    _MemorizationSection(
                      progressPercent: progress,
                      memorizedVerses: verses,
                    ),
                    const SizedBox(height: 18),
                    _NotesSection(teacherNote: teacherNote),
                    const SizedBox(height: 18),
                    _ActivitiesSection(
                      items: activities,
                      onSeeAll: () =>
                          ParentDestinations.achievements(
                            context,
                            studentId: widget.studentId,
                            studentName: name,
                          ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final DateTime date;
  final Color color;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.color,
  });
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String halaqa;
  final int level;
  final String teacher;
  final String supervisor;
  final String performance;
  final String attendance;
  final String verses;

  const _ProfileHero({
    required this.name,
    required this.imageUrl,
    required this.halaqa,
    required this.level,
    required this.teacher,
    required this.supervisor,
    required this.performance,
    required this.attendance,
    required this.verses,
  });

  @override
  Widget build(BuildContext context) {
    final halaqaLine = [
      if (halaqa.isNotEmpty) halaqa,
      'المستوى ${parentEasternDigits('$level')}',
    ].join(' - ');
    final staffLine = [
      if (teacher.isNotEmpty) 'المعلم: $teacher',
      if (supervisor.isNotEmpty) 'المشرف: $supervisor',
    ].join(' - ');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.primaryGradient),
            child: SizedBox(height: 300),
          ),
        ),
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Material(
                          color: AppColors.onPrimaryOverlay,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => Navigator.of(context).maybePop(),
                            borderRadius: BorderRadius.circular(12),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'ملف الطالب',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.onPrimary.withValues(alpha: 0.55),
                          width: 2,
                        ),
                      ),
                      child: ParentUserAvatar(
                        name: name,
                        imageUrl: imageUrl,
                        radius: 46,
                        backgroundColor: AppColors.onPrimary,
                        foregroundColor: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (halaqaLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        halaqaLine,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onPrimaryMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (staffLine.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: AppColors.onPrimary.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              staffLine,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.onPrimaryMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _StatsCard(
                  performance: performance,
                  attendance: attendance,
                  verses: verses,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String performance;
  final String attendance;
  final String verses;

  const _StatsCard({
    required this.performance,
    required this.attendance,
    required this.verses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatCell(value: performance, label: 'الأداء'),
          _Divider(),
          _StatCell(value: attendance, label: 'الحضور'),
          _Divider(),
          _StatCell(value: verses, label: 'آية'),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.border);
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;

  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsGrid extends StatelessWidget {
  final VoidCallback onEvaluations;
  final VoidCallback onReports;
  final VoidCallback onSchedule;
  final VoidCallback? onContact;

  const _ActionsGrid({
    required this.onEvaluations,
    required this.onReports,
    required this.onSchedule,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'عرض التقييمات',
                icon: Icons.fact_check_outlined,
                filled: true,
                onTap: onEvaluations,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'التقارير',
                icon: Icons.bar_chart_rounded,
                filled: false,
                onTap: onReports,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'الجدول',
                icon: Icons.calendar_month_outlined,
                filled: false,
                onTap: onSchedule,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'تواصل',
                icon: Icons.chat_bubble_outline_rounded,
                filled: false,
                onTap: onContact,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusL);
    if (filled) {
      return Material(
        color: AppColors.primary,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.onPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemorizationSection extends StatelessWidget {
  final double progressPercent;
  final int memorizedVerses;

  const _MemorizationSection({
    required this.progressPercent,
    required this.memorizedVerses,
  });

  @override
  Widget build(BuildContext context) {
    final pct = progressPercent.round().clamp(0, 100);
    // Remaining verses for *current surah* are not stored as a separate field.
    // Do not invent: show dash unless progress is complete (0 remaining).
    final remainingLabel = pct >= 100
        ? parentEasternDigits('0')
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'تقدم الحفظ',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                parentPercentLabel(progressPercent),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.secondaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            boxShadow: const [
              BoxShadow(
                color: AppColors.softShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                width: 148,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 148,
                      height: 148,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 14,
                        backgroundColor: const Color(0xFFE8EEF0),
                        color: AppColors.secondary,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          parentEasternDigits('$pct%'),
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'مكتمل',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          parentEasternDigits('$memorizedVerses'),
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'آية محفوظة',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.border),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          remainingLabel,
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'آية متبقية',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  final String teacherNote;

  const _NotesSection({required this.teacherNote});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NoteBlock(
          title: 'ملاحظات المعلم',
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.primary,
          background: AppColors.primaryLight,
          body: teacherNote.isEmpty
              ? 'لا توجد ملاحظة من المعلم في آخر تقييم معتمد.'
              : teacherNote,
        ),
        const SizedBox(height: 10),
        const _NoteBlock(
          title: 'ملاحظات المشرف',
          icon: Icons.verified_user_outlined,
          iconColor: AppColors.secondaryDeep,
          background: AppColors.secondaryBg,
          body:
          'لا توجد ملاحظات مشرف محفوظة في النظام بعد — ستظهر هنا عند توفر مصدرها.',
        ),
      ],
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String body;

  const _NoteBlock({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          child: Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.82),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivitiesSection extends StatelessWidget {
  final List<_ActivityItem> items;
  final VoidCallback onSeeAll;

  const _ActivitiesSection({
    required this.items,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'آخر النشاطات',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('الكل'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'لا توجد نشاطات أو إنجازات ممنوحة بعد.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.softShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _TimelineRow(
                    item: items[i],
                    isLast: i == items.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _ActivityItem item;
  final bool isLast;

  const _TimelineRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 8 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
