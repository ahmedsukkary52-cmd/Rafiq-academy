import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/failure.dart';
import '../domain/halaqa_meeting_link.dart';

const String kMeetingLinkLoadFailedMessage = 'تعذر تحميل رابط الاجتماع';

/// Parses one `halaqaMeetingLinks/{halaqaId}` snapshot; null when the
/// document does not exist.
HalaqaMeetingLink? halaqaMeetingLinkFromSnapshot(
  String halaqaId,
  Map<String, dynamic>? data, {
  required bool exists,
}) {
  if (!exists) return null;
  final raw = data?['meetingLink'];
  final updatedAt = data?['updatedAt'];
  return HalaqaMeetingLink(
    halaqaId: halaqaId,
    meetingLink: raw is String ? raw.trim() : '',
    updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
  );
}

/// Rules allow per-document `get` only (supervisors cannot `list`), so the
/// link is always read by id.
@LazySingleton(as: HalaqaMeetingLinkRepository)
class FirestoreHalaqaMeetingLinkRepository
    implements HalaqaMeetingLinkRepository {
  final FirebaseFirestore firestore;

  FirestoreHalaqaMeetingLinkRepository(this.firestore);

  @override
  Future<Either<Failure, HalaqaMeetingLink?>> getMeetingLink(
    String halaqaId,
  ) async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.halaqaMeetingLinks)
          .doc(halaqaId)
          .get();
      return Right(
        halaqaMeetingLinkFromSnapshot(halaqaId, doc.data(), exists: doc.exists),
      );
    } on FirebaseException catch (e) {
      return Left(meetingLinkFailureFromCode(e.code));
    } catch (_) {
      return const Left(ServerFailure(kMeetingLinkLoadFailedMessage));
    }
  }
}

Failure meetingLinkFailureFromCode(String code) => switch (code) {
  'permission-denied' => const MeetingLinkAccessDeniedFailure(),
  'unavailable' || 'deadline-exceeded' => const NetworkFailure(),
  _ => const ServerFailure(kMeetingLinkLoadFailedMessage),
};
