/// B14 — halaqa meeting-link policy (client mirror).
///
/// The authoritative check is `validateMeetingLink` in
/// `functions/src/halaqa/meetingLinkFunctions.ts`; this mirror gives early
/// form feedback and decides whether a stored link may be opened. The
/// server also rejects phone numbers / WhatsApp links, which is not mirrored.
library;

const int kMaxMeetingLinkLength = 500;

enum MeetingLinkIssue {
  empty,
  tooLong,
  whitespace,
  unsupportedCharacters,
  notHttps,
  credentials,
  invalidHost,
  malformed,
}

const Map<MeetingLinkIssue, String> kMeetingLinkIssueMessages = {
  MeetingLinkIssue.empty: 'أدخل رابط الاجتماع، أو استخدم «حذف الرابط» لإزالته',
  MeetingLinkIssue.tooLong: 'رابط الاجتماع أطول من المسموح (500 حرف)',
  MeetingLinkIssue.whitespace:
      'رابط الاجتماع يحتوي على مسافات أو رموز تحكم غير مسموحة',
  MeetingLinkIssue.unsupportedCharacters:
      'رابط الاجتماع يحتوي على رموز غير مدعومة؛ انسخ الرابط كما هو من تطبيق الاجتماع',
  MeetingLinkIssue.notHttps: 'رابط الاجتماع يجب أن يبدأ بـ https://',
  MeetingLinkIssue.credentials:
      'رابط الاجتماع يجب ألا يحتوي على اسم مستخدم أو كلمة مرور',
  MeetingLinkIssue.invalidHost: 'عنوان موقع الاجتماع في الرابط غير صالح',
  MeetingLinkIssue.malformed: 'رابط الاجتماع غير صالح',
};

final RegExp _whitespaceOrControl = RegExp(
  '[\\s\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028\u2029'
  '\u202a-\u202e\u2066-\u2069\ufeff]',
);
final RegExp _printableAscii = RegExp(r'^[\x21-\x7e]+$');
final RegExp _httpsPrefix = RegExp(r'^https://', caseSensitive: false);
final RegExp _hostLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
final RegExp _port = RegExp(r'^\d{1,5}$');

MeetingLinkIssue? _hostIssue(String authority) {
  if (authority.contains('@')) return MeetingLinkIssue.credentials;
  final colon = authority.lastIndexOf(':');
  final host = (colon >= 0 ? authority.substring(0, colon) : authority)
      .toLowerCase();
  if (colon >= 0) {
    final port = authority.substring(colon + 1);
    final value = int.tryParse(port);
    if (!_port.hasMatch(port) || value == null || value < 1 || value > 65535) {
      return MeetingLinkIssue.invalidHost;
    }
  }
  if (host.isEmpty || host.length > 253) return MeetingLinkIssue.invalidHost;
  final labels = host.split('.');
  if (labels.length < 2 || !labels.every(_hostLabel.hasMatch)) {
    return MeetingLinkIssue.invalidHost;
  }
  return null;
}

/// First policy issue of [raw], or null when it is an acceptable link.
/// Only outer whitespace is trimmed; nothing is prefixed or rewritten.
MeetingLinkIssue? meetingLinkIssue(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return MeetingLinkIssue.empty;
  if (value.length > kMaxMeetingLinkLength) return MeetingLinkIssue.tooLong;
  if (_whitespaceOrControl.hasMatch(value)) return MeetingLinkIssue.whitespace;
  if (!_printableAscii.hasMatch(value)) {
    return MeetingLinkIssue.unsupportedCharacters;
  }
  if (!_httpsPrefix.hasMatch(value)) return MeetingLinkIssue.notHttps;
  if (value.contains(r'\')) return MeetingLinkIssue.malformed;

  final afterScheme = value.substring('https://'.length);
  final end = afterScheme.indexOf(RegExp('[/?#]'));
  final authority = end < 0 ? afterScheme : afterScheme.substring(0, end);
  final host = _hostIssue(authority);
  if (host != null) return host;

  final uri = Uri.tryParse(value);
  if (uri == null) return MeetingLinkIssue.malformed;
  if (uri.scheme.toLowerCase() != 'https') return MeetingLinkIssue.notHttps;
  if (uri.userInfo.isNotEmpty) return MeetingLinkIssue.credentials;
  return null;
}

/// Arabic form message for [raw], or null when acceptable.
String? meetingLinkErrorText(String raw) {
  final issue = meetingLinkIssue(raw);
  return issue == null ? null : kMeetingLinkIssueMessages[issue];
}

/// The stored link as an openable [Uri], or null when missing or invalid.
Uri? joinableMeetingUri(String raw) {
  if (meetingLinkIssue(raw) != null) return null;
  return Uri.parse(raw.trim());
}
