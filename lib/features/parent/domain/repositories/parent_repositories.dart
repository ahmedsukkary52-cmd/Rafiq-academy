import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../../../../shared/domain/payment_access_entity.dart';
import '../../../../shared/domain/payment_proof_reader.dart';
import '../../../../shared/domain/student_parent_links.dart';
import '../../../../shared/domain/achievement_entity.dart';
import '../entities/parent_entities.dart';
import '../parent_household.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Repository Interface
// ══════════════════════════════════════════════════════════════════════════════

abstract class ParentRepository
    implements PaymentProofReader, StudentParentLinkReader {
  /// جلب معرّفات أبناء ولي الأمر
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId);

  /// Reverse lookup: student UIDs → linked parent profile IDs.
  @override
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

  /// C3 — Parent-readable Vodafone destination.
  Future<Either<Failure, PaymentPublicSettingsEntity>>
  getPaymentPublicSettings();

  /// C2 — own paymentAccess (null if not created yet).
  Future<Either<Failure, PaymentAccessEntity?>> getPaymentAccess(
    String parentId,
  );

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

  /// Parent screenshot proof for external payment. Never marks payment paid.
  Future<Either<Failure, Unit>> submitPaymentProof({
    required String parentId,
    required String paymentId,
    required String localFilePath,
  });

  /// Proof image for Parent / Admin / scoped Supervisor review.
  @override
  Future<Either<Failure, Uint8List>> downloadPaymentProof({
    required String parentId,
    required String paymentId,
    required String storagePath,
  });

  Future<Either<Failure, ParentHousehold>> getHousehold({
    required String parentId,
    required List<String> childrenIds,
  });

  Future<Either<Failure, List<ParentAttendanceMark>>> getAttendanceMarks({
    required String studentId,
    required DateTime start,
    required DateTime endExclusive,
  });

  /// Achievements of one linked child, served by the parent-scoped callable.
  Future<Either<Failure, List<AchievementEntity>>> getChildAchievements(
    String studentId,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Params
// ══════════════════════════════════════════════════════════════════════════════

class ParentIdParams extends Equatable {
  final String parentId;
  const ParentIdParams(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

class WeeklyReportParams extends Equatable {
  final String parentId;
  final String studentId;
  final DateTime weekStart;
  const WeeklyReportParams({
    required this.parentId,
    required this.studentId,
    required this.weekStart,
  });

  @override
  List<Object?> get props => [parentId, studentId, weekStart];
}

/// Minimal halaqa choice for parent استئذان submit (W7).
class ParentHalaqaOption extends Equatable {
  final String id;
  final String name;

  const ParentHalaqaOption({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
