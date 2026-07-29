import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/absence_request_projection.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/repositories/parent_repositories.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';

/// W7 Slice 1 — parent استئذان submit + list own requests.
///
/// Contextual only: never reads/writes attendance. Authorization and
/// deterministic ids live in [SubmitAbsenceRequestUseCase].
class ParentAbsenceRequestsPage extends StatefulWidget {
  const ParentAbsenceRequestsPage({super.key});

  @override
  State<ParentAbsenceRequestsPage> createState() =>
      _ParentAbsenceRequestsPageState();
}

class _ParentAbsenceRequestsPageState extends State<ParentAbsenceRequestsPage> {
  final _reasonController = TextEditingController();
  String? _formStudentId;
  String? _formHalaqaId;
  DateTime _formDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String? get _parentId {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return null;
    return auth.user.uid;
  }

  void _bootstrap() {
    final parentId = _parentId;
    if (parentId == null) return;
    final bloc = context.read<ParentBloc>();
    if (bloc.state.childrenStatus != SectionStatus.loaded) {
      bloc.add(LoadChildrenEvent(parentId));
    }
    bloc.add(LoadAbsenceRequestsEvent(parentId));
  }

  void _refresh() {
    final parentId = _parentId;
    if (parentId == null) return;
    context.read<ParentBloc>().add(LoadAbsenceRequestsEvent(parentId));
  }

  void _onChildrenReady(ParentState state) {
    if (_formStudentId != null) return;
    if (state.childrenIds.isEmpty) return;
    final selected = state.selectedChildId ?? state.childrenIds.first;
    _selectFormStudent(selected);
  }

  void _selectFormStudent(String studentId) {
    final parentId = _parentId;
    if (parentId == null) return;
    setState(() {
      _formStudentId = studentId;
      _formHalaqaId = null;
    });
    context.read<ParentBloc>().add(
      LoadStudentHalaqatEvent(parentId: parentId, studentId: studentId),
    );
  }

  void _submit() {
    final parentId = _parentId;
    final studentId = _formStudentId;
    final halaqaId = _formHalaqaId;
    if (parentId == null || studentId == null || halaqaId == null) return;

    context.read<ParentBloc>().add(
      SubmitAbsenceRequestEvent(
        AbsenceRequestEntity(
          id: '',
          studentId: studentId,
          halaqaId: halaqaId,
          requestedBy: parentId,
          date: _formDate,
          reason: _reasonController.text,
          status: AbsenceRequestStatus.pending,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('طلبات الاستئذان')),
      body: BlocConsumer<ParentBloc, ParentState>(
        listenWhen: (prev, curr) =>
            prev.childrenStatus != curr.childrenStatus ||
            prev.childrenIds != curr.childrenIds ||
            prev.studentHalaqatStatus != curr.studentHalaqatStatus ||
            prev.studentHalaqat != curr.studentHalaqat ||
            prev.absenceSubmissionStatus != curr.absenceSubmissionStatus,
        listener: (context, state) {
          if (state.childrenStatus == SectionStatus.loaded) {
            _onChildrenReady(state);
          }

          if (state.studentHalaqatStatus == SectionStatus.loaded &&
              state.studentHalaqatStudentId == _formStudentId &&
              _formHalaqaId == null &&
              state.studentHalaqat.isNotEmpty) {
            setState(() => _formHalaqaId = state.studentHalaqat.first.id);
          }

          if (state.absenceSubmissionStatus == SubmissionStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم إرسال طلب الاستئذان')),
            );
            _reasonController.clear();
            context.read<ParentBloc>().add(const ResetAbsenceSubmissionEvent());
          } else if (state.absenceSubmissionStatus == SubmissionStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.absenceSubmissionError ?? 'تعذر إرسال الطلب',
                ),
              ),
            );
            context.read<ParentBloc>().add(const ResetAbsenceSubmissionEvent());
          }
        },
        builder: (context, state) {
          if (state.childrenStatus == SectionStatus.initial ||
              state.childrenStatus == SectionStatus.loading) {
            return const AppLoadingWidget();
          }

          if (state.childrenStatus == SectionStatus.error) {
            return AppErrorWidget(
              message: state.childrenError ?? 'حدث خطأ',
              onRetry: _bootstrap,
            );
          }

          if (state.childrenIds.isEmpty) {
            return const _EmptyChildrenForAbsence();
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              children: [
                _SubmitFormCard(
                  state: state,
                  studentId: _formStudentId,
                  halaqaId: _formHalaqaId,
                  date: _formDate,
                  reasonController: _reasonController,
                  onStudentChanged: _selectFormStudent,
                  onHalaqaChanged: (id) => setState(() => _formHalaqaId = id),
                  onDateTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _formDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 7),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) setState(() => _formDate = picked);
                  },
                  onSubmit: _submit,
                  onRetryHalaqat: () {
                    final parentId = _parentId;
                    final studentId = _formStudentId;
                    if (parentId == null || studentId == null) return;
                    context.read<ParentBloc>().add(
                      LoadStudentHalaqatEvent(
                        parentId: parentId,
                        studentId: studentId,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSizes.paddingL),
                const Text(
                  'نتائج طلباتي',
                  style: AppTextStyles.headlineMedium,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  'الحالة تُعرض من سجل الاستئذان الحالي — وليست بديلاً عن سجل الحضور.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                _RequestsSection(state: state, onRetry: _refresh),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubmitFormCard extends StatelessWidget {
  final ParentState state;
  final String? studentId;
  final String? halaqaId;
  final DateTime date;
  final TextEditingController reasonController;
  final ValueChanged<String> onStudentChanged;
  final ValueChanged<String> onHalaqaChanged;
  final VoidCallback onDateTap;
  final VoidCallback onSubmit;
  final VoidCallback onRetryHalaqat;

  const _SubmitFormCard({
    required this.state,
    required this.studentId,
    required this.halaqaId,
    required this.date,
    required this.reasonController,
    required this.onStudentChanged,
    required this.onHalaqaChanged,
    required this.onDateTap,
    required this.onSubmit,
    required this.onRetryHalaqat,
  });

  @override
  Widget build(BuildContext context) {
    final submitting =
        state.absenceSubmissionStatus == SubmissionStatus.submitting;
    final canSubmit =
        !submitting &&
        studentId != null &&
        halaqaId != null &&
        state.studentHalaqatStatus == SectionStatus.loaded;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تقديم استئذان',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            'الطلب معلومة سياقية للمعلم — لا يغيّر سجل الحضور تلقائياً.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: AppSizes.paddingM),
          const Text('الابن', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          _PickerShell(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: studentId,
                items: [
                  for (final id in state.childrenIds)
                    DropdownMenuItem(
                      value: id,
                      child: Text(_childLabel(state, id)),
                    ),
                ],
                onChanged: submitting
                    ? null
                    : (v) {
                        if (v != null) onStudentChanged(v);
                      },
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          const Text('الحلقة', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          _HalaqaField(
            state: state,
            halaqaId: halaqaId,
            enabled: !submitting,
            onChanged: onHalaqaChanged,
            onRetry: onRetryHalaqat,
          ),
          const SizedBox(height: AppSizes.paddingM),
          const Text('اليوم', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: submitting ? null : onDateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textHint,
                    size: 18,
                  ),
                  Text(formatDateDmy(date), style: AppTextStyles.bodyLarge),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          const Text('السبب', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: reasonController,
            enabled: !submitting,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'اكتب سبب الاستئذان',
              filled: true,
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: canSubmit ? onSubmit : null,
              child: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إرسال الطلب'),
            ),
          ),
        ],
      ),
    );
  }

  static String _childLabel(ParentState state, String id) {
    if (state.weeklyReport != null &&
        state.weeklyReport!.studentId == id &&
        state.weeklyReport!.studentName.trim().isNotEmpty) {
      return state.weeklyReport!.studentName.trim();
    }
    return 'طالب';
  }
}

class _HalaqaField extends StatelessWidget {
  final ParentState state;
  final String? halaqaId;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onRetry;

  const _HalaqaField({
    required this.state,
    required this.halaqaId,
    required this.enabled,
    required this.onChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.studentHalaqatStatus == SectionStatus.initial ||
        state.studentHalaqatStatus == SectionStatus.loading) {
      return const SizedBox(height: 48, child: AppLoadingWidget());
    }

    if (state.studentHalaqatStatus == SectionStatus.error) {
      return AppErrorWidget(
        message: state.studentHalaqatError ?? 'تعذر تحميل الحلقات',
        onRetry: onRetry,
      );
    }

    if (state.studentHalaqat.isEmpty) {
      return Text(
        'لا توجد حلقات مرتبطة بهذا الابن',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        textAlign: TextAlign.right,
      );
    }

    return _PickerShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: halaqaId,
          items: [
            for (final ParentHalaqaOption h in state.studentHalaqat)
              DropdownMenuItem(value: h.id, child: Text(h.name)),
          ],
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
        ),
      ),
    );
  }
}

