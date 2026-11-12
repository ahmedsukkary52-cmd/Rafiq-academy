import '../../schedule/domain/entities/halaqa_schedule_source.dart';
import 'parent_child_halaqat_response.dart';

const String kParentChildScheduleCallable = 'getParentChildSchedule';

const String kParentChildScheduleLoadFailedMessage =
    'تعذر تحميل جدول الحلقة. حاول مرة أخرى.';

final RegExp _arabic = RegExp(r'[\u0600-\u06FF]');

/// `getParentChildSchedule` error code → parent-facing message. Server
/// rejections are written in Arabic and shown as-is; SDK/transport text and
/// the English backend-gate message are replaced.
String parentChildScheduleErrorMessage(String code, String? serverMessage) {
  if (code == 'unauthenticated') return kParentChildHalaqatSignedOutMessage;
  final message = serverMessage?.trim() ?? '';
  if (message.isNotEmpty && _arabic.hasMatch(message)) return message;
  return kParentChildScheduleLoadFailedMessage;
}

String _text(Object? value) => value is String ? value.trim() : '';

/// `{halaqaId, name, schedule: [{day, startTime, endTime}]}` → schedule
/// source. A response without the schedule list or for another Halaqa is a
/// contract break, not an empty schedule, so it throws [FormatException].
/// Non-map slots are skipped; any other key is ignored.
HalaqaScheduleSource parseParentChildScheduleResponse(
  Object? data, {
  required String expectedHalaqaId,
}) {
  final raw = data is Map ? data['schedule'] : null;
  if (raw is! List) {
    throw const FormatException('getParentChildSchedule: missing schedule');
  }
  final halaqaId = _text((data as Map)['halaqaId']);
  if (halaqaId != expectedHalaqaId) {
    throw const FormatException('getParentChildSchedule: halaqa mismatch');
  }
  return HalaqaScheduleSource(
    halaqaId: halaqaId,
    name: _text(data['name']),
    schedule: [
      for (final item in raw)
        if (item is Map)
          HalaqaScheduleSlot(
            day: _text(item['day']),
            startTime: _text(item['startTime']),
            endTime: _text(item['endTime']),
          ),
    ],
  );
}
