import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';
import '../widgets/supervisor_loading_skeletons.dart';

/// Transfer / add-to-second-halaqa form (UI + validation only).
/// Membership write deferred to Sprint 2.
class SupervisorTransferPage extends StatefulWidget {
  final String? preselectedStudentId;
  final String? preselectedSourceHalaqaId;

  const SupervisorTransferPage({
    super.key,
    this.preselectedStudentId,
    this.preselectedSourceHalaqaId,
  });

  @override
  State<SupervisorTransferPage> createState() => _SupervisorTransferPageState();
}

class _SupervisorTransferPageState extends State<SupervisorTransferPage> {
  bool _isMove = true;
  String? _studentId;
  String? _sourceHalaqaId;
  String? _targetHalaqaId;
  final _reasonCtrl = TextEditingController();
  String? _fieldError;

  bool _loadingRoster = false;
  String? _rosterError;
  List<SupervisorStudentRow> _roster = const [];

  @override
  void initState() {
    super.initState();
    _studentId = _trimOrNull(widget.preselectedStudentId);
    _sourceHalaqaId = _trimOrNull(widget.preselectedSourceHalaqaId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoster());
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String? _trimOrNull(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  Future<void> _loadRoster() async {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
    if (halaqat.isEmpty) {
      setState(() {
        _roster = const [];
        _loadingRoster = false;
        _rosterError = null;
      });
      return;
    }

    setState(() {
      _loadingRoster = true;
      _rosterError = null;
    });

    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    String? firstError;
    for (final h in halaqat) {
      final result = await sl<GetHalaqaStudentsUseCase>()(
        HalaqaStudentsParams(h.id),
      );
      if (!mounted) return;
      result.fold(
        (f) => firstError ??= f.message,
        (list) => byHalaqa[h.id] = list,
      );
    }

    if (!mounted) return;
    setState(() {
      _loadingRoster = false;
      _rosterError = byHalaqa.isEmpty ? firstError : null;
      _roster = SupervisorRoster.mergeSummaries(
        halaqat: halaqat,
        byHalaqaId: byHalaqa,
      );
      if (_studentId != null &&
          !_roster.any((r) => r.studentId == _studentId)) {
        _studentId = null;
      }
    });
  }

  List<HalaqaEntity> _sourceOptions(List<HalaqaEntity> halaqat) {
    final sid = _studentId;
    if (sid == null) return halaqat;
    final ids = SupervisorRoster.membershipHalaqaIds(
      halaqat: halaqat,
      studentId: sid,
    ).toSet();
    return halaqat.where((h) => ids.contains(h.id)).toList();
  }

  void _submit(List<HalaqaEntity> halaqat) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    final error = SupervisorMembershipFormValidation.transferError(
      studentId: _studentId ?? '',
      sourceHalaqaId: _sourceHalaqaId,
      targetHalaqaId: _targetHalaqaId,
      assignedHalaqat: halaqat,
      isMove: _isMove,
    );
    setState(() => _fieldError = error);
    if (error != null) return;

    final bloc = context.read<SupervisorBloc>();
    final supervisorId = auth.user.uid;
    final studentId = _studentId!;
    final target = _targetHalaqaId!;

    if (_isMove) {
      bloc.add(
        TransferStudentBetweenHalaqatEvent(
          supervisorId: supervisorId,
          studentId: studentId,
          sourceHalaqaId: _sourceHalaqaId!,
          targetHalaqaId: target,
        ),
      );
    } else {
      bloc.add(
        AdmitStudentToHalaqaEvent(
          supervisorId: supervisorId,
          halaqaId: target,
          studentId: studentId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SupervisorBloc, SupervisorState>(
          listenWhen: (p, c) =>
              p.transferStudentStatus != c.transferStudentStatus,
          listener: (context, state) {
            if (state.transferStudentStatus == SubmissionStatus.success) {
              AppSnackBar.showSuccess(context, 'تم نقل الطالب بنجاح');
              context.read<SupervisorBloc>().add(
                const ResetTransferStudentEvent(),
              );
              Navigator.of(context).maybePop();
            } else if (state.transferStudentStatus == SubmissionStatus.error) {
              AppSnackBar.showError(
                context,
                state.transferStudentError ?? 'تعذر نقل الطالب',
              );
              context.read<SupervisorBloc>().add(
                const ResetTransferStudentEvent(),
              );
            }
          },
        ),
        BlocListener<SupervisorBloc, SupervisorState>(
          listenWhen: (p, c) => p.admitStudentStatus != c.admitStudentStatus,
          listener: (context, state) {
            if (!_isMove) {
              if (state.admitStudentStatus == SubmissionStatus.success) {
                AppSnackBar.showSuccess(context, 'تمت إضافة الطالب للحلقة');
                context.read<SupervisorBloc>().add(
                  const ResetAdmitStudentEvent(),
                );
                Navigator.of(context).maybePop();
              } else if (state.admitStudentStatus == SubmissionStatus.error) {
                AppSnackBar.showError(
                  context,
                  state.admitStudentError ?? 'تعذر إضافة الطالب',
                );
                context.read<SupervisorBloc>().add(
                  const ResetAdmitStudentEvent(),
                );
              }
            }
          },
        ),
      ],
      child: SupervisorSubpageScaffold(
        title: 'نقل / إضافة طالب',
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (p, c) =>
              p.halaqat != c.halaqat ||
              p.transferStudentStatus != c.transferStudentStatus ||
              p.admitStudentStatus != c.admitStudentStatus,
          builder: (context, state) {
            final halaqat = state.halaqat;
            final sources = _sourceOptions(halaqat);
            final submitting =
                state.transferStudentStatus == SubmissionStatus.submitting ||
                (!_isMove &&
                    state.admitStudentStatus == SubmissionStatus.submitting);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'الوضع',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        label: 'نقل',
                        selected: _isMove,
                        onTap: submitting
                            ? () {}
                            : () => setState(() {
                                _isMove = true;
                                _fieldError = null;
                              }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        label: 'إضافة لحلقة ثانية',
                        selected: !_isMove,
                        onTap: submitting
                            ? () {}
                            : () => setState(() {
                                _isMove = false;
                                _fieldError = null;
                              }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loadingRoster)
                  const SizedBox(height: 280, child: SupervisorFormSkeleton())
                else if (_rosterError != null)
                  AppErrorWidget(message: _rosterError!, onRetry: _loadRoster)
                else ...[
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _studentId,
                    decoration: const InputDecoration(labelText: 'الطالب'),
                    items: [
                      for (final r in _roster)
                        DropdownMenuItem(
                          value: r.studentId,
                          child: Text(
                            r.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _roster.isEmpty || submitting
                        ? null
                        : (v) => setState(() {
                            _studentId = v;
                            _sourceHalaqaId = null;
                            _fieldError = null;
                          }),
                  ),
                  if (_isMove) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value:
                          _sourceHalaqaId != null &&
                              sources.any((h) => h.id == _sourceHalaqaId)
                          ? _sourceHalaqaId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'الحلقة المصدر',
                      ),
                      items: [
                        for (final h in sources)
                          DropdownMenuItem(
                            value: h.id,
                            child: Text(
                              h.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: sources.isEmpty || submitting
                          ? null
                          : (v) => setState(() {
                              _sourceHalaqaId = v;
                              _fieldError = null;
                            }),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _targetHalaqaId,
                    decoration: const InputDecoration(
                      labelText: 'الحلقة الهدف',
                    ),
                    items: [
                      for (final h in halaqat)
                        DropdownMenuItem(
                          value: h.id,
                          child: Text(h.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: halaqat.isEmpty || submitting
                        ? null
                        : (v) => setState(() {
                            _targetHalaqaId = v;
                            _fieldError = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonCtrl,
                    enabled: !submitting,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'السبب (اختياري)',
                    ),
                  ),
                  if (_fieldError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _fieldError!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: halaqat.isEmpty || submitting
                        ? null
                        : () => _submit(halaqat),
                    child: submitting
                        ? const Text('جاري…')
                        : Text(_isMove ? 'نقل' : 'إضافة'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
