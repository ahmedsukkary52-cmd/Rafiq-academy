import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/achievement_issue_entity.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';

@visibleForTesting
class IssueAchievementDialog extends StatefulWidget {
  final List<String> studentIds;
  final String halaqaId;
  final String issuedBy;
  final List<String> achievementTypes;
  final ValueChanged<AchievementIssueEntity> onSubmit;
  final Future<Map<String, String>> Function(List<String> ids)?
  loadStudentNames;

  const IssueAchievementDialog({
    super.key,
    required this.studentIds,
    required this.halaqaId,
    required this.issuedBy,
    required this.achievementTypes,
    required this.onSubmit,
    this.loadStudentNames,
  });

  @override
  State<IssueAchievementDialog> createState() => _IssueAchievementDialogState();
}

class _IssueAchievementDialogState extends State<IssueAchievementDialog> {
  final _titleCtrl = TextEditingController();
  final _manualStudentCtrl = TextEditingController();
  String? _studentId;
  late String _type;
  Map<String, String> _studentNames = const {};

  @override
  void initState() {
    super.initState();
    _type = widget.achievementTypes.first;
    if (widget.studentIds.length == 1) {
      _studentId = widget.studentIds.first;
    }
    _resolveStudentNames();
  }

  Future<void> _resolveStudentNames() async {
    final load = widget.loadStudentNames;
    if (load == null || widget.studentIds.isEmpty) return;
    try {
      final names = await load(widget.studentIds);
      if (mounted) setState(() => _studentNames = names);
    } catch (_) {
      // Names are cosmetic; the dropdown falls back to the raw id.
    }
  }

  String _studentLabel(String id) {
    final name = _studentNames[id]?.trim() ?? '';
    return name.isEmpty ? id : name;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _manualStudentCtrl.dispose();
    super.dispose();
  }

  String? get _resolvedStudentId {
    if (widget.studentIds.isNotEmpty) return _studentId;
    final manual = _manualStudentCtrl.text.trim();
    return manual.isEmpty ? null : manual;
  }

  void _submit() {
    final studentId = _resolvedStudentId;
    final title = _titleCtrl.text.trim();
    if (studentId == null || title.isEmpty) return;

    widget.onSubmit(
      AchievementIssueEntity(
        studentId: studentId,
        type: _type,
        title: title,
        issuedBy: widget.issuedBy,
        halaqaId: widget.halaqaId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupervisorBloc, SupervisorState>(
      buildWhen: (prev, curr) =>
          prev.issueAchievementStatus != curr.issueAchievementStatus,
      builder: (context, state) {
        final submitting =
            state.issueAchievementStatus == SubmissionStatus.submitting;
        final canSubmit =
            _resolvedStudentId != null && _titleCtrl.text.trim().isNotEmpty;

        return AlertDialog(
          title: Text(
            'منح إنجاز',
            textAlign: TextAlign.right,
            style: AppTextStyles.headlineMedium,
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('الطالب', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 6),
                  if (widget.studentIds.isEmpty) ...[
                    Text(
                      'لا يوجد طلاب في هذه الحلقة — أدخل معرّف الطالب يدوياً',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      hint: 'معرّف الطالب',
                      controller: _manualStudentCtrl,
                      onChanged: (_) => setState(() {}),
                    ),
                  ] else
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
                                  widget.studentIds.contains(_studentId)
                              ? _studentId
                              : null,
                          isExpanded: true,
                          hint: Text(
                            'اختر الطالب',
                            style: AppTextStyles.bodyMedium,
                          ),
                          items: widget.studentIds
                              .map(
                                (id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(
                                    _studentLabel(id),
                                    style: AppTextStyles.bodyMedium,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: submitting
                              ? null
                              : (value) => setState(() => _studentId = value),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('النوع', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGrey,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _type,
                        isExpanded: true,
                        items: widget.achievementTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  _typeLabel(t),
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _type = value);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('العنوان', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 6),
                  AppTextField(
                    hint: 'مثال: ختم جزء عمّ',
                    controller: _titleCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (submitting) ...[
                    const SizedBox(height: 16),
                    const Center(child: AppLoadingWidget()),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () {
                      context.read<SupervisorBloc>().add(
                        const ResetIssueAchievementEvent(),
                      );
                      Navigator.of(context).pop();
                    },
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'منح',
              width: 100,
              height: 40,
              onPressed: submitting || !canSubmit ? null : _submit,
            ),
          ],
        );
      },
    );
  }

  static String _typeLabel(String type) => switch (type) {
    'star' => 'نجمة',
    'badge' => 'شارة',
    'certificate' => 'شهادة',
    _ => type,
  };
}
