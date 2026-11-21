/// B14 — halaqa meeting-link policy (client mirror).
///
/// The authoritative check is `validateMeetingLink` in
/// `functions/src/halaqa/meetingLinkFunctions.ts`; this mirror gives early
/// form feedback and decides whether a stored link may be opened.
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

/// Real gaps / controls that survive normalize (NUL etc.).
final RegExp _hardWhitespace = RegExp(r'[\s\u0000-\u001f\u007f-\u009f]');

/// Invisible paste junk from RTL UIs / Google Calendar / messengers.
/// Stripped during normalize instead of rejecting a valid Meet/Zoom URL.
final RegExp _invisiblePasteMarks = RegExp(
  '[\u200b-\u200f\u2028\u2029\u202a-\u202e\u2060\u2066-\u2069\ufeff\u00ad]',
);

/// Unicode / ASCII whitespace — meeting URLs never need spaces.
final RegExp _anyWhitespace = RegExp(r'\s');
/// Space between alphanumerics (Meet code paste) → hyphen, not join.
final RegExp _whitespaceBetweenAlnum = RegExp(
  r'(?<=[A-Za-z0-9])\s+(?=[A-Za-z0-9])',
);
final RegExp _printableAscii = RegExp(r'^[\x21-\x7e]+$');
final RegExp _httpsPrefix = RegExp(r'^https://', caseSensitive: false);
final RegExp _hostLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
final RegExp _port = RegExp(r'^\d{1,5}$');
final RegExp _embeddedHttpsUrl = RegExp(
  r'https://[^\s<>"{}|\\^`\[\]]+',
  caseSensitive: false,
);
final RegExp _bareMeetingHost = RegExp(
  r'^(?:meet\.google\.com|(?:[\w-]+\.)?zoom\.(?:us|com)|teams\.microsoft\.com|(?:[\w-]+\.)?webex\.com|meet\.jit\.si)(?:[/:?#]|$)',
  caseSensitive: false,
);

/// Zoom / Google Meet / Teams — room IDs are digit runs, not phone numbers.
bool isKnownMeetingHost(String hostname) {
  final h = hostname.trim().toLowerCase();
  if (h.isEmpty) return false;
  if (h == 'meet.google.com' || h.endsWith('.meet.google.com')) return true;
  if (h == 'zoom.us' || h.endsWith('.zoom.us')) return true;
  if (h == 'zoom.com' || h.endsWith('.zoom.com')) return true;
  if (h == 'teams.microsoft.com' || h.endsWith('.teams.microsoft.com')) {
    return true;
  }
  if (h == 'webex.com' || h.endsWith('.webex.com')) return true;
  if (h == 'meet.jit.si') return true;
  return false;
}

/// Fancy dashes pasted from Meet/WhatsApp/Office — look like `-` but fail ASCII.
final RegExp _unicodeDashes = RegExp(
  '[\u2010\u2011\u2012\u2013\u2014\u2015\u2212\ufe58\ufe63\uff0d]',
);

/// Normalize paste shapes: invisible RTL marks, unicode dashes, whitespace,
/// quotes, invite text, bare host, http→https.
String normalizeMeetingLinkInput(String raw) {
  var value = raw
      .replaceAll(_invisiblePasteMarks, '')
      .replaceAll(_unicodeDashes, '-');
  if ((value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))) {
    value = value.substring(1, value.length - 1);
  }
  // Invite paste ("Join Zoom Meeting\nhttps://…") — only strip leading junk.
  // Never truncate a lone URL that already starts with https://.
  final httpsAt = value.toLowerCase().indexOf('https://');
  if (httpsAt > 0) {
    final embedded = _embeddedHttpsUrl.firstMatch(value.substring(httpsAt));
    if (embedded != null) value = embedded.group(0)!;
  }
  // Meet-code paste only: spaces between alnum → `-`, then drop leftover
  // whitespace. Do not rewrite arbitrary URL path spaces (e.g. "a b") into
  // valid-looking links — those stay and fail meetingLinkIssue.
  final looksLikeBareMeeting = _bareMeetingHost.hasMatch(value);
  final provisionalHost = () {
    final m = RegExp(
      r'^https?://([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(value);
    return m?.group(1)?.split(':').first ?? '';
  }();
  final mayRewriteSpaces =
      looksLikeBareMeeting || isKnownMeetingHost(provisionalHost);
  if (mayRewriteSpaces) {
    value = value
        .replaceAllMapped(_whitespaceBetweenAlnum, (_) => '-')
        .replaceAll(_anyWhitespace, '');
  }
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value) &&
      _bareMeetingHost.hasMatch(value)) {
    value = 'https://$value';
  }
  if (RegExp(r'^http://', caseSensitive: false).hasMatch(value)) {
    final asHttps = 'https://${value.substring('http://'.length)}';
    final uri = Uri.tryParse(asHttps);
    if (uri != null && isKnownMeetingHost(uri.host)) {
      value = asHttps;
    }
  }
  return value;
}

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
MeetingLinkIssue? meetingLinkIssue(String raw) {
  final value = normalizeMeetingLinkInput(raw);
  // Whitespace-only paste (spaces/tabs) is empty, not a whitespace-in-URL
  // rejection — that issue is reserved for gaps inside an otherwise non-blank
  // candidate.
  if (value.trim().isEmpty) return MeetingLinkIssue.empty;
  if (value.length > kMaxMeetingLinkLength) return MeetingLinkIssue.tooLong;
  if (_hardWhitespace.hasMatch(value)) return MeetingLinkIssue.whitespace;
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
  final normalized = normalizeMeetingLinkInput(raw);
  if (meetingLinkIssue(normalized) != null) return null;
  return Uri.parse(normalized);
}
