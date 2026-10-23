import '../domain/award_submission_id.dart';

const String kAwardGrantFailedMessage = 'تعذر منح الجائزة. حاول مرة أخرى.';
const String kAwardGrantUnconfirmedMessage =
    'لم يتأكد منح الجائزة بسبب الاتصال، وقد تكون مُنحت بالفعل. '
    'أعد المحاولة بالبيانات نفسها، ولن تُمنح مرتين.';
const String kAwardGrantSignedOutMessage =
    'انتهت الجلسة. سجّل الدخول ثم أعد المحاولة.';
const String kAwardGrantPendingNotice =
    'يوجد طلب منح لم تتأكد نتيجته. التعديل موقوف حتى تعيد المحاولة '
    'بالبيانات نفسها أو تتجاهل الطلب.';
const String kAwardGrantAbandonWarning =
    'التجاهل لا يلغي الطلب: إن كان قد وصل إلى الخادم فالجائزة ممنوحة بالفعل. '
    'راجع قائمة الجوائز قبل منح جائزة جديدة حتى لا تتكرر.';
const String kAwardGrantRetrySameLabel = 'إعادة المحاولة بالبيانات نفسها';
const String kAwardLocalSaveFailedMessage =
    'تعذر حفظ الطلب على هذا الجهاز، لذلك لم يُرسل. '
    'تحقق من مساحة التخزين ثم أعد المحاولة.';
const String kAwardRecordUnreadableSummary = 'طلب سابق تعذرت قراءته';
const String kAwardRecordUnreadableNotice =
    'يوجد طلب منح سابق لم تتأكد نتيجته، وربما يكون قد نُفِّذ بالفعل. '
    'لا يمكن إعادة إرساله بأمان لتعذر استعادة بياناته الأصلية، ومنها '
    'الطلاب المستلمون. راجع قائمة الجوائز قبل تجاهله؛ فالتجاهل يزيل '
    'سجل الطلب من هذا الجهاز فقط ولا يلغي جائزة سُجِّلت على الخادم.';
const String kAwardImageNotRestorableNotice =
    'هذا الطلب يتضمن صورة لا تُحفظ بعد إغلاق التطبيق، فلا يمكن إعادة إرساله '
    'بالبيانات نفسها. راجع قائمة الجوائز: إن لم تجد الجائزة فتجاهل الطلب '
    'وامنحها من جديد.';

/// Why a restored request cannot be retried, for the unresolved panel.
String? awardRecoveryNotice(AwardRecoveryProblem? problem) =>
    switch (problem) {
      AwardRecoveryProblem.unreadable => kAwardRecordUnreadableNotice,
      AwardRecoveryProblem.imageNotRestorable => kAwardImageNotRestorableNotice,
      null => null,
    };

/// Whether a failure message means the outcome is unknown (the request may
/// have been committed), as opposed to a confirmed rejection.
bool isAwardGrantUnconfirmed(String? message) =>
    message == kAwardGrantUnconfirmedMessage;

const Set<String> _ambiguousCodes = {
  'unavailable',
  'deadline-exceeded',
  'internal',
  'unknown',
  'cancelled',
  'resource-exhausted',
};

final RegExp _arabic = RegExp(r'[\u0600-\u06FF]');

/// `grantAward` callable error code → user-facing message. The server writes
/// its own rejections in Arabic; anything else (SDK/transport text) is
/// replaced so raw Firebase strings never reach the user.
String awardGrantErrorMessage(String code, String? serverMessage) {
  if (_ambiguousCodes.contains(code)) return kAwardGrantUnconfirmedMessage;
  if (code == 'unauthenticated') return kAwardGrantSignedOutMessage;
  final message = serverMessage?.trim() ?? '';
  if (message.isNotEmpty && _arabic.hasMatch(message)) return message;
  return kAwardGrantFailedMessage;
}

/// A non-callable error: unknown outcome once the request may have been
/// sent, a confirmed failure before that.
String awardGrantUnexpectedErrorMessage({required bool requestSent}) =>
    requestSent ? kAwardGrantUnconfirmedMessage : kAwardGrantFailedMessage;
