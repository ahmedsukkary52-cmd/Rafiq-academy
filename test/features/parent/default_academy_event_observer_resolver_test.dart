import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/data/observers/default_academy_event_observer_resolver.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/domain/parent_wallet.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';

void main() {
  final date = DateTime(2024, 6, 3);

  StudentAbsentRecorded absent(String studentId) => StudentAbsentRecorded(
    studentId: studentId,
    studentName: 'أحمد',
    halaqaId: 'h1',
    date: date,
    attendanceDocumentId: 'h1_${studentId}_20240603',
  );

  HomeworkAssigned assigned(String studentId) => HomeworkAssigned(
    assignmentId: 'a_$studentId',
    studentId: studentId,
    halaqaId: 'h1',
    assignedBy: 't1',
    dueDate: date,
    newMemorizationRange: '1-5',
    reviewRange: '',
  );

  late _FakeParentRepository parents;
  late DefaultAcademyEventObserverResolver resolver;

  setUp(() {
    parents = _FakeParentRepository();
    resolver = DefaultAcademyEventObserverResolver(parentRepository: parents);
  });

  group('DefaultAcademyEventObserverResolver', () {
    test('absence resolves linked parents only', () async {
      parents.result = const {
        's1': ['p1', 'p2'],
      };

      final event = absent('s1');
      final result = await resolver.resolve([event]);

      expect(result[event.eventId], ['p1', 'p2']);
      expect(result[event.eventId], isNot(contains('s1')));
    });

    test('homework assigned includes subject student and parents', () async {
      parents.result = const {
        's1': ['p1'],
      };

      final event = assigned('s1');
      final result = await resolver.resolve([event]);

      expect(result[event.eventId], ['s1', 'p1']);
    });

    test('lookup failure propagates', () async {
      parents.failure = const ServerFailure('down');

      expect(
        () => resolver.resolve([absent('s1')]),
        throwsA(isA<ServerException>()),
      );
    });
  });
}

class _FakeParentRepository implements ParentRepository {
  Map<String, List<String>> result = const {};
  Failure? failure;

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) async {
    if (failure != null) return Left(failure!);
    return Right(result);
  }

  @override
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, WeeklyReportEntity>> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<PaymentEntity>>> getPayments(String parentId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> submitAbsenceRequest(
    AbsenceRequestEntity request,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForParent(String parentId) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<ParentHalaqaOption>>> getHalaqatForStudent(
    String studentId,
  ) => throw UnimplementedError();
  @override
  Stream<Either<Failure, List<String>>> watchChildrenAssignments(
    String parentId,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, PaymentInitiationEntity>> initiatePayment(
    String paymentId,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, ParentWalletEntity>> getWallet(String parentId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> payPaymentFromWallet({
    required String parentId,
    required String paymentId,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, ParentHousehold>> getHousehold({
    required String parentId,
    required List<String> childrenIds,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<ParentAttendanceMark>>> getAttendanceMarks({
    required String studentId,
    required DateTime start,
    required DateTime endExclusive,
  }) => throw UnimplementedError();
}
