import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/domain/parent_wallet.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/submit_absence_request_usecase.dart';
import 'package:rafiq_academy/shared/utils/absence_request_ids.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

class _FakeParentRepository implements ParentRepository {
  final List<String> children;
  AbsenceRequestEntity? lastSubmitted;
  int submitCount = 0;
  Failure? submitFailure;
  Failure? childrenFailure;

  _FakeParentRepository({this.children = const ['s1']});

  @override
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId) async {
    if (childrenFailure != null) return Left(childrenFailure!);
    return Right(children);
  }

  @override
  Future<Either<Failure, Unit>> submitAbsenceRequest(
    AbsenceRequestEntity request,
  ) async {
    submitCount++;
    if (submitFailure != null) return Left(submitFailure!);
    lastSubmitted = request;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForParent(String parentId) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<ParentHalaqaOption>>> getHalaqatForStudent(
    String studentId,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, WeeklyReportEntity>> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<PaymentEntity>>> getPayments(String parentId) =>
      throw UnimplementedError();
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
  Future<Either<Failure, Unit>> submitPaymentProof({
    required String parentId,
    required String paymentId,
    required String localFilePath,
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

void main() {
  group('SubmitAbsenceRequestUseCase (W7 Pre-Slice)', () {
    test('normalizes day, assigns deterministic id, forces pending', () async {
      final repo = _FakeParentRepository();
      final useCase = SubmitAbsenceRequestUseCase(repo);

      final result = await useCase(
        AbsenceRequestEntity(
          id: '',
          studentId: 's1',
          halaqaId: 'h1',
          requestedBy: 'p1',
          date: DateTime(2024, 6, 3, 18, 0),
          reason: ' ظرف عائلي ',
          status: AbsenceRequestStatus.approved, // ignored — submit is pending
        ),
      );

      expect(result.isRight(), isTrue);
      final saved = repo.lastSubmitted!;
      expect(saved.date, AttendancePolicy.dayStart(DateTime(2024, 6, 3)));
      expect(
        saved.id,
        AbsenceRequestIds.documentId(
          halaqaId: 'h1',
          studentId: 's1',
          date: DateTime(2024, 6, 3),
        ),
      );
      expect(saved.status, AbsenceRequestStatus.pending);
      expect(saved.reason, 'ظرف عائلي');
      expect(saved.halaqaId, 'h1');
    });

    test('rejects student not linked to parent', () async {
      final repo = _FakeParentRepository(children: const ['other']);
      final useCase = SubmitAbsenceRequestUseCase(repo);

      final result = await useCase(
        AbsenceRequestEntity(
          id: '',
          studentId: 's1',
          halaqaId: 'h1',
          requestedBy: 'p1',
          date: DateTime(2024, 6, 3),
          reason: 'سبب',
          status: AbsenceRequestStatus.pending,
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(repo.submitCount, 0);
    });

    test('requires halaqaId (D-W7-4)', () async {
      final repo = _FakeParentRepository();
      final useCase = SubmitAbsenceRequestUseCase(repo);

      final result = await useCase(
        AbsenceRequestEntity(
          id: '',
          studentId: 's1',
          halaqaId: '  ',
          requestedBy: 'p1',
          date: DateTime(2024, 6, 3),
          reason: 'سبب',
          status: AbsenceRequestStatus.pending,
        ),
      );

      expect(result, const Left(ValidationFailure('معرّف الحلقة مطلوب')));
      expect(repo.submitCount, 0);
    });

    test(
      'D-W7-2: never consults attendance (submit is context-only)',
      () async {
        // ParentRepository has no attendance methods — successful submit proves
        // the use case does not gate on an existing absent mark.
        final repo = _FakeParentRepository();
        final useCase = SubmitAbsenceRequestUseCase(repo);

        final result = await useCase(
          AbsenceRequestEntity(
            id: '',
            studentId: 's1',
            halaqaId: 'h1',
            requestedBy: 'p1',
            date: DateTime(2024, 6, 3),
            reason: 'قبل التسجيل',
            status: AbsenceRequestStatus.pending,
          ),
        );

        expect(result.isRight(), isTrue);
        expect(repo.submitCount, 1);
      },
    );

    test('repeated submit keeps same deterministic id (D-W7-5)', () async {
      final repo = _FakeParentRepository();
      final useCase = SubmitAbsenceRequestUseCase(repo);
      final input = AbsenceRequestEntity(
        id: '',
        studentId: 's1',
        halaqaId: 'h1',
        requestedBy: 'p1',
        date: DateTime(2024, 6, 3, 9),
        reason: 'مرة أولى',
        status: AbsenceRequestStatus.pending,
      );

      await useCase(input);
      final firstId = repo.lastSubmitted!.id;
      await useCase(input.copyWithReason('مرة ثانية'));
      expect(repo.submitCount, 2);
      expect(repo.lastSubmitted!.id, firstId);
      expect(
        firstId,
        AbsenceRequestIds.documentId(
          halaqaId: 'h1',
          studentId: 's1',
          date: DateTime(2024, 6, 3),
        ),
      );
    });
  });
}

extension on AbsenceRequestEntity {
  AbsenceRequestEntity copyWithReason(String reason) => AbsenceRequestEntity(
    id: id,
    studentId: studentId,
    halaqaId: halaqaId,
    requestedBy: requestedBy,
    date: date,
    reason: reason,
    status: status,
    reviewedBy: reviewedBy,
  );
}
