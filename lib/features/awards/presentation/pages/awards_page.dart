import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../teacher/presentation/bloc/teacher_bloc.dart';
import '../../domain/entities/award_entities.dart';
import '../bloc/awards_bloc.dart';
import '../bloc/awards_event.dart';
import '../bloc/awards_state.dart';

class AwardsPage extends StatefulWidget {
  final String halaqaId;

  const AwardsPage({super.key, required this.halaqaId});

  @override
  State<AwardsPage> createState() => _AwardsPageState();
}

class _AwardsPageState extends State<AwardsPage> {
  late final AwardsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<AwardsBloc>();
    _bloc.add(LoadAwardsDashboardEvent(widget.halaqaId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: [
          BlocListener<AwardsBloc, AwardsState>(
            listenWhen: (previous, current) =>
                previous.certificateStatus != current.certificateStatus,
            listener: (context, state) async {
              if (state.certificateStatus == SubmissionStatus.success &&
                  state.certificateBytes != null) {
                await Printing.sharePdf(
                  bytes: Uint8List.fromList(state.certificateBytes!),
                  filename: 'شهادة_تقدير.pdf',
                );
                _bloc.add(const ResetCertificateEvent());
              }
            },
          ),
          BlocListener<AwardsBloc, AwardsState>(
            listenWhen: (previous, current) =>
                previous.grantStatus != current.grantStatus,
            listener: (context, state) {
              if (state.grantStatus == SubmissionStatus.success) {
                AppSnackBar.showSuccess(context, 'تم منح الجائزة بنجاح');
                _bloc.add(const ResetGrantAwardEvent());
              } else if (state.grantStatus == SubmissionStatus.error) {
                AppSnackBar.showError(
                  context,
                  state.grantError ?? 'تعذر منح الجائزة',
                );
                _bloc.add(const ResetGrantAwardEvent());
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: AppColors.dark,
          appBar: AppBar(
            backgroundColor: AppColors.dark,
            foregroundColor: Colors.white,
            title: const Text('منح الجوائز'),
            actions: [
              TextButton.icon(
                onPressed: () => _showGrantAwardSheet(context),
                icon: const Icon(Icons.add_rounded, color: AppColors.secondary),
                label: const Text(
                  '+ جائزة جديدة',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          body: BlocBuilder<AwardsBloc, AwardsState>(
            buildWhen: (previous, current) =>
                previous.statsStatus != current.statsStatus ||
                previous.stats != current.stats ||
                previous.statsError != current.statsError ||
                previous.awardsStatus != current.awardsStatus ||
                previous.grantedAwards != current.grantedAwards ||
                previous.awardsError != current.awardsError,
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  // ── إحصائيات ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      child: _AwardsStatsRow(stats: state.stats),
                    ),
                  ),

                  // ── أنواع الجوائز ─────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.paddingM,
                        0,
                        AppSizes.paddingM,
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'أنواع الجوائز',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.3,
                            children: AwardType.values
                                .map((type) => _AwardTypeCard(type: type))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── شهادة تقدير ───────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                      ),
                      child: _CertificateCard(
                        onGenerate: () => _showCertificateSheet(context),
                        isLoading:
                            state.certificateStatus ==
                            SubmissionStatus.submitting,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showGrantAwardSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _bloc,
        child: _GrantAwardSheet(halaqaId: widget.halaqaId),
      ),
    );
  }

  void _showCertificateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _bloc,
        child: _CertificateSheet(halaqaId: widget.halaqaId),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AwardsStatsRow
// ══════════════════════════════════════════════════════════════════════════════

class _AwardsStatsRow extends StatelessWidget {
  final AwardsStatsEntity? stats;

  const _AwardsStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(value: '${stats?.totalRecipients ?? 0}', label: 'مستفيد'),
        const SizedBox(width: 12),
        _StatChip(value: '${stats?.thisMonthCount ?? 0}', label: 'هذا الشهر'),
        const SizedBox(width: 12),
        _StatChip(
          value: '${stats?.totalAwardsCount ?? 0}',
          label: 'إجمالي الجوائز',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AwardTypeCard
// ══════════════════════════════════════════════════════════════════════════════

class _AwardTypeCard extends StatelessWidget {
  final AwardType type;

  const _AwardTypeCard({required this.type});

  Color get _color => switch (type) {
    AwardType.completionBadge => AppColors.awardCompletion,
    AwardType.performanceStars => AppColors.awardPerformance,
    AwardType.perfectAttendance => AppColors.awardAttendance,
    AwardType.studentOfWeek => AppColors.awardWeekly,
  };

  IconData get _icon => switch (type) {
    AwardType.completionBadge => Icons.verified_rounded,
    AwardType.performanceStars => Icons.star_rounded,
    AwardType.perfectAttendance => Icons.person_rounded,
    AwardType.studentOfWeek => Icons.emoji_events_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Icon(_icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            type.title,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            type.description,
            style: AppTextStyles.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _CertificateCard
// ══════════════════════════════════════════════════════════════════════════════

class _CertificateCard extends StatelessWidget {
  final VoidCallback onGenerate;
  final bool isLoading;

  const _CertificateCard({required this.onGenerate, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        children: [
          AppButton(
            label: 'إنشاء شهادة',
            isLoading: isLoading,
            onPressed: onGenerate,
            width: 130,
            height: 42,
            backgroundColor: AppColors.secondary,
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'شهادة تقدير',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.description_outlined,
                    color: AppColors.secondary,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'إنشاء وطباعة شهادات PDF لطلابك',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _GrantAwardSheet
// ══════════════════════════════════════════════════════════════════════════════

class _GrantAwardSheet extends StatefulWidget {
  final String halaqaId;

  const _GrantAwardSheet({required this.halaqaId});

  @override
  State<_GrantAwardSheet> createState() => _GrantAwardSheetState();
}

class _GrantAwardSheetState extends State<_GrantAwardSheet> {
  AwardType _type = AwardType.performanceStars;
  String? _studentId;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.user.uid : '';
    final students = context.watch<TeacherBloc>().state.students;

    return _BottomSheet(
      title: 'منح جائزة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // نوع الجائزة
          Text('نوع الجائزة', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3,
            physics: const NeverScrollableScrollPhysics(),
            children: AwardType.values.map((t) {
              final selected = t == _type;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t.title,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          Text('الطالب', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          if (students.isEmpty)
            Text(
              'لا يوجد طلاب محمّلون لهذه الحلقة',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value:
                      _studentId != null &&
                          students.any((s) => s.uid == _studentId)
                      ? _studentId
                      : null,
                  isExpanded: true,
                  hint: Text(
                    'اختر الطالب',
                    style: AppTextStyles.bodyMedium,
                  ),
                  items: students
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.uid,
                          child: Text(s.name, style: AppTextStyles.bodyMedium),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _studentId = value),
                ),
              ),
            ),

          const SizedBox(height: 16),

          Text('ملاحظة (اختياري)', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          AppTextField(hint: 'مثال: ختم جزء تبارك', controller: _noteCtrl),

          const SizedBox(height: 20),

          AppButton(
            label: 'منح الجائزة',
            onPressed: _studentId == null
                ? null
                : () {
                    final selected = students.firstWhere(
                      (s) => s.uid == _studentId,
                    );
                    context.read<AwardsBloc>().add(
                      GrantAwardEvent(
                        GrantedAwardEntity(
                          id: '',
                          studentId: _studentId!,
                          studentName: selected.name,
                          type: _type,
                          note: _noteCtrl.text.trim().isEmpty
                              ? null
                              : _noteCtrl.text.trim(),
                          grantedBy: uid,
                          halaqaId: widget.halaqaId,
                          grantedAt: DateTime.now(),
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _CertificateSheet
// ══════════════════════════════════════════════════════════════════════════════

class _CertificateSheet extends StatefulWidget {
  final String halaqaId;

  const _CertificateSheet({required this.halaqaId});

  @override
  State<_CertificateSheet> createState() => _CertificateSheetState();
}

class _CertificateSheetState extends State<_CertificateSheet> {
  final _nameCtrl = TextEditingController();
  final _achievementCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _achievementCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final teacherName = authState is AuthAuthenticated
        ? authState.user.name
        : 'المعلم';

    return _BottomSheet(
      title: 'إنشاء شهادة تقدير',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('اسم الطالب', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          AppTextField(hint: 'أحمد محمد العلي', controller: _nameCtrl),

          const SizedBox(height: 16),

          Text('الإنجاز', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          AppTextField(
            hint: 'مثال: إتمام حفظ جزء تبارك كاملاً',
            controller: _achievementCtrl,
          ),

          const SizedBox(height: 20),

          BlocBuilder<AwardsBloc, AwardsState>(
            buildWhen: (previous, current) =>
                previous.certificateStatus != current.certificateStatus,
            builder: (context, state) => AppButton(
              label: 'إنشاء وتنزيل الشهادة',
              isLoading: state.certificateStatus == SubmissionStatus.submitting,
              onPressed: () {
                if (_nameCtrl.text.isEmpty || _achievementCtrl.text.isEmpty) {
                  AppSnackBar.showError(context, 'يرجى ملء جميع الحقول');
                  return;
                }
                context.read<AwardsBloc>().add(
                  GenerateCertificateEvent(
                    CertificateDataEntity(
                      studentName: _nameCtrl.text.trim(),
                      halaqaName: 'حلقة المتقدمين',
                      academyName: 'أكاديمية رفيق للتحفيظ',
                      achievement: _achievementCtrl.text.trim(),
                      date: DateTime.now(),
                      teacherName: teacherName,
                    ),
                  ),
                );
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _BottomSheet helper
// ══════════════════════════════════════════════════════════════════════════════

class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        top: AppSizes.paddingL,
        left: AppSizes.paddingM,
        right: AppSizes.paddingM,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
