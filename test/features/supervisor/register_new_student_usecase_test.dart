import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/usecases/usecases.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/register_new_student_usecase.dart';

class _FakeSupervisorRepository implements SupervisorRepository {
  String? lastHalaqaId;
  String? lastStudentId;
  Either<Failure, Unit> result = const Right(unit);

  @override
  Future<Either<Failure, Unit>> registerNewStudent({
    required String halaqaId,
    required String studentId,
  }) async {
    lastHalaqaId = halaqaId;
    lastStudentId = studentId;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('RegisterNewStudentUseCase (H8 / A-H11 supervisor register)', () {
    test('forwards params to SupervisorRepository', () async {
      final repo = _FakeSupervisorRepository();
      final useCase = RegisterNewStudentUseCase(repo);

      final result = await useCase(
        const RegisterStudentParams(halaqaId: 'h1', studentId: 's1'),
      );

      expect(result, const Right(unit));
      expect(repo.lastHalaqaId, 'h1');
      expect(repo.lastStudentId, 's1');
    });

    test('surfaces repository failure unchanged', () async {
      final repo = _FakeSupervisorRepository()
        ..result = const Left(ServerFailure('fail'));
      final useCase = RegisterNewStudentUseCase(repo);

      final result = await useCase(
        const RegisterStudentParams(halaqaId: 'h1', studentId: 's1'),
      );

      expect(result, const Left(ServerFailure('fail')));
    });
  });
}
