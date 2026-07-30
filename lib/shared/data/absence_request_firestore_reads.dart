import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../domain/absence_request.dart';
import '../utils/attendance_policy.dart';
import 'absence_request_model.dart';

/// Shared استئذان Firestore reads (H4 / A-H5).
///
/// Consolidates unbounded `halaqaId` / `requestedBy` queries + client filters
/// used by teacher, supervisor, and parent. Does **not** change W7 ownership:
/// auth stays in feature use cases; review/submit stay on their writers.
class AbsenceRequestFirestoreReads {
  const AbsenceRequestFirestoreReads._();

  /// Teacher pending queue / supervisor day board building block.
  ///
  /// Query: `where(halaqaId)` then client day filter.
  /// When [pendingOnly] is true, also requires `status == pending`
  /// (teacher contract). Supervisor passes `pendingOnly: false`.
  static Future<List<AbsenceRequestModel>> forHalaqaOnDate({
    required FirebaseFirestore firestore,
    required String halaqaId,
    required DateTime date,
    bool pendingOnly = false,
  }) async {
    final id = halaqaId.trim();
    if (id.isEmpty) return const [];

    final snap = await firestore
        .collection(FirestoreCollections.absenceRequests)
        .where('halaqaId', isEqualTo: id)
        .get();

    return filterHalaqaDay(
      models: snap.docs.map(AbsenceRequestModel.fromFirestore),
      date: date,
      pendingOnly: pendingOnly,
    );
  }

  /// Parent own-history list (W7 Slice 1) — no day filter; date DESC.
  static Future<List<AbsenceRequestModel>> forParent({
    required FirebaseFirestore firestore,
    required String parentId,
  }) async {
    final uid = parentId.trim();
    if (uid.isEmpty) return const [];

    final snap = await firestore
        .collection(FirestoreCollections.absenceRequests)
        .where('requestedBy', isEqualTo: uid)
        .get();

    final items = snap.docs.map(AbsenceRequestModel.fromFirestore).toList();
    sortParentHistory(items);
    return items;
  }

  /// Pure client filter used after `where(halaqaId)` (W7 / A-H5 contract).
  static List<AbsenceRequestModel> filterHalaqaDay({
    required Iterable<AbsenceRequestModel> models,
    required DateTime date,
    bool pendingOnly = false,
  }) {
    final day = AttendancePolicy.dayStart(date);
    final items = <AbsenceRequestModel>[];
    for (final model in models) {
      if (pendingOnly && model.status != AbsenceRequestStatus.pending) {
        continue;
      }
      if (!AttendancePolicy.isSameCalendarDay(model.date, day)) continue;
      items.add(model);
    }
    return items;
  }

  /// Teacher sort: studentId ASC.
  static void sortTeacherPending(List<AbsenceRequestModel> items) {
    items.sort((a, b) => a.studentId.compareTo(b.studentId));
  }

  /// Supervisor sort: status index, then studentId.
  static void sortSupervisorDay(List<AbsenceRequestModel> items) {
    items.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      if (byStatus != 0) return byStatus;
      return a.studentId.compareTo(b.studentId);
    });
  }

  /// Parent history sort: date DESC.
  static void sortParentHistory(List<AbsenceRequestModel> items) {
    items.sort((a, b) => b.date.compareTo(a.date));
  }
}
