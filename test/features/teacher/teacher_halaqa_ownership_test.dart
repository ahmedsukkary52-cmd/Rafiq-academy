import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/shared/domain/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/teacher_halaqa_ownership.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/save_day_attendance_usecase.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';

HalaqaEntity _halaqa(String id) => HalaqaEntity(
  id: id,
  name: id,
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: const ['s1'],
  schedule: const [],
  status: 'active',
);

AttendanceRecordEntity _record({
  required String halaqaId,
  String recordedBy = 't1',
}) {
  return AttendanceRecordEntity(
    id: 'a1',
    studentId: 's1',
    studentName: 'S',
    halaqaId: halaqaId,
    date: DateTime(2026, 9, 1),
    status: AttendanceStatus.present,
    recordedBy: recordedBy,
    sessionId: '${halaqaId}_20260901',
  );
}

class _FakeTeacherRepository implements TeacherRepository {
  final List<HalaqaEntity> halaqat;
  int saveCalls = 0;

  _FakeTeacherRepository({this.halaqat = const []});

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(
    String teacherId,
  ) async => Right(halaqat);

  @override
  Future<Either<Failure, AcademyEventPublication>> saveDayAttendance(
    List<AttendanceRecordEntity> records,
  ) async {
    saveCalls++;
    return const Right(AcademyEventPublication.none());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('ensureTeacherOwnsHalaqa', () {
    test('allows owned halaqa', () async {
      final repo = _FakeTeacherRepository(halaqat: [_halaqa('h1')]);
      final result = await ensureTeacherOwnsHalaqa(
        repository: repo,
        teacherId: 't1',
        halaqaId: 'h1',
      );
      expect(result.isRight(), isTrue);
    });

    test('rejects unowned halaqa', () async {
      final repo = _FakeTeacherRepository(halaqat: [_halaqa('h1')]);
      final result = await ensureTeacherOwnsHalaqa(
        repository: repo,
        teacherId: 't1',
        halaqaId: 'h2',
      );
      expect(result.isLeft(), isTrue);
    });
  });

  group('SaveDayAttendanceUseCase ownership', () {
    test('saves when teacher owns halaqa', () async {
      final repo = _FakeTeacherRepository(halaqat: [_halaqa('h1')]);
      final useCase = SaveDayAttendanceUseCase(repo);
      final result = await useCase([_record(halaqaId: 'h1')]);
      expect(result.isRight(), isTrue);
      expect(repo.saveCalls, 1);
    });

    test('blocks save for unowned halaqa', () async {
      final repo = _FakeTeacherRepository(halaqat: [_halaqa('h1')]);
      final useCase = SaveDayAttendanceUseCase(repo);
      final result = await useCase([_record(halaqaId: 'h2')]);
      expect(result.isLeft(), isTrue);
      expect(repo.saveCalls, 0);
    });
  });
}
