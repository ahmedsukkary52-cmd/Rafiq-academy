import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/parent_repositories.dart';

class StudentHalaqatParams extends Equatable {
  final String parentId;
  final String studentId;

  const StudentHalaqatParams({required this.parentId, required this.studentId});

  @override
  List<Object?> get props => [parentId, studentId];
}

/// Resolves halaqat for a child **after** parent→child authorization (W7 Slice 1).
@lazySingleton
class GetHalaqatForStudentUseCase
    extends UseCase<List<ParentHalaqaOption>, StudentHalaqatParams> {
  final ParentRepository repository;

  GetHalaqatForStudentUseCase(this.repository);

  @override
  Future<Either<Failure, List<ParentHalaqaOption>>> call(
    StudentHalaqatParams params,
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
        ValidationFailure('لا يمكن عرض حلقات طالب غير مرتبط بولي الأمر'),
      );
    }

    return repository.getHalaqatForStudent(studentId);
  }
}
