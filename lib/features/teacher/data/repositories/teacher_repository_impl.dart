import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../../student/data/models/recitation_record_model.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../domain/entities/attendance_record_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../data_sources/teacher_remote_datasource.dart';
import '../models/attendance_record_model.dart';

@LazySingleton(as: TeacherRepository)
class TeacherRepositoryImpl implements TeacherRepository {
  final TeacherRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const TeacherRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(
    String teacherId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getTeacherHalaqat(teacherId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String halaqaId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getHalaqaStudents(halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> recordAttendance(
    AttendanceRecordEntity record,
  ) async {
    return saveDayAttendance([record]);
  }

  @override
  Future<Either<Failure, Unit>> saveDayAttendance(
    List<AttendanceRecordEntity> records,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.saveDayAttendance(
        records
            .map(
              (record) => AttendanceRecordModel(
                id: record.id,
                studentId: record.studentId,
                studentName: record.studentName,
                halaqaId: record.halaqaId,
                date: record.date,
                status: record.status,
                recordedBy: record.recordedBy,
              ),
            )
            .toList(),
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getHalaqaAttendanceForDate(
          halaqaId: halaqaId,
          date: date,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> addRecitationRecord(
    RecitationRecordEntity record,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.addRecitationRecord(
        RecitationRecordModel(
          id: record.id,
          studentId: record.studentId,
          teacherId: record.teacherId,
          halaqaId: record.halaqaId,
          date: record.date,
          type: record.type,
          versesRange: record.versesRange,
          grade: record.grade,
          notes: record.notes,
          studentName: record.studentName,
          behaviorGrade: record.behaviorGrade,
        ),
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateRecitationReview(
    UpdateRecitationReviewParams params,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.updateRecitationReview(
        recordId: params.recordId,
        grade: params.grade,
        behaviorGrade: params.behaviorGrade,
        notes: params.notes,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getHalaqaRecitationRecords(halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.sendAssignment(
        halaqaId: halaqaId,
        newMemorizationRange: newMemorizationRange,
        reviewRange: reviewRange,
        dueDate: dueDate,
        teacherId: teacherId,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
