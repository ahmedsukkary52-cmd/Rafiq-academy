import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/halaqa_meeting_link.dart';

/// Result of one Join tap. Null from [HalaqaMeetingJoiner.join] means the tap
/// was ignored because a previous join is still in progress.
enum MeetingJoinOutcome {
  opened,
  missing,
  invalid,
  launchFailed,
  accessDenied,
  loadFailed,
}

const Map<MeetingJoinOutcome, String> kMeetingJoinMessages = {
  MeetingJoinOutcome.missing:
      'لم يُضبط رابط الاجتماع لهذه الحلقة بعد. تواصل مع مشرف الحلقة.',
  MeetingJoinOutcome.invalid:
      'رابط الاجتماع المحفوظ لهذه الحلقة غير صالح. تواصل مع مشرف الحلقة لتحديثه.',
  MeetingJoinOutcome.launchFailed:
      'تعذر فتح رابط الاجتماع. تأكد من وجود متصفح أو تطبيق الاجتماع ثم حاول مرة أخرى.',
  MeetingJoinOutcome.accessDenied:
      'لا تملك صلاحية الوصول إلى رابط اجتماع هذه الحلقة. تواصل مع مشرف الحلقة.',
  MeetingJoinOutcome.loadFailed:
      'تعذر التحقق من رابط الاجتماع الآن. تحقق من الاتصال وحاول مرة أخرى.',
};

typedef MeetingLinkLoader =
    Future<Either<Failure, HalaqaMeetingLink?>> Function(String halaqaId);
typedef MeetingUriOpener = Future<bool> Function(Uri uri);

/// B14 — the single Join rule for every student entry point (home card and
/// schedule): read the canonical link fresh at tap time, open it only when
/// [meetingLinkAvailability] says joinable, and never fall back to a cached,
/// default or legacy `halaqat.meetingLink` URL. Joining is not gated on a
/// time window (see DELIVERY_STATUS B14).
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
      return await loaded.fold(
        (f) async => f is MeetingLinkAccessDeniedFailure
            ? MeetingJoinOutcome.accessDenied
            : MeetingJoinOutcome.loadFailed,
        (link) async {
          switch (meetingLinkAvailability(link)) {
            case MeetingLinkAvailability.missing:
              return MeetingJoinOutcome.missing;
            case MeetingLinkAvailability.invalid:
              return MeetingJoinOutcome.invalid;
            case MeetingLinkAvailability.joinable:
              break;
          }
          final uri = link!.joinUri!;
          bool opened;
          try {
            opened = await open(uri);
          } catch (_) {
            opened = false;
          }
          return opened
              ? MeetingJoinOutcome.opened
              : MeetingJoinOutcome.launchFailed;
        },
      );
    } finally {
      _busy = false;
    }
  }
}
