import 'dart:typed_data';

import '../../../student/data/models/achievement_model.dart';
import '../../domain/parent_household.dart';
import '../models/parent_model.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../../../../shared/domain/payment_access_entity.dart';

abstract class ParentRemoteDatasource {
  Future<List<String>> getChildrenIds(String parentId);

  /// Reverse lookup: student UIDs → parent profile document IDs.
  ///
  /// Uses existing `parentProfiles.childrenIds` (no new fields). Returns only
  /// parents that list at least one of [studentIds].
  Future<Map<String, List<String>>> getParentIdsByStudentIds(
    List<String> studentIds,
  );

  Future<WeeklyReportModel> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  });
  Future<List<PaymentModel>> getPayments(String parentId);

  /// C3 — Parent-safe Vodafone destination from academySettings/paymentPublic.
  Future<PaymentPublicSettingsEntity> getPaymentPublicSettings();

  /// C2 — own paymentAccess doc (null if none yet).
  Future<PaymentAccessEntity?> getPaymentAccess(String parentId);

  /// تقديم طلب استئذان (contextual only — never writes attendance).
  ///
  /// Uses deterministic document id. Refuses to overwrite approved/rejected.
  Future<void> submitAbsenceRequest(AbsenceRequestModel request);

  Future<List<AbsenceRequestModel>> getAbsenceRequestsForParent(
    String parentId,
  );

  Future<List<({String id, String name})>> getHalaqatForStudent(
    String studentId,
  );

  /// Upload screenshot proof for external payment. Does **not** mark paid.
  Future<void> submitPaymentProof({
    required String parentId,
    required String paymentId,
    required String localFilePath,
  });

  /// Proof bytes read through Storage Rules; only a path inside
  /// `payment_proofs/{parentId}/{paymentId}/` is ever requested.
  Future<Uint8List> downloadPaymentProof({
    required String parentId,
    required String paymentId,
    required String storagePath,
  });

  Future<ParentHousehold> getHousehold({
    required String parentId,
    required List<String> childrenIds,
  });

  Future<List<ParentAttendanceMark>> getAttendanceMarks({
    required String studentId,
    required DateTime start,
    required DateTime endExclusive,
  });

  /// Achievements of one linked child via the `getParentAchievements`
  /// callable (parent list queries on `achievements` are denied by Rules).
  Future<List<AchievementModel>> getChildAchievements(String studentId);
}
