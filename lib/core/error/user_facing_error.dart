const String permissionDeniedErrorText =
    'ليس لديك صلاحية للوصول إلى هذه البيانات.';
const String connectionErrorText =
    'تعذر الاتصال بالخادم. تحقق من الإنترنت وأعد المحاولة.';
const String signedOutErrorText = 'انتهت الجلسة. سجّل الدخول من جديد.';
const String notFoundErrorText = 'العنصر المطلوب غير موجود أو لم يعد متاحاً.';
const String genericErrorText = 'حدث خطأ غير متوقع. حاول مرة أخرى.';

final RegExp _firebaseCode = RegExp(r'\[[\w.-]+/([\w-]+)\]');
final RegExp _technicalMarker = RegExp(
  r'Exception|Error\b|firebase|Instance of|Bad state|Null check|'
  r'PERMISSION_DENIED|UNAVAILABLE',
  caseSensitive: false,
);
final RegExp _arabicLetter = RegExp(r'[\u0600-\u06FF]');

/// Turns raw Firebase/platform error text into a short Arabic sentence.
/// Messages that are already user-facing are returned unchanged, so bloc
/// copy like 'تعذر تحميل البيانات' keeps its wording.
String userFacingErrorText(String raw) {
  final message = raw.trim();
  if (message.isEmpty) return genericErrorText;

  final codeMatch = _firebaseCode.firstMatch(message);
  if (codeMatch != null) {
    // Callable HttpsErrors carry backend-authored Arabic copy after the code.
    final rest = message.substring(codeMatch.end).trim();
    if (_arabicLetter.hasMatch(rest) && !_technicalMarker.hasMatch(rest)) {
      return rest;
    }
    return _textForCode(codeMatch.group(1)!);
  }

  if (!_technicalMarker.hasMatch(message)) return message;
  if (message.contains('PERMISSION_DENIED')) return permissionDeniedErrorText;
  if (message.contains('UNAVAILABLE') ||
      message.contains('SocketException')) {
    return connectionErrorText;
  }
  final stripped = message.replaceFirst(
    RegExp(r'^(\w*Exception|Exception):\s*'),
    '',
  );
  if (stripped != message &&
      _arabicLetter.hasMatch(stripped) &&
      !_technicalMarker.hasMatch(stripped)) {
    return stripped;
  }
  return genericErrorText;
}

String _textForCode(String code) => switch (code) {
  'permission-denied' => permissionDeniedErrorText,
  'unavailable' ||
  'deadline-exceeded' ||
  'network-request-failed' => connectionErrorText,
  'unauthenticated' || 'user-token-expired' => signedOutErrorText,
  'not-found' || 'object-not-found' => notFoundErrorText,
  _ => genericErrorText,
};
