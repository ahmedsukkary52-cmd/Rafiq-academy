/// Format rules for the two academy payment destinations stored in
/// `academySettings/paymentPublic`. Each method is validated on its own;
/// a value accepted for one method is never reused for the other.
enum AcademyPaymentMethod { vodafoneCash, instapay }

enum InstapayDestinationKind { address, link }

abstract final class AcademyPaymentDestinations {
  static const int vodafoneCashMaxLength = 32;
  static const int instapayMaxLength = 200;

  static const String vodafoneCashRequiredMessage =
      'أدخل رقم محفظة فودافون كاش';
  static const String vodafoneCashInvalidMessage =
      'رقم فودافون كاش يجب أن يتكوّن من ١١ رقماً ويبدأ بـ 010';
  static const String instapayRequiredMessage =
      'أدخل عنوان إنستاباي أو رابط الدفع';
  static const String instapayInvalidMessage =
      'أدخل عنوان إنستاباي بصيغة name@instapay أو رابطاً يبدأ بـ https://';

  static final RegExp _vodafoneCash = RegExp(r'^010\d{8}$');
  static final RegExp _instapayAddress = RegExp(
    r'^[a-z0-9][a-z0-9._-]{0,63}@instapay$',
  );

  /// Arabic-Indic and Persian digits to ASCII; drops spaces and dashes.
  static String _asciiDigits(String raw) {
    final out = StringBuffer();
    for (final rune in raw.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune == 0x20 || rune == 0x2D || rune == 0xA0) {
        continue;
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// Canonical local form (`010…`), accepting `+20` / `0020` prefixes.
  static String normalizeVodafoneCash(String raw) {
    var v = _asciiDigits(raw.trim());
    if (v.startsWith('+20')) {
      v = '0${v.substring(3)}';
    } else if (v.startsWith('0020')) {
      v = '0${v.substring(4)}';
    }
    return v;
  }

  static bool isValidVodafoneCash(String raw) =>
      _vodafoneCash.hasMatch(normalizeVodafoneCash(raw));

  static String normalizeInstapay(String raw) {
    final v = raw.trim();
    if (v.toLowerCase().endsWith('@instapay')) return v.toLowerCase();
    return v;
  }

  static InstapayDestinationKind? instapayKind(String raw) {
    final v = normalizeInstapay(raw);
    if (v.isEmpty || v.length > instapayMaxLength) return null;
    if (_instapayAddress.hasMatch(v)) return InstapayDestinationKind.address;
    return instapayLinkUri(v) == null ? null : InstapayDestinationKind.link;
  }

  static bool isValidInstapay(String raw) => instapayKind(raw) != null;

  /// Only absolute `https` links with a host and no embedded credentials.
  static Uri? instapayLinkUri(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v.length > instapayMaxLength || v.contains(' ')) {
      return null;
    }
    final uri = Uri.tryParse(v);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  static String normalize(AcademyPaymentMethod method, String raw) =>
      switch (method) {
        AcademyPaymentMethod.vodafoneCash => normalizeVodafoneCash(raw),
        AcademyPaymentMethod.instapay => normalizeInstapay(raw),
      };

  /// Null when [raw] is acceptable. An empty value is accepted only when
  /// [allowEmpty] is true (clearing the destination).
  static String? validate(
    AcademyPaymentMethod method,
    String raw, {
    bool allowEmpty = false,
  }) {
    if (raw.trim().isEmpty) {
      if (allowEmpty) return null;
      return switch (method) {
        AcademyPaymentMethod.vodafoneCash => vodafoneCashRequiredMessage,
        AcademyPaymentMethod.instapay => instapayRequiredMessage,
      };
    }
    return switch (method) {
      AcademyPaymentMethod.vodafoneCash =>
        isValidVodafoneCash(raw) ? null : vodafoneCashInvalidMessage,
      AcademyPaymentMethod.instapay =>
        isValidInstapay(raw) ? null : instapayInvalidMessage,
    };
  }
}