class _PickerShell extends StatelessWidget {
  final Widget child;

  const _PickerShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: child,
    );
  }
}

class _RequestsSection extends StatelessWidget {
  final ParentState state;
  final VoidCallback onRetry;

  const _RequestsSection({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (state.absenceRequestsStatus == SectionStatus.initial ||
        state.absenceRequestsStatus == SectionStatus.loading) {
      return const SizedBox(height: 160, child: AppLoadingWidget());
    }

    if (state.absenceRequestsStatus == SectionStatus.error) {
      return AppErrorWidget(
        message: state.absenceRequestsError ?? 'تعذر تحميل الطلبات',
        onRetry: onRetry,
      );
    }

    if (state.absenceRequests.isEmpty) {
      return const _EmptyRequests();
    }

    return Column(
      children: [
        for (final request in state.absenceRequests)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RequestTile(request: request),
          ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  final AbsenceRequestEntity request;

  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final reviewedBy = request.reviewedBy?.trim() ?? '';
    final decided = AbsenceRequestProjection.isDecided(request);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatusChip(status: request.status),
              const Spacer(),
              Text(
                formatDateDmy(request.date),
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.reason,
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            'طالب: ${request.studentId}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.right,
          ),
          Text(
            'حلقة: ${request.halaqaId}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.right,
          ),
          if (decided && reviewedBy.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'قرار المعلم: ${AbsenceRequestProjection.statusLabel(request.status)} · راجع $reviewedBy',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AbsenceRequestStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = AbsenceRequestProjection.statusLabel(status);
    final color = switch (status) {
      AbsenceRequestStatus.pending => AppColors.warning,
      AbsenceRequestStatus.approved => AppColors.success,
      AbsenceRequestStatus.rejected => AppColors.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 40,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد طلبات استئذان بعد',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'بعد الإرسال والمراجعة ستظهر نتيجة كل طلب هنا من سجل الاستئذان.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyChildrenForAbsence extends StatelessWidget {
  const _EmptyChildrenForAbsence();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom_rounded,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد طلاب مرتبطون بهذا الحساب بعد',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'لا يمكن تقديم استئذان قبل ربط الأبناء بحسابك.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
