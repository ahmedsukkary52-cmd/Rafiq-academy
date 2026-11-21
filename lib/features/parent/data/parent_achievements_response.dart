import '../../../shared/data/models/achievement_model.dart';

const String kParentAchievementsLoadFailedMessage =
    'تعذر تحميل الإنجازات. حاول مرة أخرى.';
const String kParentAchievementsSignedOutMessage =
    'انتهت الجلسة. سجّل الدخول ثم أعد المحاولة.';

final RegExp _arabic = RegExp(r'[\u0600-\u06FF]');

/// `getParentAchievements` error code → parent-facing message. Server
/// rejections are written in Arabic and shown as-is; SDK/transport text and
/// the English backend-gate message are replaced.
String parentAchievementsErrorMessage(String code, String? serverMessage) {
  if (code == 'unauthenticated') return kParentAchievementsSignedOutMessage;
  final message = serverMessage?.trim() ?? '';
  if (message.isNotEmpty && _arabic.hasMatch(message)) return message;
  return kParentAchievementsLoadFailedMessage;
}

/// `{achievements: [...]}` → models. A response without that list is a
/// contract break, not an empty result, so it throws [FormatException].
/// Entries that are not maps or lack an id are skipped.
List<AchievementModel> parseParentAchievementsResponse(Object? data) {
  final root = data is Map
      ? <String, dynamic>{
          for (final e in data.entries) e.key.toString(): e.value,
        }
      : null;
  final raw = root?['achievements'];
  if (raw is! List) {
    throw const FormatException('getParentAchievements: missing list');
  }
  return [
    for (final item in raw)
      if (item is Map)
        () {
          final map = <String, dynamic>{
            for (final e in item.entries) e.key.toString(): e.value,
          };
          final id = map['id']?.toString().trim() ?? '';
          if (id.isEmpty) return null;
          return AchievementModel.fromParentCallable(map);
        }(),
  ].whereType<AchievementModel>().toList();
}
