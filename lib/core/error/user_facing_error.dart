const String permissionDeniedErrorText =
    'ليس لديك صلاحية للوصول إلى هذه البيانات.';
const String connectionErrorText =
    'تعذر الاتصال بالخادم. تحقق من الإنترنت وأعد المحاولة.';
const String signedOutErrorText = 'انتهت الجلسة. سجّل الدخول من جديد.';
const String notFoundErrorText = 'العنصر المطلوب غير موجود أو لم يعد متاحاً.';
const String missingIndexErrorText =
    'تعذر تحميل هذه القائمة حالياً. أعد المحاولة لاحقاً أو تواصل مع الدعم.';
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
    if (_arabicLetter.hasMatch(rest)) return rest;
    final code = codeMatch.group(1)!;
    if (_isFirestoreMissingIndex(message, code)) return missingIndexErrorText;
    return _textForCode(code);
  }

  // Strip a leading Exception: wrapper when the body is already Arabic.
  final stripped = message.replaceFirst(
    RegExp(r'^(\w*Exception|Exception):\s*'),
    '',
  );
  final candidate = stripped != message ? stripped : message;

  // Datasource / callable Arabic copy must survive even when it mentions
  // Error / firebase / IOException (those markers are for raw dumps only).
  if (_arabicLetter.hasMatch(candidate) &&
      !candidate.contains('Instance of') &&
      !candidate.contains('package:') &&
      !candidate.contains('#0 ')) {
    return candidate;
  }

  if (!_technicalMarker.hasMatch(message)) return message;
  if (RegExp(r'requires an index', caseSensitive: false).hasMatch(message)) {
    return missingIndexErrorText;
  }
  if (message.contains('PERMISSION_DENIED')) return permissionDeniedErrorText;
  if (message.contains('UNAVAILABLE') ||
      message.contains('SocketException')) {
    return connectionErrorText;
  }
  return genericErrorText;
}

/// Firestore composite-index failures only. Callable `failed-precondition`
/// (business rules) must stay on the generic or backend-authored path.
bool _isFirestoreMissingIndex(String message, String code) {
  if (code != 'failed-precondition') return false;
  final lower = message.toLowerCase();
  if (lower.contains('firebase_functions/')) return false;
  if (!lower.contains('index')) return false;
  return lower.contains('cloud_firestore/') ||
      lower.contains('requires an index');
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
