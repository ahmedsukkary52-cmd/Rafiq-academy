import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/domain/parent_wallet.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/pay_payment_from_wallet_usecase.dart';

class _FakeParentRepository implements ParentRepository {
  String? paidParentId;
  String? paidPaymentId;
  Either<Failure, Unit> payResult = const Right(unit);

  @override
  Future<Either<Failure, Unit>> payPaymentFromWallet({
    required String parentId,
    required String paymentId,
  }) async {
    paidParentId = parentId;
    paidPaymentId = paymentId;
    return payResult;
  }

  @override
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId) =>
      throw UnimplementedError();
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
  group('PayPaymentFromWalletUseCase', () {
    test('rejects empty ids before repository', () async {
      final repo = _FakeParentRepository();
      final useCase = PayPaymentFromWalletUseCase(repo);

      final emptyParent = await useCase(
        const PayPaymentFromWalletParams(parentId: ' ', paymentId: 'pay1'),
      );
      final emptyPayment = await useCase(
        const PayPaymentFromWalletParams(parentId: 'p1', paymentId: ''),
      );

      expect(emptyParent.isLeft(), isTrue);
      expect(emptyPayment.isLeft(), isTrue);
      expect(repo.paidPaymentId, isNull);
    });

    test('debits through repository when ids are valid', () async {
      final repo = _FakeParentRepository();
      final useCase = PayPaymentFromWalletUseCase(repo);

      final result = await useCase(
        const PayPaymentFromWalletParams(parentId: 'p1', paymentId: 'pay1'),
      );

      expect(result.isRight(), isTrue);
      expect(repo.paidParentId, 'p1');
      expect(repo.paidPaymentId, 'pay1');
    });

    test('forwards insufficient-balance failure', () async {
      final repo = _FakeParentRepository()
        ..payResult = const Left(ValidationFailure('رصيد المحفظة غير كافٍ'));
      final useCase = PayPaymentFromWalletUseCase(repo);

      final result = await useCase(
        const PayPaymentFromWalletParams(parentId: 'p1', paymentId: 'pay1'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f.message, contains('رصيد')),
        (_) => fail('expected failure'),
      );
    });
  });
}
