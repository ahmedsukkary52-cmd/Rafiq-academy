import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/academy_stats_entity.dart';
import '../entities/complaint_entity.dart';
import '../entities/financial_summary_entity.dart';
import '../entities/teacher_activity_entity.dart';
import '../entities/teacher_management_entity.dart';

/// ملخص بيانات معلم لشاشة "إدارة شؤون المعلمين" - بتجمع بين بيانات
/// users (الاسم) وteacherProfiles (النصاب والتقييم) في entity واحدة،
/// عشان شاشة الإدارة تعرض القائمة من غير ما تعمل دمج بنفسها.

/// سجل نشاط معلم خلال فترة معيّنة، مبني على الأيام اللي سجّل فيها
/// حضور لطلابه فعلياً. دي بيانات **مُستنتجة** (derived) من سجلات
/// attendanceRecords الموجودة أصلاً، مش مصدر بيانات منفصل بنكتبه إحنا.
///
/// ملاحظة مهمة لأحمد: ده مؤشر غير مباشر على حضور المعلم ("سجّل حضور
/// إذن كان موجود")، مش تسجيل دخول/حضور صريح للمعلم نفسه. لو التصميم
/// لاحقاً طلب "تشييك إن" صريح للمعلم، هنحتاج نضيف collection جديدة
/// مخصصة لده، الحل ده بديل عملي مؤقت من البيانات المتاحة حالياً.

abstract class AdminRepository {
  /// إحصائيات عامة للأكاديمية
  Future<Either<Failure, AcademyStatsEntity>> getAcademyStats();

  /// ملخص مالي
  Future<Either<Failure, FinancialSummaryEntity>> getFinancialSummary();

  /// قبول طالب جديد وتوزيعه على حلقة
  Future<Either<Failure, Unit>> approveNewStudent({
    required String studentId,
    required String halaqaId,
  });

  /// تفعيل أو تعطيل حساب
  Future<Either<Failure, Unit>> toggleAccountStatus({
    required String uid,
    required bool isActive,
  });

  /// الشكاوى الواردة
  Future<Either<Failure, List<ComplaintEntity>>> getComplaints();

  /// الرد على شكوى
  Future<Either<Failure, Unit>> respondToComplaint({
    required String complaintId,
    required String response,
  });

  /// إرسال إشعار موحّد لفئة معينة أو الكل
  Future<Either<Failure, Unit>> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole, // أو 'all'
  });

  /// قائمة كل المعلمين مع بيانات النصاب والتقييم - لشاشة إدارة المعلمين
  Future<Either<Failure, List<TeacherManagementEntity>>> getAllTeachers();

  /// تحديث تقييم أداء معلم
  Future<Either<Failure, Unit>> updateTeacherPerformance({
    required String teacherId,
    required double rating,
  });

  /// تحديد نصاب الحصص الأسبوعي لمعلم
  Future<Either<Failure, Unit>> updateTeacherQuota({
    required String teacherId,
    required int weeklyQuota,
  });

  /// سجل نشاط معلم (الأيام اللي سجّل فيها حضور لطلابه) خلال فترة معيّنة
  Future<Either<Failure, TeacherActivityEntity>> getTeacherActivityLog({
    required String teacherId,
    required DateTime from,
    required DateTime to,
  });
}

class ApproveStudentParams extends Equatable {
  final String studentId;
  final String halaqaId;

  const ApproveStudentParams({required this.studentId, required this.halaqaId});

  @override
  List<Object?> get props => [studentId, halaqaId];
}

class ToggleAccountParams extends Equatable {
  final String uid;
  final bool isActive;

  const ToggleAccountParams({required this.uid, required this.isActive});

  @override
  List<Object?> get props => [uid, isActive];
}

class RespondComplaintParams extends Equatable {
  final String complaintId;
  final String response;

  const RespondComplaintParams({
    required this.complaintId,
    required this.response,
  });

  @override
  List<Object?> get props => [complaintId, response];
}

class BroadcastParams extends Equatable {
  final String title;
  final String body;
  final String targetRole;

  const BroadcastParams({
    required this.title,
    required this.body,
    required this.targetRole,
  });

  @override
  List<Object?> get props => [title, body, targetRole];
}

class UpdateTeacherPerformanceParams extends Equatable {
  final String teacherId;
  final double rating;

  const UpdateTeacherPerformanceParams({
    required this.teacherId,
    required this.rating,
  });

  @override
  List<Object?> get props => [teacherId, rating];
}

class UpdateTeacherQuotaParams extends Equatable {
  final String teacherId;
  final int weeklyQuota;

  const UpdateTeacherQuotaParams({
    required this.teacherId,
    required this.weeklyQuota,
  });

  @override
  List<Object?> get props => [teacherId, weeklyQuota];
}

class TeacherActivityParams extends Equatable {
  final String teacherId;
  final DateTime from;
  final DateTime to;

  const TeacherActivityParams({
    required this.teacherId,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [teacherId, from, to];
}