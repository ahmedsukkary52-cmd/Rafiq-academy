import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/usecases/usecases.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/approve_new_student_usecase.dart';

class _FakeAdminRepository implements AdminRepository {
  String? lastStudentId;
  String? lastHalaqaId;
  Either<Failure, Unit> result = const Right(unit);

  @override
  Future<Either<Failure, Unit>> approveNewStudent({
    required String studentId,
    required String halaqaId,
  }) async {
    lastStudentId = studentId;
    lastHalaqaId = halaqaId;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('ApproveNewStudentUseCase (H8 / A-H11 admit)', () {
    test('forwards studentId and halaqaId to AdminRepository', () async {
      final repo = _FakeAdminRepository();
      final useCase = ApproveNewStudentUseCase(repo);

      final result = await useCase(
        const ApproveStudentParams(studentId: 's1', halaqaId: 'h1'),
      );

      expect(result, const Right(unit));
      expect(repo.lastStudentId, 's1');
      expect(repo.lastHalaqaId, 'h1');
    });

    test('surfaces repository failure unchanged', () async {
      final repo = _FakeAdminRepository()
        ..result = const Left(ServerFailure('deny'));
      final useCase = ApproveNewStudentUseCase(repo);

      final result = await useCase(
        const ApproveStudentParams(studentId: 's1', halaqaId: 'h1'),
      );

      expect(result, const Left(ServerFailure('deny')));
    });
  });
}
