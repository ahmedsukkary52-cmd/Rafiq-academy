import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/services/halaqa_meeting_joiner.dart';
import '../../domain/usecases/get_student_halaqa_usecase.dart';
import '../../domain/usecases/watch_latest_assignment_usecase.dart';

/// Opens [uri] outside the app. `launchUrl` reports a missing handler as
/// false, so no `canLaunchUrl` pre-check (and no Android `<queries>` entry)
/// is needed.
Future<bool> openMeetingUriExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

HalaqaMeetingJoiner? _sharedJoiner;

/// One joiner for the app, so taps on the home card and the schedule page
/// cannot start overlapping launches.
HalaqaMeetingJoiner get sharedHalaqaMeetingJoiner =>
    _sharedJoiner ??= HalaqaMeetingJoiner(
      loadLink: (halaqaId) async {
        final result = await sl<GetStudentHalaqaUseCase>()(
          HalaqaIdParams(halaqaId),
        );
        return result.map((halaqa) => halaqa.meetingLink);
      },
      open: openMeetingUriExternally,
    );

/// Join tap handler shared by every student entry point.
Future<void> joinHalaqaMeeting(
  BuildContext context,
  String halaqaId, {
  HalaqaMeetingJoiner? joiner,
}) async {
  final outcome = await (joiner ?? sharedHalaqaMeetingJoiner).join(halaqaId);
  if (outcome == null || outcome == MeetingJoinOutcome.opened) return;
  if (!context.mounted) return;
  final message = kMeetingJoinMessages[outcome]!;
  if (outcome == MeetingJoinOutcome.missing) {
    AppSnackBar.showInfo(context, message);
  } else {
    AppSnackBar.showError(context, message);
  }
}
