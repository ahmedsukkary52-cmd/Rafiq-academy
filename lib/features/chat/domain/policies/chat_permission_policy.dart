import '../../../../core/constants/app_constants.dart';

/// قواعد مين يقدر يتواصل مع مين، مبنية على السبسيفيكيشن الأصلي:
/// - المعلم وولي الأمر بيتواصلوا بس مع المشرف أو الإدارة (مش مع بعض مباشرة)
/// - المشرف بيتواصل مع المعلم وولي الأمر والإدارة
/// - الإدارة بتتواصل مع الكل
///
/// السبب إننا بنحط القاعدة دي هنا في domain layer، مش بس مخفية كزرار
/// في الـ UI: لو حد عدّى الـ UI بأي طريقة (أو عملنا route مباشر بالغلط)،
/// الـ use case نفسه هيرفض العملية. دفاع على مستويين (defense in depth).
///
/// ملاحظة لأحمد: السبسيفيكيشن متقولش صراحة لو المشرف والإدارة يقدروا
/// يتكلموا مع بعض، افترضت إنه مسموح لأنهم الاتنين "staff"، لو حابب
/// تمنعه غيّر القائمة تحت بس.
class ChatPermissionPolicy {
  const ChatPermissionPolicy._();

  static const Map<String, Set<String>> _allowedPairs = {
    AppRoles.teacher: {AppRoles.supervisor, AppRoles.admin},
    AppRoles.parent: {AppRoles.supervisor, AppRoles.admin},
    AppRoles.supervisor: {AppRoles.teacher, AppRoles.parent, AppRoles.admin},
    AppRoles.admin: {AppRoles.teacher, AppRoles.parent, AppRoles.supervisor},
  };

  static bool canChat(String roleA, String roleB) {
    return _allowedPairs[roleA]?.contains(roleB) ?? false;
  }
}

/// توليد id ثابت للمحادثة من uid الطرفين، بحيث الاتنين - أياً كان مين
/// بدأ المحادثة - يوصلوا لنفس الـ document بالظبط بدل ما يتعمل
/// محادثتين مكررتين بين نفس الشخصين.
class ConversationIdGenerator {
  const ConversationIdGenerator._();

  static String generate(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// بيستخرج uid الطرف التاني من نفس الـ conversationId، من غير ما
  /// نحتاج نقرأ الـ document. معتمد على إن uid الفايربيز مفيهوش
  /// underscore (وده صحيح في الصيغة القياسية بتاعته).
  ///
  /// متعمد إننا نحط الدالة دي جنب [generate] في نفس الكلاس، عشان لو
  /// حد غيّر طريقة توليد الـ id في المستقبل، يفتكر يحدّث الدالة دي معاها.
  static String otherParticipant(String conversationId, String knownUid) {
    final parts = conversationId.split('_');
    return parts.firstWhere((p) => p != knownUid, orElse: () => parts.first);
  }
}