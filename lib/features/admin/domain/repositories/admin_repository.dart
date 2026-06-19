import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/academy_stats_entity.dart';
import '../entities/complaint_entity.dart';
import '../entities/financial_summary_entity.dart';

abstract class AdminRepository {
  Future<Either<Failure, AcademyStatsEntity>> getAcademyStats();

  Future<Either<Failure, FinancialSummaryEntity>> getFinancialSummary();

  Future<Either<Failure, Unit>> approveNewStudent({
    required String studentId,
    required String halaqaId,
  });

  Future<Either<Failure, Unit>> toggleAccountStatus({
    required String uid,
    required bool isActive,
  });

  Future<Either<Failure, List<ComplaintEntity>>> getComplaints();

  Future<Either<Failure, Unit>> respondToComplaint({
    required String complaintId,
    required String response,
  });

  Future<Either<Failure, Unit>> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// Use Cases
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
// Params
// ══════════════════════════════════════════════════════════════════════════════

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
