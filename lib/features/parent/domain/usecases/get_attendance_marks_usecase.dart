import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../parent_household.dart';
import '../repositories/parent_repositories.dart';

class AttendanceMarksParams extends Equatable {
  final String parentId;
  final String studentId;
  final DateTime start;
  final DateTime endExclusive;

  const AttendanceMarksParams({
    required this.parentId,
    required this.studentId,
    required this.start,
    required this.endExclusive,
  });

  @override
  List<Object?> get props => [parentId, studentId, start, endExclusive];
}

@lazySingleton
class GetAttendanceMarksUseCase
    extends UseCase<List<ParentAttendanceMark>, AttendanceMarksParams> {
  final ParentRepository repository;

  GetAttendanceMarksUseCase(this.repository);

  @override
  Future<Either<Failure, List<ParentAttendanceMark>>> call(
    AttendanceMarksParams params,
  ) async {
    final parentId = params.parentId.trim();
    final studentId = params.studentId.trim();
    if (parentId.isEmpty) {
      return const Left(ValidationFailure('معرّف ولي الأمر مطلوب'));
    }
    if (studentId.isEmpty) {
      return const Left(ValidationFailure('معرّف الطالب مطلوب'));
    }

    final childrenEither = await repository.getChildrenIds(parentId);
    final childrenFailure = childrenEither.fold<Failure?>(
      (l) => l,
      (_) => null,
    );
    if (childrenFailure != null) return Left(childrenFailure);

    final children = childrenEither
        .getOrElse((_) => const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (!children.contains(studentId)) {
      return const Left(
        ValidationFailure('لا يمكن عرض حضور طالب غير مرتبط بولي الأمر'),
      );
    }

    return repository.getAttendanceMarks(
      studentId: studentId,
      start: params.start,
      endExclusive: params.endExclusive,
    );
  }
}
