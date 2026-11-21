import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/core/usecases/usecases.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_absence_requests_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_children_ids_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_halaqat_for_student_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_parent_household_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_payment_access_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_payment_public_settings_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_payments_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_weekly_report_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/submit_absence_request_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/submit_payment_proof_usecase.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_bloc.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_event.dart';
import 'package:rafiq_academy/shared/domain/academy_billing_entities.dart';
import 'package:rafiq_academy/shared/domain/payment_access_entity.dart';
import 'package:rafiq_academy/shared/domain/payment_entity.dart';

import '../../helpers/payment_destination_placeholders.dart';

typedef _E<T> = Either<Failure, T>;

PaymentEntity _pay(String id) => PaymentEntity(
  id: id,
  studentId: 's1',
  parentId: 'p1',
  amount: 100,
  status: PaymentStatus.due,
  dueDate: DateTime(2026, 11, 1),
);

class _Payments extends Fake implements GetPaymentsUseCase {
  final calls = <ParentPaymentsPageParams>[];
  final pages = <String?, ParentPaymentsPage>{};
  bool failNext = false;

  @override
  Future<_E<List<PaymentEntity>>> call(ParentIdParams p) async =>
      const Right([]);

  @override
  Future<_E<ParentPaymentsPage>> page(ParentPaymentsPageParams p) async {
    calls.add(p);
    if (failNext) {
      failNext = false;
      return Left(ServerFailure('network'));
    }
    return Right(
      pages[p.afterPaymentId] ??
          const ParentPaymentsPage(
            items: [],
            nextCursorId: null,
            hasMore: false,
          ),
    );
  }
}

class _Public extends Fake implements GetPaymentPublicSettingsUseCase {
  @override
  Future<_E<PaymentPublicSettingsEntity>> call(NoParams p) async =>
      const Right(
        PaymentPublicSettingsEntity(
          vodafoneCashDestination: kDevPlaceholderVodafoneCash,
          instapayDestination: kDevPlaceholderInstapayAddress,
        ),
      );
}

class _Access extends Fake implements GetPaymentAccessUseCase {
  @override
  Future<_E<PaymentAccessEntity?>> call(ParentIdParams p) async =>
      const Right(PaymentAccessEntity(parentId: 'p1', status: 'ok'));
}

class _UnusedChildren extends Fake implements GetChildrenIdsUseCase {
  @override
  Future<_E<List<String>>> call(ParentIdParams p) async => const Right([]);
}

class _UnusedReport extends Fake implements GetWeeklyReportUseCase {
  @override
  Future<_E<WeeklyReportEntity>> call(WeeklyReportParams p) async =>
      Left(ServerFailure('unused'));
}

class _UnusedAbsence extends Fake implements GetAbsenceRequestsUseCase {
  @override
  Future<_E<List<AbsenceRequestEntity>>> call(ParentIdParams p) async =>
      const Right([]);
}

class _UnusedHalaqat extends Fake implements GetHalaqatForStudentUseCase {
  @override
  Future<_E<List<ParentHalaqaOption>>> call(StudentHalaqatParams p) async =>
      const Right([]);
}

class _UnusedSubmitAbsence extends Fake implements SubmitAbsenceRequestUseCase {
  @override
  Future<_E<Unit>> call(AbsenceRequestEntity p) async => const Right(unit);
}

class _UnusedHousehold extends Fake implements GetParentHouseholdUseCase {
  @override
  Future<_E<ParentHousehold>> call(ParentHouseholdParams p) async =>
      const Right(ParentHousehold());
}

class _UnusedProof extends Fake implements SubmitPaymentProofUseCase {
  @override
  Future<_E<Unit>> call(SubmitPaymentProofParams p) async => const Right(unit);
}

ParentBloc _bloc(_Payments payments) => ParentBloc(
  getChildrenIds: _UnusedChildren(),
  getWeeklyReport: _UnusedReport(),
  getPayments: payments,
  getPaymentPublicSettings: _Public(),
  getPaymentAccess: _Access(),
  getAbsenceRequests: _UnusedAbsence(),
  getHalaqatForStudent: _UnusedHalaqat(),
  submitAbsenceRequest: _UnusedSubmitAbsence(),
  getHousehold: _UnusedHousehold(),
  submitPaymentProof: _UnusedProof(),
);

void main() {
  late _Payments payments;
  late ParentBloc bloc;

  setUp(() {
    payments = _Payments();
    bloc = _bloc(payments);
  });

  tearDown(() => bloc.close());

  test('initial load uses cursor page and LoadMore appends without dupes', () async {
    payments.pages[null] = ParentPaymentsPage(
      items: [_pay('pay2'), _pay('pay1')],
      nextCursorId: 'pay1',
      hasMore: true,
    );
    payments.pages['pay1'] = ParentPaymentsPage(
      items: [_pay('pay0'), _pay('pay1')],
      nextCursorId: null,
      hasMore: false,
    );

    bloc.add(const LoadPaymentsEvent('p1'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.paymentsStatus, SectionStatus.loaded);
    expect(bloc.state.payments.map((p) => p.id), ['pay2', 'pay1']);
    expect(bloc.state.paymentsHasMore, isTrue);
    expect(bloc.state.paymentsCursorId, 'pay1');
    expect(payments.calls.single.afterPaymentId, isNull);

    bloc.add(const LoadMorePaymentsEvent());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(payments.calls.last.afterPaymentId, 'pay1');
    expect(bloc.state.payments.map((p) => p.id), ['pay2', 'pay1', 'pay0']);
    expect(bloc.state.paymentsHasMore, isFalse);
  });

  test('LoadMore is a no-op when exhausted', () async {
    payments.pages[null] = ParentPaymentsPage(
      items: [_pay('only')],
      nextCursorId: null,
      hasMore: false,
    );
    bloc.add(const LoadPaymentsEvent('p1'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bloc.add(const LoadMorePaymentsEvent());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(payments.calls.length, 1);
  });

  test('LoadMore error keeps loaded invoices and sets retry message', () async {
    payments.pages[null] = ParentPaymentsPage(
      items: [_pay('pay2')],
      nextCursorId: 'pay2',
      hasMore: true,
    );
    bloc.add(const LoadPaymentsEvent('p1'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    payments.failNext = true;
    bloc.add(const LoadMorePaymentsEvent());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.payments.map((p) => p.id), ['pay2']);
    expect(bloc.state.paymentsError, isNotNull);
    expect(bloc.state.paymentsStatus, SectionStatus.loaded);
    expect(bloc.state.paymentsLoadingMore, isFalse);
  });
}
