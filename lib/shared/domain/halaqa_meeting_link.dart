import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/failure.dart';
import '../../core/usecases/usecases.dart';
import 'meeting_link_policy.dart';

/// B14 — canonical `halaqaMeetingLinks/{halaqaId}` document
/// (`meetingLink` + `updatedAt`). The legacy `halaqat.meetingLink` mirror is
/// never read by the client.
class HalaqaMeetingLink extends Equatable {
  final String halaqaId;

  /// Trimmed stored value; empty when the field is absent or not a string.
  final String meetingLink;
  final DateTime? updatedAt;

  const HalaqaMeetingLink({
    required this.halaqaId,
    required this.meetingLink,
    this.updatedAt,
  });

  Uri? get joinUri => joinableMeetingUri(meetingLink);

  @override
  List<Object?> get props => [halaqaId, meetingLink, updatedAt];
}

enum MeetingLinkAvailability { joinable, missing, invalid }

/// No document means no link. A document whose value is empty or fails
/// [joinableMeetingUri] is unusable and must never be opened or shown.
MeetingLinkAvailability meetingLinkAvailability(HalaqaMeetingLink? link) {
  if (link == null) return MeetingLinkAvailability.missing;
  return link.joinUri == null
      ? MeetingLinkAvailability.invalid
      : MeetingLinkAvailability.joinable;
}

/// `setHalaqaMeetingLink` lets a supervisor add a link only when neither the
/// canonical doc nor the legacy `halaqat.meetingLink` mirror holds a value.
/// Until the legacy mirror is stripped, a missing canonical doc can hide a
/// legacy value, and the client must not read that field to tell the cases
/// apart — so supervisor add stays off and admins add the link.
const bool kSupervisorMeetingLinkAddEnabled = false;

/// Firestore rules refused the read (not a roster student, supervisor or
/// admin of this halaqa). Distinct from connectivity failures.
class MeetingLinkAccessDeniedFailure extends Failure {
  const MeetingLinkAccessDeniedFailure([
    super.message = 'لا تملك صلاحية الوصول إلى رابط اجتماع هذه الحلقة',
  ]);
}

abstract interface class HalaqaMeetingLinkRepository {
  /// Right(null) when no link document exists for [halaqaId].
  Future<Either<Failure, HalaqaMeetingLink?>> getMeetingLink(String halaqaId);
}

@lazySingleton
class GetHalaqaMeetingLinkUseCase
    implements UseCase<HalaqaMeetingLink?, String> {
  final HalaqaMeetingLinkRepository repository;

  const GetHalaqaMeetingLinkUseCase(this.repository);

  @override
  Future<Either<Failure, HalaqaMeetingLink?>> call(String halaqaId) {
    final id = halaqaId.trim();
    if (id.isEmpty) return Future.value(const Right(null));
    return repository.getMeetingLink(id);
  }
}
