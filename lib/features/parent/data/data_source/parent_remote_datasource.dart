import '../../domain/entities/parent_entities.dart';
import '../models/parent_model.dart';

abstract class ParentRemoteDatasource {
  Future<List<String>> getChildrenIds(String parentId);
  Future<WeeklyReportModel> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  });
  Future<List<PaymentModel>> getPayments(String parentId);
  Future<void> submitAbsenceRequest(AbsenceRequestModel request);

  Future<PaymentInitiationEntity> initiatePayment(String paymentId);
}
