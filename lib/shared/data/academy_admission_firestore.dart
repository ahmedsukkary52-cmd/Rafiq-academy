import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/exception.dart';
import '../domain/academy_membership_invariant.dart';

/// Firestore realization of **Academy Admission Workflow** (Rules 5–7).
///
/// Establishes the approved membership invariant as **one** Firestore batch.
/// Does not invent a membership collection or promote a field SSOT.
///
/// Current Implementation Owner entry remains [ApproveNewStudentUseCase];
/// this helper is the shared atomic write both admin and supervisor paths use.
///
/// Rule 6: repeated calls for the same student+halaqa converge to the same
/// invariant (idempotent reconcile; `arrayUnion` never duplicates roster ids).
///
/// Rule 7: reconciliation is **invariant-driven**. Target values come from the
/// admission parameters (`studentId`, `halaqaId`) written **directly** into each
/// invariant member. Never assume one stored field is authoritative and copy it
/// into the others.
class AcademyAdmissionFirestore {
  const AcademyAdmissionFirestore._();

  /// Preconditions: user exists and `role == student`.
  /// Writes atomically: `isActive=true`, profile `halaqaId`, roster `arrayUnion`.
  ///
  /// If the invariant already holds for this pair, returns without rewriting
  /// (Rule 6). Otherwise reconciles toward the approved invariant in one batch
  /// (Rule 7 — direct writes, not field-to-field copies).
  /// If any step cannot complete, throws — never leaves a partial admit.
  static Future<void> establishMembership({
    required FirebaseFirestore firestore,
    required String studentId,
    required String halaqaId,
  }) async {
    final trimmedStudentId = studentId.trim();
    final trimmedHalaqaId = halaqaId.trim();
    if (trimmedStudentId.isEmpty || trimmedHalaqaId.isEmpty) {
      throw const ServerException('معرّف الطالب أو الحلقة غير صالح');
    }

    final userRef = firestore
        .collection(FirestoreCollections.users)
        .doc(trimmedStudentId);
    final profileRef = firestore
        .collection(FirestoreCollections.studentProfiles)
        .doc(trimmedStudentId);
    final halaqaRef = firestore
        .collection(FirestoreCollections.halaqat)
        .doc(trimmedHalaqaId);

    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw const ServerException('الطالب غير موجود');
    }

    final userData = userSnap.data() ?? const <String, dynamic>{};
    final role = userData['role'];
    if (role != AppRoles.student) {
      // Incomplete membership — do not write any invariant member.
      throw const ServerException(
        'لا يمكن إتمام العضوية: دور المستخدم ليس طالباً',
      );
    }

    final profileSnap = await profileRef.get();
    final halaqaSnap = await halaqaRef.get();
    if (!halaqaSnap.exists) {
      throw const ServerException('الحلقة غير موجودة');
    }

    final rosterRaw = halaqaSnap.data()?['studentIds'];
    final roster = rosterRaw is List
        ? rosterRaw.map((e) => e.toString()).toList()
        : const <String>[];
    final profileHalaqaId = profileSnap.data()?['halaqaId'] as String?;
    final isActive = userData['isActive'] as bool?;

    if (AcademyMembershipInvariant.isComplete(
      rosterContainsStudent: roster.contains(trimmedStudentId),
      profileHalaqaId: profileHalaqaId,
      expectedHalaqaId: trimmedHalaqaId,
      role: role is String ? role : null,
      isActive: isActive,
    )) {
      // Rule 6 — already at the approved invariant for this pair.
      return;
    }

    // Rule 7 — write invariant members from admission targets directly.
    final batch = firestore.batch();
    batch.update(userRef, {'isActive': true});
    batch.update(profileRef, {'halaqaId': trimmedHalaqaId});
    batch.update(halaqaRef, {
      'studentIds': FieldValue.arrayUnion([trimmedStudentId]),
    });

    await batch.commit();
  }
}
