import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/academy_membership_invariant.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../shared/domain/halaqa_entity.dart';
import '../../../student_search/data/datasources/student_search_remote_datasource.dart';
import '../../../student_search/domain/entities/student_search_entry.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_loading_skeletons.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

/// Admit an existing student into an assigned halaqa (no identity creation).
class SupervisorRegisterPage extends StatefulWidget {
  final String? preselectedHalaqaId;

  const SupervisorRegisterPage({super.key, this.preselectedHalaqaId});

  @override
  State<SupervisorRegisterPage> createState() => _SupervisorRegisterPageState();
}

class _SupervisorRegisterPageState extends State<SupervisorRegisterPage> {
  /// Holds the selected student's id for validation; never typed by the user.
  final _studentIdCtrl = TextEditingController();
  final _queryCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<StudentSearchEntry> _hits = const [];
  StudentSearchEntry? _selected;
  String? _halaqaId;
  String? _fieldError;

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final query = value.trim();
      final auth = context.read<AuthBloc>().state;
      if (query.length < 2 || auth is! AuthAuthenticated) {
        setState(() => _hits = const []);
        return;
      }
      setState(() => _searching = true);
      try {
        final hits = await StudentSearchRemoteDatasourceImpl(
          firestore: sl<FirebaseFirestore>(),
        ).searchInViewerScope(viewerUid: auth.user.uid, query: query);
        if (mounted && _queryCtrl.text.trim() == query) {
          setState(() => _hits = hits);
        }
      } catch (_) {
        if (mounted) setState(() => _hits = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _halaqaId = widget.preselectedHalaqaId?.trim();
    if (_halaqaId != null && _halaqaId!.isEmpty) _halaqaId = null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _studentIdCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
    final error = SupervisorMembershipFormValidation.registerError(
      studentId: _studentIdCtrl.text,
      targetHalaqaId: _halaqaId,
      assignedHalaqat: halaqat,
    );
    if (error != null) {
      setState(() => _fieldError = error);
      return;
    }
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول أولاً');
      return;
    }
    setState(() => _fieldError = null);
    context.read<SupervisorBloc>().add(
      AdmitStudentToHalaqaEvent(
        supervisorId: auth.user.uid,
        halaqaId: _halaqaId!,
        studentId: _studentIdCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) => p.admitStudentStatus != c.admitStudentStatus,
      listener: (context, state) {
        if (state.admitStudentStatus == SubmissionStatus.success) {
          if (state.admitStudentRosterRefreshFailed) {
            AppSnackBar.showInfo(
              context,
              'تم قبول الطالب، لكن تعذر تحديث القائمة: ${state.halaqatError ?? 'حاول التحديث لاحقاً'}',
            );
            // Keep the form open so the supervisor can retry or refresh.
            context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
          } else {
            AppSnackBar.showSuccess(context, 'تم قبول الطالب في الحلقة');
            context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
            Navigator.of(context).maybePop();
          }
        } else if (state.admitStudentStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.admitStudentError ?? 'تعذر قبول الطالب',
          );
          context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
        }
      },
      child: SupervisorSubpageScaffold(
        title: 'إسناد طالب موجود',
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (p, c) =>
              p.halaqat != c.halaqat ||
              p.admitStudentStatus != c.admitStudentStatus,
          builder: (context, state) {
            if (state.halaqatStatus == SectionStatus.loading &&
                state.halaqat.isEmpty) {
              return const SupervisorFormSkeleton();
            }

            final submitting =
                state.admitStudentStatus == SubmissionStatus.submitting;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'إسناد طالب مسجّل مسبقاً لحلقة تشرف عليها',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ابحث عن الطالب باسمه من طلاب حلقاتك واختر حلقة ضمن نطاق إشرافك. '
                        'لا يتم إنشاء حساب جديد من هذه الشاشة. '
                        'الحد الأقصى ${_eastern('${AcademyMembershipInvariant.maxHalaqatPerStudent}')} حلقات للطالب.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_selected != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                      ),
                      title: Text(_selected!.fullName),
                      subtitle: Text(
                        _selected!.halaqaName.isEmpty
                            ? 'الطالب المختار'
                            : 'الحلقة الحالية: ${_selected!.halaqaName}',
                      ),
                      trailing: TextButton(
                        onPressed: submitting
                            ? null
                            : () => setState(() {
                                _selected = null;
                                _studentIdCtrl.clear();
                              }),
                        child: const Text('تغيير'),
                      ),
                    ),
                  )
                else ...[
                  TextField(
                    key: const Key('supervisor-admit-search'),
                    controller: _queryCtrl,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'ابحث باسم الطالب',
                      hintText: 'من طلاب حلقاتك',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _onQuery,
                  ),
                  if (_searching) const LinearProgressIndicator(),
                  if (!_searching &&
                      _queryCtrl.text.trim().length >= 2 &&
                      _hits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'لا نتائج ضمن طلاب حلقاتك. الطلاب الجدد يسجّلهم مسؤول الأكاديمية.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final hit in _hits)
                    ListTile(
                      key: Key('supervisor-admit-${hit.studentId}'),
                      leading: const Icon(Icons.person_outline),
                      title: Text(hit.fullName),
                      subtitle: hit.halaqaName.isEmpty
                          ? null
                          : Text(hit.halaqaName),
                      onTap: () => setState(() {
                        _selected = hit;
                        _studentIdCtrl.text = hit.studentId;
                        _fieldError = null;
                      }),
                    ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_halaqaId ?? 'none'),
                  initialValue: _resolveHalaqa(state.halaqat),
                  decoration: const InputDecoration(
                    labelText: 'الحلقة',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: [
                    for (final h in state.halaqat)
                      DropdownMenuItem(
                        value: h.id,
                        child: Text(
                          '${h.name} (${h.studentIds.length} طالب)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: submitting
                      ? null
                      : (id) => setState(() {
                          _halaqaId = id;
                          _fieldError = null;
                        }),
                ),
                if (_fieldError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _fieldError!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: submitting ? null : _submit,
                  child: Text(submitting ? 'جاري…' : 'قبول في الحلقة'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _resolveHalaqa(List<HalaqaEntity> halaqat) {
    final current = _halaqaId;
    if (current != null && halaqat.any((h) => h.id == current)) {
      return current;
    }
    return null;
  }

  String _eastern(String input) {
    const western = '0123456789';
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final code in input.runes) {
      final ch = String.fromCharCode(code);
      final i = western.indexOf(ch);
      buffer.write(i >= 0 ? eastern[i] : ch);
    }
    return buffer.toString();
  }
}
