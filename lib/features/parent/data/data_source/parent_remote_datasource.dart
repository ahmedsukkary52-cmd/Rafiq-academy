import '../../domain/entities/parent_entities.dart';
import '../models/parent_model.dart';

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

  Future<PaymentInitiationEntity> initiatePayment(String paymentId);
}
