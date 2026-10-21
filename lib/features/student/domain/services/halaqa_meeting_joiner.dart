import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/meeting_link_policy.dart';

/// Result of one Join tap. Null from [HalaqaMeetingJoiner.join] means the tap
/// was ignored because a previous join is still in progress.
enum MeetingJoinOutcome { opened, missing, invalid, launchFailed, loadFailed }

const Map<MeetingJoinOutcome, String> kMeetingJoinMessages = {
  MeetingJoinOutcome.missing:
      'لم يُضبط رابط الاجتماع لهذه الحلقة بعد. تواصل مع مشرف الحلقة.',
  MeetingJoinOutcome.invalid:
      'رابط الاجتماع المحفوظ لهذه الحلقة غير صالح. تواصل مع مشرف الحلقة لتحديثه.',
  MeetingJoinOutcome.launchFailed:
      'تعذر فتح رابط الاجتماع. تأكد من وجود متصفح أو تطبيق الاجتماع ثم حاول مرة أخرى.',
  MeetingJoinOutcome.loadFailed:
      'تعذر التحقق من رابط الاجتماع الآن. تحقق من الاتصال وحاول مرة أخرى.',
};

typedef MeetingLinkLoader =
    Future<Either<Failure, String>> Function(String halaqaId);
typedef MeetingUriOpener = Future<bool> Function(Uri uri);

/// B14 — the single Join rule for every student entry point (home card and
/// schedule): read the halaqa's link fresh at tap time, open it only when it
/// passes [joinableMeetingUri], and never fall back to a cached or default
/// URL. Joining is not gated on a time window (see DELIVERY_STATUS B14).
class HalaqaMeetingJoiner {
  final MeetingLinkLoader loadLink;
  final MeetingUriOpener open;
  bool _busy = false;

  HalaqaMeetingJoiner({required this.loadLink, required this.open});

  bool get isBusy => _busy;

  Future<MeetingJoinOutcome?> join(String halaqaId) async {
    if (_busy) return null;
    final id = halaqaId.trim();
    if (id.isEmpty) return MeetingJoinOutcome.missing;
    _busy = true;
    try {
      final loaded = await loadLink(id);
      return await loaded.fold((_) async => MeetingJoinOutcome.loadFailed, (
        raw,
      ) async {
        if (raw.trim().isEmpty) return MeetingJoinOutcome.missing;
        final uri = joinableMeetingUri(raw);
        if (uri == null) return MeetingJoinOutcome.invalid;
        bool opened;
        try {
          opened = await open(uri);
        } catch (_) {
          opened = false;
        }
        return opened
            ? MeetingJoinOutcome.opened
            : MeetingJoinOutcome.launchFailed;
      });
    } finally {
      _busy = false;
    }
  }
}
