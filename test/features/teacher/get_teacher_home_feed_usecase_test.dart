import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/awards/domain/repositories/awards_repository.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/read_models/teacher_recent_activity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_teacher_home_feed_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_today_agenda_usecase.dart';

final _monday = DateTime(2024, 6, 3, 9, 0);

HalaqaEntity _halaqa({
  required String id,
  List<String> studentIds = const ['s1'],
  String day = 'monday',
  String start = '09:00',
  String end = '10:00',
}) {
  return HalaqaEntity(
    id: id,
    name: 'حلقة $id',
    teacherId: 't1',
    supervisorId: 'sup1',
    studentIds: studentIds,
    schedule: [HalaqaScheduleEntity(day: day, startTime: start, endTime: end)],
    meetingLink: '',
    status: 'active',
  );
}

class _FakeTeacherRepo implements TeacherRepository {
  final List<AttendanceRecordEntity> attendance;
  final List<RecitationRecordEntity> recitations;
  final DateTime? latestDue;

  _FakeTeacherRepo({
    this.attendance = const [],
    this.recitations = const [],
    this.latestDue,
  });

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async => Right(attendance);

  @override
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  ) async => Right(latestDue);

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId) async => Right(recitations);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAwardsRepo implements AwardsRepository {
  final List<GrantedAwardEntity> awards;

  _FakeAwardsRepo(this.awards);

  @override
  Future<Either<Failure, List<GrantedAwardEntity>>> getGrantedAwards(
    String halaqaId,
  ) async => Right(awards);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('orders recent activities newest-first and caps to 5', () async {
    final halaqa = _halaqa(id: 'h1');
    final olderEval = RecitationRecordEntity(
      id: 'r1',
      studentId: 's1',
      studentName: 'أحمد',
      teacherId: 't1',
      halaqaId: 'h1',
      date: DateTime(2024, 6, 1, 8),
      type: RecitationType.memorization,
      versesRange: '1-5',
      grade: RecitationGrade.excellent,
      reviewStatus: 'reviewed',
    );
    final newerEval = RecitationRecordEntity(
      id: 'r2',
      studentId: 's1',
      studentName: 'سارة',
      teacherId: 't1',
      halaqaId: 'h1',
      date: DateTime(2024, 6, 3, 10),
      type: RecitationType.memorization,
      versesRange: '6-10',
      grade: RecitationGrade.veryGood,
      reviewStatus: 'reviewed',
    );
    final award = GrantedAwardEntity(
      id: 'a1',
      studentId: 's1',
      studentName: 'سارة علي',
      type: AwardType.studentOfWeek,
      grantedBy: 't1',
      halaqaId: 'h1',
      grantedAt: DateTime(2024, 6, 3, 11),
    );

    final useCase = GetTeacherHomeFeedUseCase(
      teacherRepository: _FakeTeacherRepo(
        attendance: [
          AttendanceRecordEntity(
            id: 'att1',
            studentId: 's1',
            studentName: 'أحمد',
            halaqaId: 'h1',
            date: DateTime(2024, 6, 3, 9, 5),
            status: AttendanceStatus.present,
            recordedBy: 't1',
          ),
        ],
        recitations: [olderEval, newerEval],
        latestDue: DateTime(2024, 6, 3, 23, 59),
      ),
      awardsRepository: _FakeAwardsRepo([award]),
    );

    final result = await useCase(
      TodayAgendaParams(halaqat: [halaqa], now: _monday),
    );

    final feed = result.getOrElse((_) => throw TestFailure('expected Right'));
    expect(feed.recentActivities, isNotEmpty);
    expect(feed.recentActivities.first.kind, TeacherRecentActivityKind.award);
    expect(
      feed.recentActivities.map((a) => a.occurredAt).toList(),
      equals(
        [...feed.recentActivities.map((a) => a.occurredAt)]
          ..sort((a, b) => b.compareTo(a)),
      ),
    );
    expect(feed.recentActivities.length, lessThanOrEqualTo(5));
    expect(feed.agenda.featuredSession, isNotNull);
    expect(feed.agenda.featuredSession!.halaqaId, 'h1');
  });
}
