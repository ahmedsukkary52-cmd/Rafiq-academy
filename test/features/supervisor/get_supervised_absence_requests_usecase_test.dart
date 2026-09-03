import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/achievement_issue_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/payment_review_params.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/supervisor_report_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_absence_requests_usecase.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

HalaqaEntity _halaqa(String id) => HalaqaEntity(
  id: id,
  name: id,
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: const ['s1'],
  schedule: const [],
  meetingLink: '',
  status: 'active',
);

class _FakeSupervisorRepository implements SupervisorRepository {
  final List<HalaqaEntity> halaqat;
  final List<AbsenceRequestEntity> requests;
  int readCalls = 0;
  List<String>? lastHalaqaIds;
  DateTime? lastDate;

  _FakeSupervisorRepository({
    this.halaqat = const [],
    this.requests = const [],
  });

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getSupervisedHalaqat(
    String supervisorId,
  ) async => Right(halaqat);

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForHalaqatOnDate({
    required List<String> halaqaIds,
    required DateTime date,
  }) async {
    readCalls++;
    lastHalaqaIds = halaqaIds;
    lastDate = date;
    return Right(
      requests.where((r) => halaqaIds.contains(r.halaqaId)).toList(),
    );
  }

  @override
  Future<Either<Failure, Unit>> issueAchievement(AchievementIssueEntity d) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> submitReport(SupervisorReportEntity r) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> admitStudentToHalaqa({
    required String supervisorId,
    required String halaqaId,
    required String studentId,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> transferStudentBetweenHalaqat({
    required String supervisorId,
    required String studentId,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, Map<String, String>>> getUserDisplayNames(
    List<String> userIds,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<PaymentEntity>>> getPaymentsForStudents({
    required String supervisorId,
    required List<String> studentIds,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reviewPaymentProof(
    PaymentReviewParams params,
  ) => throw UnimplementedError();
}

void main() {
  group('GetSupervisedAbsenceRequestsUseCase (W7 Slice 3 / Rule 2)', () {
    test('projects requests for supervised halaqat only', () async {
      final day = DateTime(2024, 6, 3, 14);
      final repo = _FakeSupervisorRepository(
        halaqat: [_halaqa('h1'), _halaqa('h2')],
        requests: [
          AbsenceRequestEntity(
            id: '1',
            studentId: 's1',
            halaqaId: 'h1',
            requestedBy: 'p1',
            date: DateTime(2024, 6, 3),
            reason: 'سفر',
            status: AbsenceRequestStatus.approved,
            reviewedBy: 't1',
          ),
        ],
      );
      final useCase = GetSupervisedAbsenceRequestsUseCase(repo);

      final result = await useCase(
        SupervisedAbsenceRequestsParams(supervisorId: 'sup1', date: day),
      );

      expect(result.isRight(), isTrue);
      expect(repo.readCalls, 1);
      expect(repo.lastHalaqaIds, ['h1', 'h2']);
      expect(repo.lastDate, AttendancePolicy.dayStart(day));
      expect(
        result.getOrElse((_) => const []).single.status,
        AbsenceRequestStatus.approved,
      );
    });

    test('empty supervised set → empty projection (no read fan-out)', () async {
      final repo = _FakeSupervisorRepository();
      final useCase = GetSupervisedAbsenceRequestsUseCase(repo);

      final result = await useCase(
        SupervisedAbsenceRequestsParams(
          supervisorId: 'sup1',
          date: DateTime(2024, 6, 3),
        ),
      );

      expect(result, const Right(<AbsenceRequestEntity>[]));
      expect(repo.readCalls, 0);
    });
  });
}
