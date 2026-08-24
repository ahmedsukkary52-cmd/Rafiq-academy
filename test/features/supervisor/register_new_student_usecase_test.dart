import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/admit_student_to_halaqa_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/register_new_student_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/transfer_student_between_halaqat_usecase.dart';

class _FakeSupervisorRepository implements SupervisorRepository {
  AdmitStudentParams? lastAdmit;
  TransferStudentParams? lastTransfer;
  Either<Failure, Unit> result = const Right(unit);

  @override
  Future<Either<Failure, Unit>> admitStudentToHalaqa({
    required String supervisorId,
    required String halaqaId,
    required String studentId,
  }) async {
    lastAdmit = AdmitStudentParams(
      supervisorId: supervisorId,
      halaqaId: halaqaId,
      studentId: studentId,
    );
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
  group('AdmitStudentToHalaqaUseCase', () {
    test(
      'forwards params to SupervisorRepository.admitStudentToHalaqa',
      () async {
        final repo = _FakeSupervisorRepository();
        final useCase = AdmitStudentToHalaqaUseCase(repo);

        final result = await useCase(
          const AdmitStudentParams(
            supervisorId: 'sup1',
            halaqaId: 'h1',
            studentId: 's1',
          ),
        );

        expect(result, const Right(unit));
        expect(repo.lastAdmit?.supervisorId, 'sup1');
        expect(repo.lastAdmit?.halaqaId, 'h1');
        expect(repo.lastAdmit?.studentId, 's1');
      },
    );

    test('surfaces repository failure unchanged', () async {
      final repo = _FakeSupervisorRepository()
        ..result = const Left(ServerFailure('fail'));
      final useCase = AdmitStudentToHalaqaUseCase(repo);

      final result = await useCase(
        const AdmitStudentParams(
          supervisorId: 'sup1',
          halaqaId: 'h1',
          studentId: 's1',
        ),
      );

      expect(result, const Left(ServerFailure('fail')));
    });
  });

  group('RegisterNewStudentUseCase (admission alias)', () {
    test('delegates to admitStudentToHalaqa — not a partial writer', () async {
      final repo = _FakeSupervisorRepository();
      final useCase = RegisterNewStudentUseCase(repo);

      await useCase(
        const AdmitStudentParams(
          supervisorId: 'sup1',
          halaqaId: 'h1',
          studentId: 's1',
        ),
      );

      expect(repo.lastAdmit?.studentId, 's1');
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
  });
}
