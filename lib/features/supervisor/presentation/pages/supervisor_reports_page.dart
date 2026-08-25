import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/supervisor_report_entity.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

class SupervisorReportsPage extends StatefulWidget {
  final bool quickCompose;

  const SupervisorReportsPage({super.key, this.quickCompose = false});

  @override
  State<SupervisorReportsPage> createState() => _SupervisorReportsPageState();
}

class _SupervisorReportsPageState extends State<SupervisorReportsPage> {
  final _contentCtrl = TextEditingController();
  String _type = 'periodic';
  String? _halaqaId;
  String? _teacherId;
  String? _formError;

  static const _types = <String, String>{
    'periodic': 'تقرير دوري',
    'incident': 'بلاغ',
    'follow_up': 'متابعة',
  };

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      setState(() => _formError = 'أدخل محتوى التقرير');
      return;
    }
    setState(() => _formError = null);

    final teacherRaw = (_teacherId ?? '').trim();
    context.read<SupervisorBloc>().add(
      SubmitSupervisorReportEvent(
        SupervisorReportEntity(
          id: '',
          supervisorId: auth.user.uid,
          halaqaId: _halaqaId,
          teacherId: teacherRaw.isEmpty ? null : teacherRaw,
          type: _type,
          content: content,
          date: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) => p.submitReportStatus != c.submitReportStatus,
      listener: (context, state) {
        if (state.submitReportStatus == SubmissionStatus.success) {
          context.read<SupervisorBloc>().add(const ResetSubmitReportEvent());
          _contentCtrl.clear();
          if (widget.quickCompose) {
            Navigator.of(context).maybePop();
          }
        } else if (state.submitReportStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.submitReportError ?? 'تعذر إرسال التقرير',
          );
          context.read<SupervisorBloc>().add(const ResetSubmitReportEvent());
        }
      },
      child: SupervisorSubpageScaffold(
        title: widget.quickCompose ? 'تقرير سريع' : 'التقارير',
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (p, c) =>
              p.halaqat != c.halaqat ||
              p.submitReportStatus != c.submitReportStatus,
          builder: (context, state) {
            final halaqat = state.halaqat;
            final submitting =
                state.submitReportStatus == SubmissionStatus.submitting;
            final teacherIds = <String>{
              for (final h in halaqat)
                if (h.teacherId.trim().isNotEmpty) h.teacherId.trim(),
            }.toList()..sort();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (!widget.quickCompose) ...[
                  Text(
                    'رفع تقرير أو بلاغ للإدارة',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'نوع التقرير',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _types.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _type == entry.key,
                        onSelected: (_) => setState(() => _type = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: _halaqaId,
                  decoration: const InputDecoration(
                    labelText: 'الحلقة (اختياري)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— بدون حلقة —'),
                    ),
                    for (final h in halaqat)
                      DropdownMenuItem<String?>(
                        value: h.id,
                        child: Text(h.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _halaqaId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: _teacherId != null && teacherIds.contains(_teacherId)
                      ? _teacherId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'المعلم (اختياري)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— بدون معلم —'),
                    ),
                    for (final id in teacherIds)
                      DropdownMenuItem<String?>(
                        value: id,
                        child: Text(id, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _teacherId = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contentCtrl,
                  maxLines: widget.quickCompose ? 5 : 8,
                  decoration: const InputDecoration(
                    labelText: 'المحتوى',
                    alignLabelWithHint: true,
                  ),
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
                      : const Text('إرسال'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
