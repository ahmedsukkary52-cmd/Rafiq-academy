import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/absence_request.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../utils/teacher_workflow_ownership.dart';
import '../widgets/excuses/teacher_excuse_list_item_data.dart';
import '../widgets/excuses/teacher_excuse_request_card.dart';
import '../widgets/excuses/teacher_excuses_history_skeleton.dart';
import '../widgets/teacher_pending_absence_section.dart';

/// Teacher استئذان inbox — reviews parent requests for owned halaqat.
///
/// Preview args remain for isolated UI previews only.
class TeacherExcusesPage extends StatefulWidget {
  final List<TeacherExcuseListItemData>? previewItems;
  final List<String>? previewHalaqaOptions;
  final bool previewLoading;

  const TeacherExcusesPage({
    super.key,
    this.previewItems,
    this.previewHalaqaOptions,
    this.previewLoading = false,
  });

  @override
  State<TeacherExcusesPage> createState() => _TeacherExcusesPageState();
}

class _TeacherExcusesPageState extends State<TeacherExcusesPage> {
  late DateTime _selectedDate;
  String? _selectedHalaqaId;

  bool get _isPreview =>
      widget.previewItems != null ||
      widget.previewHalaqaOptions != null ||
      widget.previewLoading;

  @override
  void initState() {
    super.initState();
    _selectedDate = AttendancePolicy.dayStart(DateTime.now());
    if (_isPreview) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  String? _teacherUid() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) return auth.user.uid;
    return null;
  }

  void _bootstrap() {
    final teacherId = _teacherUid();
    if (teacherId == null || teacherId.isEmpty) return;
    final bloc = context.read<TeacherBloc>();
    if (bloc.state.halaqat.isEmpty) {
      bloc.add(LoadTeacherHalaqatEvent(teacherId));
    }
    _syncSelection(bloc.state);
  }

  void _syncSelection(TeacherState state) {
    if (state.halaqat.isEmpty) return;
    final current = _selectedHalaqaId;
    final stillValid =
        current != null && state.halaqat.any((h) => h.id == current);
    final nextId = stillValid ? current : state.halaqat.first.id;
    if (_selectedHalaqaId != nextId) {
      setState(() => _selectedHalaqaId = nextId);
    }
    _loadPending(nextId);
  }

  void _loadPending(String halaqaId) {
    final teacherId = _teacherUid();
    if (teacherId == null || teacherId.isEmpty) return;
    final bloc = context.read<TeacherBloc>();
    bloc.add(LoadHalaqaStudentsEvent(halaqaId));
    bloc.add(
      LoadPendingAbsenceRequestsEvent(
        teacherId: teacherId,
        halaqaId: halaqaId,
        date: _selectedDate,
      ),
    );
  }

  String _studentNameFor(
    String studentId,
    List<HalaqaStudentSummaryEntity> students,
  ) {
    for (final s in students) {
      if (s.uid == studentId) {
        final name = s.name.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return 'طالب';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = AttendancePolicy.dayStart(picked));
    final halaqaId = _selectedHalaqaId;
    if (halaqaId != null) _loadPending(halaqaId);
  }

  String _hijriLabel(DateTime date) {
    HijriCalendar.setLocal('ar');
    return HijriCalendar.fromDate(date).toFormat('dd MMMM yyyy');
  }

  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher');
    }
  }

  void _onAbsenceReviewStatusChanged(TeacherState state) {
    if (state.absenceReviewStatus == SubmissionStatus.success) {
      AppSnackBar.showSuccess(context, 'تم تحديث طلب الاستئذان');
      context.read<TeacherBloc>().add(const ResetAbsenceReviewEvent());
    } else if (state.absenceReviewStatus == SubmissionStatus.error &&
        state.absenceReviewError != null) {
      AppSnackBar.showError(context, state.absenceReviewError!);
      context.read<TeacherBloc>().add(const ResetAbsenceReviewEvent());
    }
  }

  void _review(AbsenceRequestEntity request, AbsenceRequestStatus decision) {
    if (!TeacherWorkflowOwnership.canExecute(context)) return;
    final teacherId = _teacherUid();
    final halaqaId = _selectedHalaqaId;
    if (teacherId == null || teacherId.isEmpty || halaqaId == null) {
      AppSnackBar.showError(context, 'تعذر تحديد الحلقة أو هوية المعلم');
      return;
    }
    context.read<TeacherBloc>().add(
      ReviewAbsenceRequestEvent(
        requestId: request.id,
        halaqaId: halaqaId,
        teacherId: teacherId,
        decision: decision,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreview) return _previewScaffold();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MultiBlocListener(
        listeners: [
          BlocListener<TeacherBloc, TeacherState>(
            listenWhen: (p, c) => p.halaqat != c.halaqat,
            listener: (_, state) => _syncSelection(state),
          ),
          BlocListener<TeacherBloc, TeacherState>(
            listenWhen: (p, c) =>
                p.absenceReviewStatus != c.absenceReviewStatus,
            listener: (_, state) => _onAbsenceReviewStatusChanged(state),
          ),
        ],
        child: Scaffold(
          backgroundColor: const Color(0xFFF5FAFB),
          body: Column(
            children: [
              _ExcusesHeader(onBack: _onBack),
              Expanded(child: _liveBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveBody() {
    return BlocBuilder<TeacherBloc, TeacherState>(
      buildWhen: (p, c) =>
          p.halaqat != c.halaqat ||
          p.halaqatStatus != c.halaqatStatus ||
          p.halaqatError != c.halaqatError ||
          p.students != c.students ||
          p.studentsHalaqaId != c.studentsHalaqaId ||
          p.pendingAbsenceRequests != c.pendingAbsenceRequests ||
          p.pendingAbsenceRequestsStatus != c.pendingAbsenceRequestsStatus ||
          p.pendingAbsenceRequestsError != c.pendingAbsenceRequestsError ||
          p.absenceReviewStatus != c.absenceReviewStatus,
      builder: (context, state) {
        if (state.halaqatStatus == SectionStatus.loading ||
            state.halaqatStatus == SectionStatus.initial) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: TeacherExcusesHistorySkeleton(),
          );
        }
        if (state.halaqatStatus == SectionStatus.error) {
          return AppErrorWidget(
            message: state.halaqatError ?? 'تعذر تحميل الحلقات',
            onRetry: _bootstrap,
          );
        }
        if (state.halaqat.isEmpty) {
          return const Center(child: Text('لا توجد حلقات مسندة'));
        }

        final halaqaId = _selectedHalaqaId ?? state.halaqat.first.id;
        final canWrite = TeacherWorkflowOwnership.canExecute(context);
        final roster = state.studentsHalaqaId == halaqaId
            ? state.students
            : const <HalaqaStudentSummaryEntity>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            _DateHalaqaBar(
              dateLabel: _hijriLabel(_selectedDate),
              halaqaNames: {for (final h in state.halaqat) h.id: h.name},
              selectedHalaqaId: halaqaId,
              onDateTap: _pickDate,
              onHalaqaChanged: (id) {
                setState(() => _selectedHalaqaId = id);
                _loadPending(id);
              },
            ),
            const SizedBox(height: 16),
            TeacherPendingAbsenceSection(
              status: state.pendingAbsenceRequestsStatus,
              requests: state.pendingAbsenceRequestsHalaqaId == halaqaId
                  ? state.pendingAbsenceRequests
                  : const [],
              error: state.pendingAbsenceRequestsError,
              canReview: canWrite,
              reviewing:
                  state.absenceReviewStatus == SubmissionStatus.submitting,
              studentName: (id) => _studentNameFor(id, roster),
              onRetry: () => _loadPending(halaqaId),
              onReview: _review,
            ),
          ],
        );
      },
    );
  }

  Widget _previewScaffold() {
    final items = widget.previewItems ?? const <TeacherExcuseListItemData>[];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAFB),
        body: Column(
          children: [
            _ExcusesHeader(onBack: _onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  if (widget.previewLoading)
                    const TeacherExcusesHistorySkeleton()
                  else if (items.isEmpty)
                    const Text('لا توجد طلبات')
                  else
                    for (final item in items) ...[
                      TeacherExcuseRequestCard(item: item),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExcusesHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ExcusesHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: AppColors.surface,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, top + 12, 18, 13),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE8EEF0), width: 0.8),
          ),
        ),
        child: Row(
          children: [
            Material(
              color: const Color(0xFFF5FAFB),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'طلبات الاعتذار',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }
}

class _DateHalaqaBar extends StatelessWidget {
  final String dateLabel;
  final Map<String, String> halaqaNames;
  final String selectedHalaqaId;
  final VoidCallback onDateTap;
  final ValueChanged<String> onHalaqaChanged;

  const _DateHalaqaBar({
    required this.dateLabel,
    required this.halaqaNames,
    required this.selectedHalaqaId,
    required this.onDateTap,
    required this.onHalaqaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onDateTap,
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in halaqaNames.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: e.key == selectedHalaqaId,
                  onSelected: (_) => onHalaqaChanged(e.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
