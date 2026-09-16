import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/student_search_contract.dart';
import '../entities/student_search_entry.dart';
import '../repositories/student_search_repository.dart';

/// C13 / WA-14 — one use case per frozen query shape, so no caller can
/// assemble an unscoped staff query by accident.

class ScopedStudentSearchParams extends Equatable {
  /// The signed-in staff uid; must match `visibleTo` for Rules to allow it.
  final String viewerUid;
  final String query;
  final int limit;

  const ScopedStudentSearchParams({
    required this.viewerUid,
    required this.query,
    this.limit = StudentSearchContract.defaultSearchLimit,
  });

  @override
  List<Object?> get props => [viewerUid, query, limit];
}

class GlobalStudentSearchParams extends Equatable {
  final String query;
  final int limit;

  const GlobalStudentSearchParams({
    required this.query,
    this.limit = StudentSearchContract.defaultSearchLimit,
  });

  @override
  List<Object?> get props => [query, limit];
}

class HalaqaStudentSearchParams extends Equatable {
  final String halaqaId;
  final String query;
  final int limit;

  const HalaqaStudentSearchParams({
    required this.halaqaId,
    this.query = '',
    this.limit = StudentSearchContract.defaultSearchLimit,
  });

  @override
  List<Object?> get props => [halaqaId, query, limit];
}

/// Teacher / Supervisor directory search, scoped by roster-derived visibility.
@lazySingleton
class SearchStudentsInScopeUseCase
    extends UseCase<List<StudentSearchEntry>, ScopedStudentSearchParams> {
  final StudentSearchRepository repository;

  SearchStudentsInScopeUseCase(this.repository);

  @override
  Future<Either<Failure, List<StudentSearchEntry>>> call(
    ScopedStudentSearchParams params,
  ) => repository.searchInViewerScope(
    viewerUid: params.viewerUid,
    query: params.query,
    limit: params.limit,
  );
}

/// Admin global directory search (prefix-only by frozen contract).
@lazySingleton
class SearchAllStudentsUseCase
    extends UseCase<List<StudentSearchEntry>, GlobalStudentSearchParams> {
  final StudentSearchRepository repository;

  SearchAllStudentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<StudentSearchEntry>>> call(
    GlobalStudentSearchParams params,
  ) => repository.searchAll(query: params.query, limit: params.limit);
}

/// Admin halaqa-scoped search — resolve a halaqa name to its id first, then
/// filter here. `studentSearch` intentionally stores no normalized halaqa name.
@lazySingleton
class SearchStudentsInHalaqaUseCase
    extends UseCase<List<StudentSearchEntry>, HalaqaStudentSearchParams> {
  final StudentSearchRepository repository;

  SearchStudentsInHalaqaUseCase(this.repository);

  @override
  Future<Either<Failure, List<StudentSearchEntry>>> call(
    HalaqaStudentSearchParams params,
  ) => repository.searchInHalaqa(
    halaqaId: params.halaqaId,
    query: params.query,
    limit: params.limit,
  );
}

/// Direct identity lookup by the real `studentId`.
@lazySingleton
class GetStudentSearchEntryUseCase
    extends UseCase<StudentSearchEntry?, String> {
  final StudentSearchRepository repository;

  GetStudentSearchEntryUseCase(this.repository);

  @override
  Future<Either<Failure, StudentSearchEntry?>> call(String studentId) =>
      repository.getByStudentId(studentId);
}
