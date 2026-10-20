/// No-personal-contact policy. Personal phone numbers are never stored, and
/// user-generated text must not carry phone numbers or WhatsApp/telephone
/// links. Mirrors `functions/src/privacy/contactInfoPolicy.ts` and the
/// `contactFieldKeys()` deny-list in firestore.rules.
///
/// Detection is best-effort: spelled-out digits, obfuscated numbers, emails
/// and other messaging handles are not caught.
library;

const List<String> contactFieldKeys = [
  'phone',
  'phoneNumber',
  'mobile',
  'whatsapp',
  'parentPhone',
  'guardianPhone',
];

enum ContactInfoFinding { phoneNumber, phoneLink, whatsappLink }

const String contactInfoRejectionMessage =
    'لا يُسمح بمشاركة أرقام الهواتف أو روابط واتساب أو روابط الاتصال';

final RegExp _phoneLink = RegExp(
  r'(?:^|[^a-z0-9])(?:tel|sms|callto):',
  caseSensitive: false,
);
final RegExp _whatsappLink = RegExp(
  r'(?:^|[^a-z0-9])whatsapp:'
  r'|(?:^|[^a-z0-9.])(?:wa\.me|wa\.link)(?:[/?#\s]|$)'
  r'|(?:^|[^a-z0-9])(?:[a-z0-9-]+\.)?whatsapp\.com(?:[/?#\s]|$)',
  caseSensitive: false,
);

/// Digit groups joined only by spaces, dashes, dots or parentheses.
final RegExp _digitRun = RegExp(r'\+?\d+(?:[ \t\u00a0\-.()]{1,3}\d+)*');
final RegExp _nonDigits = RegExp(r'\D+');
const int _maxPhoneDigits = 15;

String _normalizeDigits(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.write(rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.write(rune - 0x06F0);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool _isPhoneDigits(String digits, {required bool hasPlus}) {
  if (RegExp(r'^05\d{8}$').hasMatch(digits) ||
      RegExp(r'^9665\d{8}$').hasMatch(digits)) {
    return true;
  }
  if (RegExp(r'^01[0125]\d{8}$').hasMatch(digits) ||
      RegExp(r'^201[0125]\d{8}$').hasMatch(digits)) {
    return true;
  }
  if (digits.startsWith('00')) {
    final rest = digits.substring(2);
    return rest.length >= 8 &&
        rest.length <= _maxPhoneDigits &&
        !rest.startsWith('0');
  }
  return hasPlus && digits.length >= 8 && digits.length <= _maxPhoneDigits;
}

bool _containsPhoneNumber(String text) {
  for (final match in _digitRun.allMatches(text)) {
    final run = match.group(0)!;
    final hasPlus = run.startsWith('+');
    final groups = run.split(_nonDigits).where((g) => g.isNotEmpty).toList();
    for (var i = 0; i < groups.length; i++) {
      var joined = '';
      for (var j = i; j < groups.length; j++) {
        joined += groups[j];
        if (joined.length > _maxPhoneDigits + 2) break;
        if (_isPhoneDigits(joined, hasPlus: hasPlus && i == 0)) return true;
      }
    }
  }
  return false;
}

/// First kind of contact info found in [text], or null.
ContactInfoFinding? detectContactInfo(String? text) {
  if (text == null || text.isEmpty) return null;
  final normalized = _normalizeDigits(text);
  if (_whatsappLink.hasMatch(normalized)) {
    return ContactInfoFinding.whatsappLink;
  }
  if (_phoneLink.hasMatch(normalized)) return ContactInfoFinding.phoneLink;
  if (_containsPhoneNumber(normalized)) return ContactInfoFinding.phoneNumber;
  return null;
}

/// Arabic rejection message when [text] carries contact info, else null.
String? contactInfoViolation(String? text) =>
    detectContactInfo(text) == null ? null : contactInfoRejectionMessage;

/// Whether [raw] is an http(s) link that is safe to open from user content:
/// no telephone/SMS/WhatsApp schemes and no WhatsApp hosts.
bool isAllowedExternalLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasAuthority) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return false;
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  if (host == 'wa.me' ||
      host == 'wa.link' ||
      host == 'whatsapp.com' ||
      host.endsWith('.whatsapp.com')) {
    return false;
  }
  return true;
}
