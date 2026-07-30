import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/send_assignment_usecase.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';

class _FakeTeacherRepository implements TeacherRepository {
  SendAssignmentParams? lastParams;
  Either<Failure, AcademyEventPublication> result =
      const Right(AcademyEventPublication.none());

  @override
  Future<Either<Failure, AcademyEventPublication>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) async {
    lastParams = SendAssignmentParams(
      halaqaId: halaqaId,
      newMemorizationRange: newMemorizationRange,
      reviewRange: reviewRange,
      dueDate: dueDate,
      teacherId: teacherId,
    );
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('SendAssignmentUseCase (H8 / A-H11 homework assign)', () {
    final due = DateTime(2026, 8, 1);
    final params = SendAssignmentParams(
      halaqaId: 'h1',
      newMemorizationRange: '2:1-10',
      reviewRange: '1:1-5',
      dueDate: due,
      teacherId: 't1',
    );

    test('forwards assignment params and returns publication', () async {
      const publication = AcademyEventPublication(
        eventCount: 2,
        eventsPublished: true,
      );
      final repo = _FakeTeacherRepository()..result = const Right(publication);
      final useCase = SendAssignmentUseCase(repo);

      final result = await useCase(params);

      expect(result, const Right(publication));
      expect(repo.lastParams, params);
    });

    test('surfaces repository failure unchanged', () async {
      final repo = _FakeTeacherRepository()
        ..result = const Left(ServerFailure('deny'));
      final useCase = SendAssignmentUseCase(repo);

      final result = await useCase(params);

      expect(result, const Left(ServerFailure('deny')));
    });
  });
}
