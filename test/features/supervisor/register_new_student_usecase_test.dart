import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/usecases/usecases.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/register_new_student_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/transfer_student_between_halaqat_usecase.dart';

class _FakeSupervisorRepository implements SupervisorRepository {
  String? lastHalaqaId;
  String? lastStudentId;
  TransferStudentParams? lastTransfer;
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
  Future<Either<Failure, Unit>> transferStudentBetweenHalaqat({
    required String supervisorId,
    required String studentId,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  }) async {
    lastTransfer = TransferStudentParams(
      supervisorId: supervisorId,
      studentId: studentId,
      sourceHalaqaId: sourceHalaqaId,
      targetHalaqaId: targetHalaqaId,
    );
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

  group('TransferStudentBetweenHalaqatUseCase', () {
    test('forwards transfer params', () async {
      final repo = _FakeSupervisorRepository();
      final useCase = TransferStudentBetweenHalaqatUseCase(repo);

      final result = await useCase(
        const TransferStudentParams(
          supervisorId: 'sup1',
          studentId: 's1',
          sourceHalaqaId: 'h1',
          targetHalaqaId: 'h2',
        ),
      );

      expect(result, const Right(unit));
      expect(repo.lastTransfer?.sourceHalaqaId, 'h1');
      expect(repo.lastTransfer?.targetHalaqaId, 'h2');
    });

    test('surfaces repository failure unchanged', () async {
      final repo = _FakeSupervisorRepository()
        ..result = const Left(ServerFailure('fail'));
      final useCase = TransferStudentBetweenHalaqatUseCase(repo);

      final result = await useCase(
        const TransferStudentParams(
          supervisorId: 'sup1',
          studentId: 's1',
          sourceHalaqaId: 'h1',
          targetHalaqaId: 'h2',
        ),
      );

      expect(result, const Left(ServerFailure('fail')));
    });
  });
}
