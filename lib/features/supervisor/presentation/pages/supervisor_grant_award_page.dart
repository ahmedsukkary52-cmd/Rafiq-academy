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
import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';
import 'supervisor_awards_hub_page.dart';

class SupervisorGrantAwardPage extends StatefulWidget {
  final String? preselectedStudentId;
  final String? preselectedHalaqaId;

  const SupervisorGrantAwardPage({
    super.key,
    this.preselectedStudentId,
    this.preselectedHalaqaId,
  });

  @override
  State<SupervisorGrantAwardPage> createState() =>
      _SupervisorGrantAwardPageState();
}

class _SupervisorGrantAwardPageState extends State<SupervisorGrantAwardPage> {
  String? _studentId;
  String? _halaqaId;
  String _type = kSupervisorAwardTypeExamples.first;
  final _titleCtrl = TextEditingController();
  bool _loadingRoster = false;
  String? _rosterError;
  List<SupervisorStudentRow> _roster = const [];
  String? _formError;

  @override
  void initState() {
    super.initState();
    _studentId = _trimOrNull(widget.preselectedStudentId);
    _halaqaId = _trimOrNull(widget.preselectedHalaqaId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoster());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String? _trimOrNull(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  SupervisorStudentRow? _rowFor(String? sid) {
    if (sid == null) return null;
    for (final r in _roster) {
      if (r.studentId == sid) return r;
    }
    return null;
  }

  String _halaqaName(String id, List<HalaqaEntity> halaqat) {
    for (final h in halaqat) {
      if (h.id == id) return h.name;
    }
    return id;
  }

  Future<void> _loadRoster() async {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
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
    final roster = SupervisorRoster.mergeSummaries(
      halaqat: halaqat,
      byHalaqaId: byHalaqa,
    );
    setState(() {
      _loadingRoster = false;
      _rosterError = byHalaqa.isEmpty && halaqat.isNotEmpty ? firstError : null;
      _roster = roster;
      if (_studentId != null && _rowFor(_studentId) == null) {
        _studentId = null;
      }
      _syncHalaqaForStudent();
    });
  }

  void _syncHalaqaForStudent() {
    final row = _rowFor(_studentId);
    if (row == null || row.halaqaIds.isEmpty) return;
    if (_halaqaId == null || !row.halaqaIds.contains(_halaqaId)) {
      _halaqaId = row.halaqaIds.first;
    }
  }

  List<String> _halaqaIdsForSelected(List<HalaqaEntity> halaqat) {
    final row = _rowFor(_studentId);
    if (row != null && row.halaqaIds.isNotEmpty) return row.halaqaIds;
    return halaqat.map((h) => h.id).toList();
  }

  void _submit() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }
    final studentId = _studentId?.trim() ?? '';
    final halaqaId = _halaqaId?.trim() ?? '';
    final title = _titleCtrl.text.trim();
    if (studentId.isEmpty) {
      setState(() => _formError = 'اختر الطالب');
      return;
    }
    if (halaqaId.isEmpty) {
      setState(() => _formError = 'اختر الحلقة');
      return;
    }
    if (title.isEmpty) {
      setState(() => _formError = 'أدخل عنوان الإنجاز');
      return;
    }
    setState(() => _formError = null);
    context.read<SupervisorBloc>().add(
      IssueAchievementEvent(
        AchievementIssueEntity(
          studentId: studentId,
          type: _type,
          title: title,
          issuedBy: auth.user.uid,
          halaqaId: halaqaId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) =>
          p.issueAchievementStatus != c.issueAchievementStatus,
      listener: (context, state) {
        if (state.issueAchievementStatus == SubmissionStatus.success) {
          context.read<SupervisorBloc>().add(
            const ResetIssueAchievementEvent(),
          );
          Navigator.of(context).maybePop();
        } else if (state.issueAchievementStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.issueAchievementError ?? 'تعذر منح الإنجاز',
          );
          context.read<SupervisorBloc>().add(
            const ResetIssueAchievementEvent(),
          );
        }
      },
      child: SupervisorSubpageScaffold(
        title: 'منح جائزة',
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (p, c) =>
              p.halaqat != c.halaqat ||
              p.issueAchievementStatus != c.issueAchievementStatus,
          builder: (context, state) {
            final halaqat = state.halaqat;
            final halaqaIds = _halaqaIdsForSelected(halaqat);
            final submitting =
                state.issueAchievementStatus == SubmissionStatus.submitting;

            if (_loadingRoster) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_rosterError != null) {
              return AppErrorWidget(
                message: _rosterError!,
                onRetry: _loadRoster,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                DropdownButtonFormField<String>(
                  value: _studentId != null && _rowFor(_studentId) != null
                      ? _studentId
                      : null,
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
                  onChanged: _roster.isEmpty
                      ? null
                      : (v) => setState(() {
                          _studentId = v;
                          _formError = null;
                          _syncHalaqaForStudent();
                        }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _halaqaId != null && halaqaIds.contains(_halaqaId)
                      ? _halaqaId
                      : null,
                  decoration: const InputDecoration(labelText: 'الحلقة'),
                  items: [
                    for (final id in halaqaIds)
                      DropdownMenuItem(
                        value: id,
                        child: Text(
                          _halaqaName(id, halaqat),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: halaqaIds.isEmpty
                      ? null
                      : (v) => setState(() {
                          _halaqaId = v;
                          _formError = null;
                        }),
                ),
                const SizedBox(height: 16),
                Text(
                  'النوع',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in kSupervisorAwardTypeExamples)
                      ChoiceChip(
                        label: Text(t),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'عنوان الإنجاز'),
                  onChanged: (_) {
                    if (_formError != null) setState(() => _formError = null);
                  },
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: submitting ? null : _submit,
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('منح'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
