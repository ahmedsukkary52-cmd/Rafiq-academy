import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
/// [canClear] and a link exists — [currentLink], or [storedLinkExists] for a
/// stored value that must not be displayed (an invalid link).
Future<MeetingLinkDialogResult?> showMeetingLinkDialog(
  BuildContext context, {
  required String currentLink,
  required bool canClear,
  bool storedLinkExists = false,
}) {
  return showDialog<MeetingLinkDialogResult>(
    context: context,
    builder: (_) => _MeetingLinkDialog(
      currentLink: currentLink.trim(),
      canClear: canClear,
      storedLinkExists: storedLinkExists,
    ),
  );
}

class _MeetingLinkDialog extends StatefulWidget {
  final String currentLink;
  final bool canClear;
  final bool storedLinkExists;

  const _MeetingLinkDialog({
    required this.currentLink,
    required this.canClear,
    required this.storedLinkExists,
  });

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
    final value = normalizeMeetingLinkInput(_controller.text);
    final current = normalizeMeetingLinkInput(widget.currentLink);
    if (value == current && value.isNotEmpty) {
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
    final showClear =
        widget.canClear &&
        (widget.currentLink.isNotEmpty || widget.storedLinkExists);
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
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            maxLength: kMaxMeetingLinkLength,
            inputFormatters: const [MeetingLinkInputFormatter()],
            decoration: InputDecoration(
              labelText: 'رابط Zoom أو Google Meet',
              hintText: 'https://meet.google.com/xxx-xxxx-xxx',
              helperText:
                  'الصق رابط الغرفة كما هو. أي شرطات أو رموز خفية تُصلَّح تلقائياً.',
              helperMaxLines: 2,
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

/// Live-field sanitizer: unicode dashes → ASCII, drop invisible / whitespace junk.
class MeetingLinkInputFormatter extends TextInputFormatter {
  const MeetingLinkInputFormatter();

  static final _betweenAlnum = RegExp(r'(?<=[A-Za-z0-9])\s+(?=[A-Za-z0-9])');
  static final _junk = RegExp(
    r'[\s\u200b-\u200f\u2028\u2029\u202a-\u202e\u2060\u2066-\u2069\ufeff\u00ad]',
  );
  static final _dashes = RegExp(
    '[\u2010\u2011\u2012\u2013\u2014\u2015\u2212\ufe58\ufe63\uff0d]',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text
        .replaceAllMapped(_betweenAlnum, (_) => '-')
        .replaceAll(_junk, '')
        .replaceAll(_dashes, '-');
    if (cleaned == newValue.text) return newValue;
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}
