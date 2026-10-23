const String kPaymentDestinationsLoadFailedMessage =
    'تعذر تحميل وسائل الدفع. حاول مرة أخرى';
const String kPaymentDestinationsSaveFailedMessage =
    'تعذر حفظ وسيلة الدفع. لم يتم تغيير البيانات المحفوظة. حاول مرة أخرى';
const String kPaymentDestinationsOfflineMessage =
    'تعذر الاتصال بالخادم. تحقق من اتصالك وحاول مرة أخرى';
const String kPaymentDestinationsDeniedMessage =
    'ليس لديك صلاحية تعديل وسائل الدفع';

/// User-facing text for a Firestore error code; never the raw exception.
String paymentDestinationsErrorMessage(
  String code, {
  required bool save,
}) => switch (code) {
  'permission-denied' || 'unauthenticated' => kPaymentDestinationsDeniedMessage,
  'unavailable' || 'deadline-exceeded' => kPaymentDestinationsOfflineMessage,
  _ =>
    save
        ? kPaymentDestinationsSaveFailedMessage
        : kPaymentDestinationsLoadFailedMessage,
};
