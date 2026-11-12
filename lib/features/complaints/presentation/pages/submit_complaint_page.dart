import 'package:flutter/material.dart';

import '../../../../core/error/user_facing_error.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/complaints_repository.dart';
import '../../domain/complaint.dart';
import '../complaint_widgets.dart';

/// New complaint to the academy administration. Pops with the created id.
class SubmitComplaintPage extends StatefulWidget {
  const SubmitComplaintPage({
    super.key,
    required this.viewer,
    required this.repository,
  });

  final ComplaintViewer viewer;
  final ComplaintsRepository repository;

  @override
  State<SubmitComplaintPage> createState() => _SubmitComplaintPageState();
}

class _SubmitComplaintPageState extends State<SubmitComplaintPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  List<ComplaintContextOption> _options = const [];
  ComplaintContextOption? _context;
  String? _subjectError;
  String? _messageError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.repository
        .contextOptions(uid: widget.viewer.uid, role: widget.viewer.role)
        .then((o) {
          if (mounted) setState(() => _options = o);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _subjectError = ComplaintFormValidation.subject(_subject.text);
      _messageError = ComplaintFormValidation.message(_message.text);
    });
    if (_subjectError != null || _messageError != null) return;
    setState(() => _sending = true);
    try {
      final ctx = _context;
      final id = await widget.repository.submit(
        subject: _subject.text,
        message: _message.text,
        studentId: ctx != null && ctx.isStudent ? ctx.id : null,
        halaqaId: ctx != null && !ctx.isStudent ? ctx.id : null,
      );
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'تم إرسال الشكوى إلى الإدارة');
      Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFacingErrorText('$e'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.viewer.role == 'parent';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppSubpageScaffold(
        title: 'شكوى جديدة',
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text(
              'تصل الشكوى إلى إدارة الأكاديمية، وستصلك إشعارات بكل رد أو تحديث.',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_options.isNotEmpty) ...[
              DropdownButtonFormField<ComplaintContextOption?>(
                key: const Key('complaint-context'),
                initialValue: _context,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: parent
                      ? 'بخصوص الطالب (اختياري)'
                      : 'بخصوص الحلقة (اختياري)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('عام')),
                  for (final o in _options)
                    DropdownMenuItem(
                      value: o,
                      child: Text(o.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _sending
                    ? null
                    : (v) => setState(() => _context = v),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('complaint-subject'),
              controller: _subject,
              enabled: !_sending,
              maxLength: ComplaintFormValidation.subjectMax,
              decoration: InputDecoration(
                labelText: 'عنوان الشكوى',
                errorText: _subjectError,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('complaint-message'),
              controller: _message,
              enabled: !_sending,
              minLines: 4,
              maxLines: 8,
              maxLength: ComplaintFormValidation.messageMax,
              decoration: InputDecoration(
                labelText: 'التفاصيل',
                alignLabelWithHint: true,
                errorText: _messageError,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              key: const Key('complaint-submit'),
              label: 'إرسال الشكوى',
              isLoading: _sending,
              onPressed: _sending ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
