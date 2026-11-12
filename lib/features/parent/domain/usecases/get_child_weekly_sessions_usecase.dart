import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../schedule/domain/entities/class_session_entity.dart';
import '../../../schedule/domain/mappers/halaqa_weekly_sessions_mapper.dart';
import '../repositories/parent_repositories.dart';

class ChildWeeklySessionsParams extends Equatable {
  final String studentId;
  final String halaqaId;

  const ChildWeeklySessionsParams({
    required this.studentId,
    required this.halaqaId,
  });

  @override
  List<Object?> get props => [studentId, halaqaId];
}

/// Parent view of a linked child's weekly Halaqa sessions. The callable
/// resolves the parent from the auth token and rejects children not in their
/// profile or not on the Halaqa roster.
///
/// Not registered in the generated DI config (OA-56, not regenerated); callers
/// construct it with the registered [ParentRepository].
class GetChildWeeklySessionsUseCase
    extends UseCase<List<ClassSessionEntity>, ChildWeeklySessionsParams> {
  final ParentRepository repository;
  final HalaqaWeeklySessionsMapper _mapper;
  final DateTime Function() _now;

  GetChildWeeklySessionsUseCase(this.repository, {DateTime Function()? now})
    : _mapper = const HalaqaWeeklySessionsMapper(),
      _now = now ?? DateTime.now;

  @override
  Future<Either<Failure, List<ClassSessionEntity>>> call(
    ChildWeeklySessionsParams params,
  ) async {
    final studentId = params.studentId.trim();
    final halaqaId = params.halaqaId.trim();
    if (studentId.isEmpty) {
      return const Left(ValidationFailure('معرّف الطالب مطلوب'));
    }
    if (halaqaId.isEmpty) return const Right([]);
    final source = await repository.getChildHalaqaSchedule(
      studentId: studentId,
      halaqaId: halaqaId,
    );
    return source.map((s) => _mapper.map(s, now: _now()));
  }
}
