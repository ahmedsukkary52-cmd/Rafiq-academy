const String kCommunicationSettingsLoadFailedMessage =
    'تعذر تحميل إعدادات التواصل، حاول مرة أخرى';
const String kCommunicationSettingsSaveFailedMessage =
    'تعذر حفظ الإعدادات، تعديلاتك محفوظة ويمكنك المحاولة مرة أخرى';
const String kCommunicationSettingsOfflineMessage =
    'تعذر الاتصال بالخادم، تحقق من الإنترنت وحاول مرة أخرى';
const String kCommunicationSettingsDeniedMessage =
    'ليس لديك صلاحية لتعديل إعدادات التواصل';

/// User-facing text for a Firestore error code; never the raw exception.
String communicationSettingsErrorMessage(String code, {required bool save}) =>
    switch (code) {
      'permission-denied' ||
      'unauthenticated' => kCommunicationSettingsDeniedMessage,
      'unavailable' ||
      'deadline-exceeded' => kCommunicationSettingsOfflineMessage,
      _ =>
        save
            ? kCommunicationSettingsSaveFailedMessage
            : kCommunicationSettingsLoadFailedMessage,
    };
