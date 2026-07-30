import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/parent_entities.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Repository Interface
// ══════════════════════════════════════════════════════════════════════════════

abstract class ParentRepository {
  /// جلب معرّفات أبناء ولي الأمر
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId);

  /// Reverse lookup: student UIDs → linked parent profile IDs.
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  );

  /// التقرير الأسبوعي للطالب
  Future<Either<Failure, WeeklyReportEntity>> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  });

  /// سجل المدفوعات والاشتراكات
  Future<Either<Failure, List<PaymentEntity>>> getPayments(String parentId);

  /// تقديم طلب استئذان عن حصة
  Future<Either<Failure, Unit>> submitAbsenceRequest(
    AbsenceRequestEntity request,
  );

  /// List استئذان submitted by this parent (contextual docs only).
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForParent(String parentId);

  /// Halaqat containing [studentId] for scoped request submit.
  Future<Either<Failure, List<ParentHalaqaOption>>> getHalaqatForStudent(
    String studentId,
  );

  /// Stream لمتابعة التكليفات الجديدة real-time
  Stream<Either<Failure, List<String>>> watchChildrenAssignments(
    String parentId,
  );

  /// بدء عملية دفع جديدة عن طريق Cloud Function وسيطة (راجع
  /// functions/src/paymob/createPaymentIntention.ts) - المبلغ بيتقرأ
  /// من Firestore على السيرفر، مش من التطبيق، لأسباب أمان.
  Future<Either<Failure, PaymentInitiationEntity>> initiatePayment(
    String paymentId,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Params
// ══════════════════════════════════════════════════════════════════════════════

class PaymentIdParams extends Equatable {
  final String paymentId;

  const PaymentIdParams(this.paymentId);

  @override
  List<Object?> get props => [paymentId];
}

class ParentIdParams extends Equatable {
  final String parentId;
  const ParentIdParams(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

class WeeklyReportParams extends Equatable {
  final String studentId;
  final DateTime weekStart;
  const WeeklyReportParams({required this.studentId, required this.weekStart});

  @override
  List<Object?> get props => [studentId, weekStart];
}

/// Minimal halaqa choice for parent استئذان submit (W7).
class ParentHalaqaOption extends Equatable {
  final String id;
  final String name;

  const ParentHalaqaOption({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
