import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/domain/meeting_link_policy.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/meeting_link_dialog.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../admin/domain/entities/admin_operations_entities.dart';
import '../../../admin/domain/usecases/admin_operations_usecases.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';
import '../widgets/supervisor_subpage_scaffold.dart';
import '../widgets/supervisor_loading_skeletons.dart';

class SupervisorHalaqaDetailPage extends StatefulWidget {
  final String halaqaId;

  const SupervisorHalaqaDetailPage({super.key, required this.halaqaId});

  @override
  State<SupervisorHalaqaDetailPage> createState() =>
      _SupervisorHalaqaDetailPageState();
}

class _SupervisorHalaqaDetailPageState
    extends State<SupervisorHalaqaDetailPage> {
  bool _loadingStudents = false;
  String? _studentsError;
  List<HalaqaStudentSummaryEntity> _students = const [];
  String _query = '';
  bool _showStudents = false;
  bool _savingLink = false;

  /// Supervisors may only add a link while none is stored (B14); the
  /// callable enforces this and the halaqa scope.
  Future<void> _addMeetingLink(HalaqaEntity halaqa) async {
    if (_savingLink) return;
    final result = await showMeetingLinkDialog(
      context,
      currentLink: halaqa.meetingLink,
      canClear: false,
    );
    if (result == null || result.clear || !mounted) return;
    setState(() => _savingLink = true);
    final outcome = await sl<SetHalaqaMeetingLinkUseCase>()(
      SetHalaqaMeetingLinkParams(
        halaqaId: halaqa.id,
        meetingLink: result.link!,
      ),
    );
    if (!mounted) return;
    setState(() => _savingLink = false);
    outcome.fold(
      (f) => AppSnackBar.showError(context, 'لم يُحفظ الرابط: ${f.message}'),
      (change) {
        AppSnackBar.showSuccess(context, meetingLinkChangeMessage(change));
        final auth = context.read<AuthBloc>().state;
        if (auth is AuthAuthenticated) {
          context.read<SupervisorBloc>().add(
            LoadSupervisedHalaqatEvent(auth.user.uid),
          );
        }
      },
    );
  }

  HalaqaEntity? _find(List<HalaqaEntity> list) {
    for (final h in list) {
      if (h.id == widget.halaqaId) return h;
    }
    return null;
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loadingStudents = true;
      _studentsError = null;
      _showStudents = true;
    });
    final result = await sl<GetHalaqaStudentsUseCase>()(
      HalaqaStudentsParams(widget.halaqaId),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loadingStudents = false;
        _studentsError = f.message;
      }),
      (list) => setState(() {
        _loadingStudents = false;
        _students = list;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupervisorBloc, SupervisorState>(
      buildWhen: (p, c) => p.halaqat != c.halaqat,
      builder: (context, state) {
        final halaqa = _find(state.halaqat);
        if (halaqa == null) {
          return SupervisorSubpageScaffold(
            title: 'الحلقة',
            body: Center(
              child: Text(
                'الحلقة غير موجودة ضمن نطاق إشرافك',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
          );
        }

        final filtered = _query.trim().isEmpty
            ? _students
            : _students
                  .where(
                    (s) =>
                        s.name.contains(_query.trim()) ||
                        s.uid.contains(_query.trim()),
                  )
                  .toList();

        return SupervisorSubpageScaffold(
          title: halaqa.name,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  _StatusBadge(status: halaqa.status),
                  const Spacer(),
                  Text(
                    '${halaqa.studentIds.length} طالب',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionChip(
                    icon: Icons.groups_outlined,
                    label: 'الطلاب',
                    onTap: _loadStudents,
                  ),
                  _ActionChip(
                    icon: Icons.fact_check_outlined,
                    label: 'الحضور',
                    onTap: () => SupervisorDestinations.attendance(
                      context,
                      halaqaId: halaqa.id,
                    ),
                  ),
                  _ActionChip(
                    icon: Icons.swap_horiz_rounded,
                    label: 'نقل',
                    onTap: () => SupervisorDestinations.transfer(
                      context,
                      sourceHalaqaId: halaqa.id,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SupervisorMeetingLinkCard(
                link: halaqa.meetingLink.trim(),
                saving: _savingLink,
                onAdd: () => _addMeetingLink(halaqa),
              ),
              if (_showStudents) ...[
                const SizedBox(height: 20),
                Text(
                  'طلاب الحلقة',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'تصفية بالاسم أو المعرّف',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                if (_loadingStudents)
                  const SizedBox(
                    height: 220,
                    child: SupervisorListCardsSkeleton(itemCount: 3),
                  )
                else if (_studentsError != null)
                  AppErrorWidget(
                    message: _studentsError!,
                    onRetry: _loadStudents,
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'لا يوجد طلاب',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.name.trim().isEmpty ? 'طالب' : s.name),
                      subtitle: Text(
                        s.isAtRisk
                            ? 'في خطر'
                            : 'حضور ${s.attendancePercent.toStringAsFixed(0)}%',
                      ),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => SupervisorDestinations.studentProfile(
                        context,
                        studentId: s.uid,
                        halaqaId: halaqa.id,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SupervisorMeetingLinkCard extends StatelessWidget {
  final String link;
  final bool saving;
  final VoidCallback onAdd;

  const _SupervisorMeetingLinkCard({
    required this.link,
    required this.saving,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final valid = joinableMeetingUri(link) != null;
    final (title, note) = link.isEmpty
        ? (
            'لم يُضبط رابط الاجتماع بعد',
            'أضف رابط الاجتماع ليتمكن الطلاب من الانضمام.',
          )
        : valid
        ? ('رابط الاجتماع مضبوط', 'تعديل الرابط أو حذفه متاح للمسؤول.')
        : ('رابط الاجتماع المحفوظ غير صالح', 'تواصل مع المسؤول لتحديث الرابط.');
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.videocam_outlined,
                color: link.isNotEmpty && valid
                    ? AppColors.primary
                    : AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (link.isNotEmpty && valid) ...[
            const SizedBox(height: 6),
            Text(
              link,
              textDirection: TextDirection.ltr,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            note,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
          ),
          if (link.isEmpty) ...[
            const SizedBox(height: 8),
            AppButton(
              key: const Key('supervisorAddMeetingLink'),
              label: 'إضافة رابط',
              height: 40,
              isLoading: saving,
              onPressed: saving ? null : onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status.trim().toLowerCase() == 'active';
    final label = active ? 'نشطة' : (status.trim().isEmpty ? '—' : status);
    final bg = active ? const Color(0xFFE8F5E9) : AppColors.surfaceGrey;
    final fg = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
