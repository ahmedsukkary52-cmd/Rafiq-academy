/// Members created by the Admin sign in with an academy username (e.g.
/// `st123456`); staff may still use an email. Firebase Auth needs an email, so
/// a username maps to an internal address under the reserved `.invalid` TLD —
/// mirrored by `functions/src/accounts/academyCredentials.ts`.
abstract final class AcademyLoginIdentifier {
  static const emailDomain = 'members.rafiq-academy.invalid';

  static final _username = RegExp(r'^[a-z][a-z0-9._-]{2,29}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isUsername(String raw) =>
      _username.hasMatch(raw.trim().toLowerCase());

  static bool isEmail(String raw) => _email.hasMatch(raw.trim());

  /// The Firebase Auth email for [raw], or null when it is neither form.
  static String? toAuthEmail(String raw) {
    final value = raw.trim();
    if (isEmail(value)) return value;
    if (isUsername(value)) return '${value.toLowerCase()}@$emailDomain';
    return null;
  }

  /// Internal addresses receive no mail; recovery goes through the Admin.
  static bool isInternalEmail(String? email) =>
      (email ?? '').trim().toLowerCase().endsWith('@$emailDomain');
}
