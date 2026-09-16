import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../../../shared/domain/student_search_contract.dart';
import '../../domain/entities/student_search_entry.dart';
import '../../domain/repositories/student_search_repository.dart';
import '../datasources/student_search_remote_datasource.dart';

@LazySingleton(as: StudentSearchRepository)
class StudentSearchRepositoryImpl implements StudentSearchRepository {
  final StudentSearchRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const StudentSearchRepositoryImpl({
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

  @override
  Future<Either<Failure, List<StudentSearchEntry>>> searchInViewerScope({
    required String viewerUid,
    required String query,
    int limit = StudentSearchContract.defaultSearchLimit,
  }) {
    return _guard(
      () => remoteDatasource.searchInViewerScope(
        viewerUid: viewerUid,
        query: query,
        limit: limit,
      ),
    );
  }

  @override
  Future<Either<Failure, List<StudentSearchEntry>>> searchAll({
    required String query,
    int limit = StudentSearchContract.defaultSearchLimit,
  }) {
    return _guard(() => remoteDatasource.searchAll(query: query, limit: limit));
  }

  @override
  Future<Either<Failure, List<StudentSearchEntry>>> searchInHalaqa({
    required String halaqaId,
    required String query,
    int limit = StudentSearchContract.defaultSearchLimit,
  }) {
    return _guard(
      () => remoteDatasource.searchInHalaqa(
        halaqaId: halaqaId,
        query: query,
        limit: limit,
      ),
    );
  }

  @override
  Future<Either<Failure, StudentSearchEntry?>> getByStudentId(
    String studentId,
  ) {
    return _guard(() => remoteDatasource.getByStudentId(studentId));
  }
}
