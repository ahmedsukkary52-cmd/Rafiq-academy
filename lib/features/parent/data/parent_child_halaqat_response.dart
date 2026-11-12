const String kParentChildHalaqatCallable = 'getParentChildHalaqat';

const String kParentChildHalaqatLoadFailedMessage =
    'تعذر تحميل حلقات الطالب. حاول مرة أخرى.';
const String kParentChildHalaqatSignedOutMessage =
    'انتهت الجلسة. سجّل الدخول ثم أعد المحاولة.';

final RegExp _arabic = RegExp(r'[\u0600-\u06FF]');

/// One Halaqa as projected by `getParentChildHalaqat`: never the roster or
/// the meeting link.
class ParentChildHalaqaRow {
  final String id;
  final String name;
  final String teacherId;
  final String supervisorId;

  const ParentChildHalaqaRow({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.supervisorId,
  });
}

/// `getParentChildHalaqat` error code → parent-facing message. Server
/// rejections are written in Arabic and shown as-is; SDK/transport text and
/// the English backend-gate message are replaced.
String parentChildHalaqatErrorMessage(String code, String? serverMessage) {
  if (code == 'unauthenticated') return kParentChildHalaqatSignedOutMessage;
  final message = serverMessage?.trim() ?? '';
  if (message.isNotEmpty && _arabic.hasMatch(message)) return message;
  return kParentChildHalaqatLoadFailedMessage;
}

String _text(Object? value) => value is String ? value.trim() : '';

/// `{halaqat: [...]}` → rows. A response without that list is a contract
/// break, not an empty result, so it throws [FormatException]. Entries that
/// are not maps or lack an id are skipped; any other key is ignored.
List<ParentChildHalaqaRow> parseParentChildHalaqatResponse(Object? data) {
  final raw = data is Map ? data['halaqat'] : null;
  if (raw is! List) {
    throw const FormatException('getParentChildHalaqat: missing list');
  }
  return [
    for (final item in raw)
      if (item is Map && _text(item['id']).isNotEmpty)
        ParentChildHalaqaRow(
          id: _text(item['id']),
          name: _text(item['name']),
          teacherId: _text(item['teacherId']),
          supervisorId: _text(item['supervisorId']),
        ),
  ];
}
