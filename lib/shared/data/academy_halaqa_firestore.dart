import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/exception.dart';

/// Shared halaqa creation write path — single source of truth for new halaqat.
class AcademyHalaqaFirestore {
  const AcademyHalaqaFirestore._();

  static const String activeStatus = 'active';

  /// Creates a halaqa document and links it to the teacher profile when present.
  static Future<String> createHalaqa({
    required FirebaseFirestore firestore,
    required String name,
    required String teacherId,
    required String supervisorId,
    String meetingLink = '',
    List<Map<String, dynamic>> schedule = const [],
  }) async {
    final trimmedName = name.trim();
    final trimmedTeacherId = teacherId.trim();
    final trimmedSupervisorId = supervisorId.trim();
    if (trimmedName.isEmpty) {
      throw const ServerException('اسم الحلقة مطلوب');
    }
    if (trimmedTeacherId.isEmpty || trimmedSupervisorId.isEmpty) {
      throw const ServerException('المعلم والمشرف مطلوبان');
    }

    final halaqaRef = firestore.collection(FirestoreCollections.halaqat).doc();
    final batch = firestore.batch();

    batch.set(halaqaRef, {
      'name': trimmedName,
      'teacherId': trimmedTeacherId,
      'supervisorId': trimmedSupervisorId,
      'studentIds': const <String>[],
      'schedule': schedule,
      'meetingLink': meetingLink.trim(),
      'status': activeStatus,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final teacherProfileRef = firestore
        .collection(FirestoreCollections.teacherProfiles)
        .doc(trimmedTeacherId);
    final teacherProfileSnap = await teacherProfileRef.get();
    if (teacherProfileSnap.exists) {
      batch.update(teacherProfileRef, {
        'halaqatIds': FieldValue.arrayUnion([halaqaRef.id]),
      });
    }

    await batch.commit();
    return halaqaRef.id;
  }

  /// Updates teacher/supervisor on an existing halaqa (registration assignment).
  static Future<void> assignStaff({
    required FirebaseFirestore firestore,
    required String halaqaId,
    String? teacherId,
    String? supervisorId,
  }) async {
    final trimmedHalaqaId = halaqaId.trim();
    if (trimmedHalaqaId.isEmpty) {
      throw const ServerException('معرّف الحلقة غير صالح');
    }

    final updates = <String, dynamic>{};
    final trimmedTeacher = teacherId?.trim();
    final trimmedSupervisor = supervisorId?.trim();
    if (trimmedTeacher != null && trimmedTeacher.isNotEmpty) {
      updates['teacherId'] = trimmedTeacher;
    }
    if (trimmedSupervisor != null && trimmedSupervisor.isNotEmpty) {
      updates['supervisorId'] = trimmedSupervisor;
    }
    if (updates.isEmpty) return;

    await firestore
        .collection(FirestoreCollections.halaqat)
        .doc(trimmedHalaqaId)
        .update(updates);
  }
}
