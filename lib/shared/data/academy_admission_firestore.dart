import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/exception.dart';
import '../domain/academy_membership_invariant.dart';

/// Firestore realization of **Academy Admission Workflow** (Dual-Halaqa).
///
/// Establishes / moves membership using `halaqat.studentIds` + `users.isActive`
/// + role gate. `studentProfiles.halaqaId` is updated only as primary UI pointer
/// per Dual-Halaqa primary rules — never as membership SSOT.
///
/// Cap: [AcademyMembershipInvariant.maxHalaqatPerStudent].
class AcademyAdmissionFirestore {
  const AcademyAdmissionFirestore._();

  /// Preconditions: user exists and `role == student`.
  /// Writes atomically: `isActive=true`, roster `arrayUnion`, and primary only
  /// when [AcademyMembershipInvariant.shouldSetPrimaryOnEstablish] is true.
  ///
  /// Enforces dual-halaqa cap. Idempotent when the pair is already complete.
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
      throw const ServerException(
        'لا يمكن إتمام العضوية: دور المستخدم ليس طالباً',
      );
    }

    final profileSnap = await profileRef.get();
    if (!profileSnap.exists) {
      throw const ServerException('ملف الطالب غير موجود');
    }

    final halaqaSnap = await halaqaRef.get();
    if (!halaqaSnap.exists) {
      throw const ServerException('الحلقة غير موجودة');
    }

    final membershipIds = await _membershipHalaqaIds(
      firestore: firestore,
      studentId: trimmedStudentId,
    );
    final alreadyOnTarget = membershipIds.contains(trimmedHalaqaId);
    final isActive = userData['isActive'] as bool?;
    final roleStr = role is String ? role : null;

    if (AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: alreadyOnTarget,
          role: roleStr,
          isActive: isActive,
        ) &&
        isActive == true) {
      return;
    }

    if (!alreadyOnTarget &&
        membershipIds.length >=
            AcademyMembershipInvariant.maxHalaqatPerStudent) {
      throw const ServerException('الطالب وصل للحد الأقصى (حلقتان)');
    }

    final currentPrimary = profileSnap.data()?['halaqaId'] as String?;
    final others = membershipIds.where((id) => id != trimmedHalaqaId);
    final setPrimary = AcademyMembershipInvariant.shouldSetPrimaryOnEstablish(
      currentPrimary: currentPrimary,
      membershipHalaqaIdsExcludingTarget: others,
    );

    final batch = firestore.batch();
    batch.update(userRef, {'isActive': true});
    batch.update(halaqaRef, {
      'studentIds': FieldValue.arrayUnion([trimmedStudentId]),
    });
    if (setPrimary) {
      batch.update(profileRef, {'halaqaId': trimmedHalaqaId});
    }

    await batch.commit();
  }

  /// Atomic move: `arrayRemove(source)` + `arrayUnion(target)` + primary rules.
  ///
  /// Does not create a pending/approval state. Cap is preserved (1 out, 1 in).
  static Future<void> transferMembership({
    required FirebaseFirestore firestore,
    required String studentId,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  }) async {
    final trimmedStudentId = studentId.trim();
    final source = sourceHalaqaId.trim();
    final target = targetHalaqaId.trim();
    if (trimmedStudentId.isEmpty || source.isEmpty || target.isEmpty) {
      throw const ServerException('معرّف الطالب أو الحلقة غير صالح');
    }
    if (source == target) {
      throw const ServerException('المصدر والهدف يجب أن يختلفا');
    }

    final userRef = firestore
        .collection(FirestoreCollections.users)
        .doc(trimmedStudentId);
    final profileRef = firestore
        .collection(FirestoreCollections.studentProfiles)
        .doc(trimmedStudentId);
    final sourceRef = firestore
        .collection(FirestoreCollections.halaqat)
        .doc(source);
    final targetRef = firestore
        .collection(FirestoreCollections.halaqat)
        .doc(target);

    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw const ServerException('الطالب غير موجود');
    }
    final userData = userSnap.data() ?? const <String, dynamic>{};
    if (userData['role'] != AppRoles.student) {
      throw const ServerException(
        'لا يمكن إتمام النقل: دور المستخدم ليس طالباً',
      );
    }

    final profileSnap = await profileRef.get();
    if (!profileSnap.exists) {
      throw const ServerException('ملف الطالب غير موجود');
    }

    final sourceSnap = await sourceRef.get();
    final targetSnap = await targetRef.get();
    if (!sourceSnap.exists || !targetSnap.exists) {
      throw const ServerException('الحلقة غير موجودة');
    }

    final membershipIds = await _membershipHalaqaIds(
      firestore: firestore,
      studentId: trimmedStudentId,
    );
    if (!membershipIds.contains(source)) {
      throw const ServerException('الطالب ليس عضوًا في الحلقة المصدر');
    }

    final alreadyOnTarget = membershipIds.contains(target);
    // After remove(source)+add(target): size = len - 1 + (alreadyOnTarget ? 0 : 1)
    final resultingCount = membershipIds.length - 1 + (alreadyOnTarget ? 0 : 1);
    if (resultingCount > AcademyMembershipInvariant.maxHalaqatPerStudent) {
      throw const ServerException('الطالب وصل للحد الأقصى (حلقتان)');
    }

    final currentPrimary = profileSnap.data()?['halaqaId'] as String?;
    final nextPrimary = AcademyMembershipInvariant.primaryAfterTransfer(
      currentPrimary: currentPrimary,
      sourceHalaqaId: source,
      targetHalaqaId: target,
    );
    final remaining = <String>{
      for (final id in membershipIds)
        if (id != source) id,
      target,
    };
    final resolvedPrimary =
        AcademyMembershipInvariant.primaryAfterMembershipsChanged(
          currentPrimary: nextPrimary,
          remainingHalaqaIds: remaining,
        );

    final batch = firestore.batch();
    batch.update(userRef, {'isActive': true});
    batch.update(sourceRef, {
      'studentIds': FieldValue.arrayRemove([trimmedStudentId]),
    });
    batch.update(targetRef, {
      'studentIds': FieldValue.arrayUnion([trimmedStudentId]),
    });
    batch.update(profileRef, {'halaqaId': resolvedPrimary});

    await batch.commit();
  }

  static Future<List<String>> _membershipHalaqaIds({
    required FirebaseFirestore firestore,
    required String studentId,
  }) async {
    final snap = await firestore
        .collection(FirestoreCollections.halaqat)
        .where('studentIds', arrayContains: studentId)
        .get();
    return snap.docs.map((d) => d.id).toList(growable: false);
  }
}
