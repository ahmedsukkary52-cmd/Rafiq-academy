import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../awards/presentation/bloc/awards_bloc.dart';
import '../../../awards/presentation/bloc/awards_event.dart';
import '../../../awards/presentation/bloc/awards_state.dart';
import '../../../awards/presentation/pages/awards_page.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../parent/domain/repositories/parent_repositories.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../../teacher/presentation/teacher_contact_parent.dart';
import '../../../teacher/presentation/widgets/teacher_home_figma_cards.dart';
import '../../../teacher/presentation/widgets/teacher_loading_skeletons.dart';
import '../../domain/entities/recitation_record_entity.dart';
import '../../domain/entities/student_profile_entity.dart';
import '../../domain/student_profile_award_scope.dart';
import '../../domain/student_profile_content.dart';
import '../../domain/student_profile_latest_evaluation.dart';
import '../../domain/usecases/get_recitation_records_usecase.dart';
import '../../domain/usecases/get_student_halaqa_usecase.dart';
import '../../domain/usecases/get_student_profile_usecase.dart';
import '../../domain/usecases/watch_latest_assignment_usecase.dart';

class StudentProfilePage extends StatefulWidget {
  final String studentId;
  final String? halaqaId;

  const StudentProfilePage({
    super.key,
    required this.studentId,
    this.halaqaId,
  });

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  late final AwardsBloc _awardsBloc;
  SectionStatus _status = SectionStatus.initial;
  StudentProfileEntity? _profile;
  String? _halaqaName;
  String? _grantHalaqaId;
  double? _attendancePercent;
  bool _hasLinkedGuardian = false;
  String? _guardianName;
  StudentProfileLatestEvaluation? _latestEvaluation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _awardsBloc = sl<AwardsBloc>();
    _load();
  }

  @override
  void dispose() {
    _awardsBloc.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _status = SectionStatus.loading;
      _error = null;
    });

    final result = await sl<GetStudentProfileUseCase>()(
      StudentUidParams(widget.studentId),
    );

    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() {
          _status = SectionStatus.error;
          _error = failure.message;
          _profile = null;
          _halaqaName = null;
          _grantHalaqaId = null;
          _attendancePercent = null;
          _hasLinkedGuardian = false;
          _guardianName = null;
          _latestEvaluation = null;
        });
      },
      (profile) async {
        final grantHalaqaId = resolveStudentProfileAwardHalaqaId(
          routeHalaqaId: widget.halaqaId,
          profileHalaqaId: profile.halaqaId,
        );
        var halaqaName = profile.halaqaName.trim();
        double? attendancePercent;

        if (grantHalaqaId != null) {
          final rosterResult = await sl<GetHalaqaStudentsUseCase>()(
            HalaqaStudentsParams(grantHalaqaId),
          );
          rosterResult.fold((_) {}, (roster) {
            attendancePercent = attendancePercentFromRoster(
              roster: roster,
              studentId: widget.studentId,
            );
          });

          if (halaqaName.isEmpty) {
            final halaqaResult = await sl<GetStudentHalaqaUseCase>()(
              HalaqaIdParams(grantHalaqaId),
            );
            halaqaResult.fold((_) {}, (halaqa) => halaqaName = halaqa.name);
          }
        }

        final recitationsFuture = sl<GetRecitationRecordsUseCase>()(
          StudentUidParams(widget.studentId),
        );
        final parentsFuture = sl<ParentRepository>().getParentIdsByStudentIds([
          widget.studentId,
        ]);
        final recitationsResult = await recitationsFuture;
        final parentsResult = await parentsFuture;
        if (!mounted) return;

        StudentProfileLatestEvaluation? latestEvaluation;
        recitationsResult.fold((_) {}, (records) {
          latestEvaluation = pickLatestStudentProfileEvaluation(records);
        });

        var hasLinkedGuardian = false;
        String? guardianName;
        final parentIds = parentsResult.fold<List<String>>(
          (_) => const <String>[],
          (map) => map[widget.studentId] ?? const <String>[],
        );
        if (parentIds.isNotEmpty) {
          hasLinkedGuardian = true;
          final parentResult = await sl<GetChatParticipantUseCase>()(
            ChatUidParams(parentIds.first),
          );
          parentResult.fold((_) {}, (parent) {
            guardianName = nonEmptyTrimmed(parent.name);
          });
        }

        if (!mounted) return;
        setState(() {
          _status = SectionStatus.loaded;
          _profile = profile;
          _halaqaName = halaqaName.isEmpty ? null : halaqaName;
          _grantHalaqaId = grantHalaqaId;
          _attendancePercent = attendancePercent;
          _hasLinkedGuardian = hasLinkedGuardian;
          _guardianName = guardianName;
          _latestEvaluation = latestEvaluation;
          _error = null;
        });
      },
    );
  }

  void _openCreateAwardSheet() {
    final halaqaId = _grantHalaqaId;
    if (halaqaId == null || halaqaId.isEmpty) {
      AppSnackBar.showInfo(context, 'لا توجد حلقة مسندة لهذا الطالب');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _awardsBloc,
        child: CreateAwardSheet(
          halaqaId: halaqaId,
          preselectedStudentId: widget.studentId,
        ),
      ),
    );
  }

  void _openEvaluations() {
    final path = studentProfileEvaluationsPath(
      halaqaId: _grantHalaqaId,
      studentId: widget.studentId,
    );
    if (path == null) {
      AppSnackBar.showInfo(context, 'لا توجد حلقة مسندة لهذا الطالب');
      return;
    }
    context.push(path);
  }

  Future<void> _contactParent() {
    return contactStudentParent(
      context: context,
      studentId: widget.studentId,
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider.value(
        value: _awardsBloc,
        child: BlocListener<AwardsBloc, AwardsState>(
          listenWhen: (previous, current) =>
              previous.grantStatus != current.grantStatus,
          listener: (context, state) {
            if (state.grantStatus == SubmissionStatus.success) {
              AppSnackBar.showSuccess(context, 'تم منح الجائزة بنجاح');
              _awardsBloc.add(const ResetGrantAwardEvent());
            } else if (state.grantStatus == SubmissionStatus.error) {
              AppSnackBar.showError(
                context,
                state.grantError ?? 'تعذر منح الجائزة',
              );
              _awardsBloc.add(const ResetGrantAwardEvent());
            }
          },
          child: _buildScaffold(),
        ),
      ),
    );
  }

  Widget _buildScaffold() {
    if (_status == SectionStatus.loading ||
        _status == SectionStatus.initial) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: TeacherStudentProfileSkeleton(),
      );
    }

    if (_status == SectionStatus.error || _profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('ملف الطالب'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _goBack,
          ),
        ),
        body: AppErrorWidget(
          message: _error ?? 'تعذر تحميل بيانات الطالب',
          onRetry: _load,
        ),
      );
    }

    final profile = _profile!;
    final planName = profile.currentPlanName.trim().isEmpty
        ? 'لا توجد خطة حالية'
        : profile.currentPlanName.trim();
    final halaqaLabel = (_halaqaName == null || _halaqaName!.trim().isEmpty)
        ? 'لا توجد حلقة'
        : _halaqaName!.trim();
    final attendanceLabel = _attendancePercent == null
        ? '—'
        : '${teacherHomeEasternDigits('${_attendancePercent!.round()}')}٪';
    final streakLabel = teacherHomeEasternDigits('${profile.streakDays}');
    final versesLabel = teacherHomeEasternDigits(
      '${profile.totalVersesMemorized}',
    );
    final progressPercent =
        profile.overallProgressPercent.clamp(0.0, 100.0).toDouble();
    final joinDate = _formatJoinMonthYear(profile.createdAt);
    final phone = nonEmptyTrimmed(profile.phone);
    final guardianValue = !_hasLinkedGuardian
        ? 'غير مرتبط'
        : (_guardianName ?? 'ولي الأمر');
    final displayName =
        profile.name.trim().isEmpty ? 'طالب' : profile.name.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Gradient is painted behind content; header sizes to its children
          // so it cannot overflow a fixed SliverAppBar height.
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 320,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                ),
                Column(
                  children: [
                    _ProfileHeader(
                      name: displayName,
                      level: profile.level,
                      halaqaName: halaqaLabel,
                      profileImageUrl: profile.profileImageUrl,
                      onBack: _goBack,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StatsCard(
                              attendanceLabel: attendanceLabel,
                              streakLabel: streakLabel,
                              versesLabel: versesLabel,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                // RTL: first child is on the right (start).
                                Expanded(
                                  child: _ProfileCtaButton(
                                    label: 'تواصل مع الأهل',
                                    icon: Icons.chat_bubble_rounded,
                                    backgroundColor: AppColors.primary,
                                    onPressed: _contactParent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ProfileCtaButton(
                                    label: 'منح جائزة',
                                    icon: Icons.star_rounded,
                                    backgroundColor: AppColors.secondary,
                                    onPressed: _openCreateAwardSheet,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoCard(
                              name: displayName,
                              guardian: guardianValue,
                              phone: phone == null
                                  ? 'غير متوفر'
                                  : teacherHomeEasternDigits(phone),
                              planName: planName,
                              joinDate: joinDate == null
                                  ? 'غير متوفر'
                                  : teacherHomeEasternDigits(joinDate),
                            ),
                            const SizedBox(height: 16),
                            _ProgressCard(
                              versesMemorized: profile.totalVersesMemorized,
                              progressPercent: progressPercent,
                              onDetailsTap: _openEvaluations,
                            ),
                            const SizedBox(height: 16),
                            _LatestEvaluationCard(
                              evaluation: _latestEvaluation,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Month + year only — matches the design (`سبتمبر ٢٠٢٤`).
String? _formatJoinMonthYear(DateTime? createdAt) {
  if (createdAt == null) return null;
  const months = [
    '',
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${months[createdAt.month]} ${createdAt.year}';
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final int level;
  final String halaqaName;
  final String? profileImageUrl;
  final VoidCallback onBack;

  const _ProfileHeader({
    required this.name,
    required this.level,
    required this.halaqaName,
    required this.profileImageUrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 48),
      child: Column(
        children: [
          Row(
            children: [
              _HeaderCircleButton(
                icon: Icons.chevron_right_rounded,
                onTap: onBack,
              ),
              Expanded(
                child: Text(
                  'ملف الطالب',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 18),
          _HeaderAvatar(name: name, imageUrl: profileImageUrl),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'المستوى ${teacherHomeEasternDigits('$level')} - $halaqaName',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onPrimaryMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onPrimary.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.onPrimary, size: 22),
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _HeaderAvatar({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '؟' : trimmed[0];
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.onPrimary.withValues(alpha: 0.45),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 44,
        backgroundColor: AppColors.onPrimary,
        backgroundImage: hasImage ? NetworkImage(imageUrl!.trim()) : null,
        child: hasImage
            ? null
            : Text(
                initial,
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                ),
              ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String attendanceLabel;
  final String streakLabel;
  final String versesLabel;

  const _StatsCard({
    required this.attendanceLabel,
    required this.streakLabel,
    required this.versesLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: AppSizes.radiusL,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatCell(value: attendanceLabel, label: 'الحضور'),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            Expanded(
              child: _StatCell(value: streakLabel, label: 'يوم متتالي'),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            Expanded(
              child: _StatCell(value: versesLabel, label: 'آية حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;

  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _ProfileCtaButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String name;
  final String guardian;
  final String phone;
  final String planName;
  final String joinDate;

  const _InfoCard({
    required this.name,
    required this.guardian,
    required this.phone,
    required this.planName,
    required this.joinDate,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text('معلومات الطالب', style: AppTextStyles.titleMedium),
            ],
          ),
          const Divider(height: 20),
          _InfoRow(label: 'الاسم الكامل', value: name),
          const SizedBox(height: 12),
          _InfoRow(label: 'ولي الأمر', value: guardian),
          const SizedBox(height: 12),
          _InfoRow(label: 'رقم الهاتف', value: phone),
          const SizedBox(height: 12),
          _InfoRow(label: 'الخطة الحالية', value: planName),
          const SizedBox(height: 12),
          _InfoRow(label: 'تاريخ الانضمام', value: joinDate),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int versesMemorized;
  final double progressPercent;
  final VoidCallback onDetailsTap;

  const _ProgressCard({
    required this.versesMemorized,
    required this.progressPercent,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final versesLabel =
        '${teacherHomeEasternDigits('$versesMemorized')} آية';
    final percentLabel =
        '${teacherHomeEasternDigits('${progressPercent.round()}')}٪';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_graph_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text('تقدم الحفظ', style: AppTextStyles.titleMedium),
              ),
              GestureDetector(
                onTap: onDetailsTap,
                child: Text(
                  'التفاصيل',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  versesLabel,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              Text(
                percentLabel,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: (progressPercent / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.primaryLight,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestEvaluationCard extends StatelessWidget {
  final StudentProfileLatestEvaluation? evaluation;

  const _LatestEvaluationCard({required this.evaluation});

  @override
  Widget build(BuildContext context) {
    final latest = evaluation;
    final overall = latest?.memorizationGrade ??
        latest?.reviewGrade ??
        latest?.behaviorGrade;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.primary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'آخر تقييم',
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                          if (overall != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _gradeTint(overall),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusFull,
                                ),
                              ),
                              child: Text(
                                overall.label,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: _gradeColor(overall),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (latest == null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'لا يوجد تقييم بعد',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _EvaluationBox(
                                label: 'الحفظ',
                                grade: latest.memorizationGrade,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _EvaluationBox(
                                label: 'المراجعة',
                                grade: latest.reviewGrade,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _EvaluationBox(
                                label: 'السلوك',
                                grade: latest.behaviorGrade,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvaluationBox extends StatelessWidget {
  final String label;
  final RecitationGrade? grade;

  const _EvaluationBox({required this.label, required this.grade});

  @override
  Widget build(BuildContext context) {
    final tint = grade == null ? AppColors.surfaceGrey : _gradeTint(grade!);
    final color =
        grade == null ? AppColors.textSecondary : _gradeColor(grade!);
    final value = grade?.label ?? '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _gradeColor(RecitationGrade grade) => switch (grade) {
  RecitationGrade.excellent => AppColors.gradeExcellent,
  RecitationGrade.veryGood => AppColors.info,
  RecitationGrade.good => AppColors.gradeGood,
  RecitationGrade.needsRetry => AppColors.gradeNeedsWork,
};

Color _gradeTint(RecitationGrade grade) =>
    _gradeColor(grade).withValues(alpha: 0.12);
