import 'package:flutter/material.dart';

import '../domain/meeting_link_policy.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// What the user asked for in [showMeetingLinkDialog].
class MeetingLinkDialogResult {
  /// Trimmed link to save; null when [clear] is requested.
  final String? link;
  final bool clear;

  const MeetingLinkDialogResult.save(String this.link) : clear = false;
  const MeetingLinkDialogResult.clear() : link = null, clear = true;
}

/// Edit dialog for one halaqa's meeting link. The field starts with
/// [currentLink], so saving without edits never loses it; an unchanged save
/// returns null. Clearing is a separate, confirmed action shown only when
/// [canClear] and a link exists.
Future<MeetingLinkDialogResult?> showMeetingLinkDialog(
  BuildContext context, {
  required String currentLink,
  required bool canClear,
}) {
  return showDialog<MeetingLinkDialogResult>(
    context: context,
    builder: (_) =>
        _MeetingLinkDialog(currentLink: currentLink.trim(), canClear: canClear),
  );
}

class _MeetingLinkDialog extends StatefulWidget {
  final String currentLink;
  final bool canClear;

  const _MeetingLinkDialog({required this.currentLink, required this.canClear});

  @override
  State<_MeetingLinkDialog> createState() => _MeetingLinkDialogState();
}

class _MeetingLinkDialogState extends State<_MeetingLinkDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentLink,
  );
  String? _error;
  bool _confirmClear = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value == widget.currentLink && value.isNotEmpty) {
      Navigator.pop(context);
      return;
    }
    final error = meetingLinkErrorText(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, MeetingLinkDialogResult.save(value));
  }

  @override
  Widget build(BuildContext context) {
    final showClear = widget.canClear && widget.currentLink.isNotEmpty;
    return AlertDialog(
      title: Text(
        widget.currentLink.isEmpty ? 'إضافة رابط الاجتماع' : 'رابط الاجتماع',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('meetingLinkField'),
            controller: _controller,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            autocorrect: false,
            maxLength: kMaxMeetingLinkLength,
            decoration: InputDecoration(
              labelText: 'رابط الاجتماع (https://)',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_confirmClear)
            Text(
              'سيتم حذف الرابط ولن يتمكن الطلاب من الانضمام حتى يُضاف رابط جديد. اضغط «تأكيد الحذف» للمتابعة.',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
        ],
      ),
      actions: [
        if (showClear)
          TextButton(
            key: const Key('meetingLinkClear'),
            onPressed: () {
              if (!_confirmClear) {
                setState(() => _confirmClear = true);
                return;
              }
              Navigator.pop(context, const MeetingLinkDialogResult.clear());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(_confirmClear ? 'تأكيد الحذف' : 'حذف الرابط'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        AppButton(
          key: const Key('meetingLinkSave'),
          label: 'حفظ',
          width: 96,
          height: 40,
          onPressed: _save,
        ),
      ],
    );
  }
}
