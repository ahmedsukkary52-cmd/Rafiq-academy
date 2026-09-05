import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/admin_grant_reward_params.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../../domain/entities/admin_halaqa_roster_entity.dart';
import '../../domain/entities/communication_settings_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';

@LazySingleton(as: AdminRepository)
class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const AdminRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await run());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  Future<Either<Failure, Unit>> _guardUnit(Future<void> Function() run) async {
    final result = await _guard(run);
    return result.map((_) => unit);
  }

  @override
  Future<Either<Failure, AcademyStatsEntity>> getAcademyStats() =>
      _guard(remoteDatasource.getAcademyStats);

  @override
  Future<Either<Failure, FinancialSummaryEntity>> getFinancialSummary() =>
      _guard(remoteDatasource.getFinancialSummary);

  @override
  Future<Either<Failure, Unit>> approveNewStudent({
    required String studentId,
    required String halaqaId,
  }) => _guardUnit(
    () => remoteDatasource.approveNewStudent(
      studentId: studentId,
      halaqaId: halaqaId,
    ),
  );

  @override
  Future<Either<Failure, Unit>> toggleAccountStatus({
    required String uid,
    required bool isActive,
  }) => _guardUnit(
    () => remoteDatasource.toggleAccountStatus(uid: uid, isActive: isActive),
  );

  @override
  Future<Either<Failure, List<ComplaintEntity>>> getComplaints() =>
      _guard(remoteDatasource.getComplaints);

  @override
  Future<Either<Failure, Unit>> respondToComplaint({
    required String complaintId,
    required String response,
  }) => _guardUnit(
    () => remoteDatasource.respondToComplaint(
      complaintId: complaintId,
      response: response,
    ),
  );

  @override
  Future<Either<Failure, Unit>> updateComplaint({
    required String complaintId,
    String? status,
    String? priority,
    String? assigneeId,
    String? assigneeRole,
    String? response,
  }) => _guardUnit(
    () => remoteDatasource.updateComplaint(
      complaintId: complaintId,
      status: status,
      priority: priority,
      assigneeId: assigneeId,
      assigneeRole: assigneeRole,
      response: response,
    ),
  );

  @override
  Future<Either<Failure, Unit>> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole,
  }) => _guardUnit(
    () => remoteDatasource.sendBroadcastNotification(
      title: title,
      body: body,
      targetRole: targetRole,
    ),
  );

  @override
  Future<Either<Failure, List<TeacherManagementEntity>>> getAllTeachers() =>
      _guard(remoteDatasource.getAllTeachers);

  @override
  Future<Either<Failure, Unit>> updateTeacherPerformance({
    required String teacherId,
    required double rating,
  }) => _guardUnit(
    () => remoteDatasource.updateTeacherPerformance(
      teacherId: teacherId,
      rating: rating,
    ),
  );

  @override
  Future<Either<Failure, Unit>> updateTeacherQuota({
    required String teacherId,
    required int weeklyQuota,
  }) => _guardUnit(
    () => remoteDatasource.updateTeacherQuota(
      teacherId: teacherId,
      weeklyQuota: weeklyQuota,
    ),
  );

  @override
  Future<Either<Failure, TeacherActivityEntity>> getTeacherActivityLog({
    required String teacherId,
    required DateTime from,
    required DateTime to,
  }) => _guard(
    () => remoteDatasource.getTeacherActivityLog(
      teacherId: teacherId,
      from: from,
      to: to,
    ),
  );

  @override
  Future<Either<Failure, List<AdminHalaqaRosterEntity>>>
  getAcademyStudentRoster() => _guard(remoteDatasource.getAcademyStudentRoster);

  @override
  Future<Either<Failure, List<RegistrationRequestEntity>>>
  getRegistrationRequests() => _guard(remoteDatasource.getRegistrationRequests);

  @override
  Future<Either<Failure, Unit>> rejectRegistrationRequest({
    required String studentId,
  }) => _guardUnit(
    () => remoteDatasource.rejectRegistrationRequest(studentId: studentId),
  );

  @override
  Future<Either<Failure, Unit>> approveRegistrationRequest({
    required String studentId,
    required String halaqaId,
    String? teacherId,
    String? supervisorId,
  }) => _guardUnit(
    () => remoteDatasource.approveRegistrationRequest(
      studentId: studentId,
      halaqaId: halaqaId,
      teacherId: teacherId,
      supervisorId: supervisorId,
    ),
  );

  @override
  Future<Either<Failure, List<AdminHalaqaSummaryEntity>>> getAllHalaqat() =>
      _guard(remoteDatasource.getAllHalaqat);

  @override
  Future<Either<Failure, List<AdminStaffSummaryEntity>>> getAllSupervisors() =>
      _guard(remoteDatasource.getAllSupervisors);

  @override
  Future<Either<Failure, CommunicationSettingsEntity>>
  getCommunicationSettings() =>
      _guard(remoteDatasource.getCommunicationSettings);

  @override
  Future<Either<Failure, Unit>> saveCommunicationSettings(
    CommunicationSettingsEntity settings,
  ) => _guardUnit(() => remoteDatasource.saveCommunicationSettings(settings));

  @override
  Future<Either<Failure, Unit>> grantReward(AdminGrantRewardParams params) =>
      _guardUnit(() => remoteDatasource.grantReward(params));

  @override
  Future<Either<Failure, String>> createHalaqa({
    required String name,
    required String teacherId,
    required String supervisorId,
    String meetingLink = '',
  }) => _guard(
    () => remoteDatasource.createHalaqa(
      name: name,
      teacherId: teacherId,
      supervisorId: supervisorId,
      meetingLink: meetingLink,
    ),
  );

  @override
  Future<Either<Failure, String>> ensureAdminInternalChat({
    required String adminUid,
  }) => _guard(
    () => remoteDatasource.ensureAdminInternalChat(adminUid: adminUid),
  );
}
