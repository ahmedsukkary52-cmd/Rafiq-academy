import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/save_day_attendance_usecase.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';

class _FakeTeacherRepository implements TeacherRepository {
  List<AttendanceRecordEntity>? lastRecords;
  Either<Failure, AcademyEventPublication> result =
      const Right(AcademyEventPublication.none());

  @override
  Future<Either<Failure, AcademyEventPublication>> saveDayAttendance(
    List<AttendanceRecordEntity> records,
  ) async {
    lastRecords = records;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('SaveDayAttendanceUseCase (H8 / A-H11 attendance save)', () {
    final records = [
      AttendanceRecordEntity(
        id: 'a1',
        studentId: 's1',
        studentName: 'طالب',
        halaqaId: 'h1',
        date: DateTime(2026, 7, 31),
        status: AttendanceStatus.present,
        recordedBy: 't1',
      ),
    ];

    test('forwards records and returns repository publication', () async {
      const publication = AcademyEventPublication(
        eventCount: 1,
        eventsPublished: true,
      );
      final repo = _FakeTeacherRepository()..result = const Right(publication);
      final useCase = SaveDayAttendanceUseCase(repo);

      final result = await useCase(records);

      expect(result, const Right(publication));
      expect(repo.lastRecords, records);
    });

    test('surfaces repository failure unchanged', () async {
      final repo = _FakeTeacherRepository()
        ..result = const Left(ServerFailure('offline'));
      final useCase = SaveDayAttendanceUseCase(repo);

      final result = await useCase(records);

      expect(result, const Left(ServerFailure('offline')));
    });
  });
}
