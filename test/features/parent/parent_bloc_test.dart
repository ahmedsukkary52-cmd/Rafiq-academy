import 'dart:async';

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
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_state.dart';
import 'package:rafiq_academy/shared/domain/academy_billing_entities.dart';
import 'package:rafiq_academy/shared/domain/payment_access_entity.dart';

typedef _E<T> = Either<Failure, T>;

class _Script<P, R> {
  _Script(this.respond);

  R Function(P params) respond;
  final params = <P>[];
  final gates = <int, Completer<void>>{};

  Future<R> run(P p) async {
    final index = params.length;
    params.add(p);
    await gates[index]?.future;
    return respond(p);
  }
}

WeeklyReportEntity _report(String studentId) => WeeklyReportEntity(
  studentId: studentId,
  studentName: studentId,
  weekStart: DateTime(2026, 9, 5),
  totalVersesMemorized: 0,
  attendedSessions: 0,
  totalSessions: 0,
  teacherNotes: '',
);

final _invoice = PaymentEntity(
  id: 'inv_c1_2026-09',
  studentId: 'c1',
  parentId: 'p1',
  amount: 300,
  dueDate: DateTime(2026, 9, 10),
  status: PaymentStatus.due,
);

final _absence = AbsenceRequestEntity(
  id: '',
  studentId: 'c1',
  halaqaId: 'h1',
  requestedBy: 'p1',
  date: DateTime(2026, 9, 12),
  reason: 'سفر',
  status: AbsenceRequestStatus.pending,
);

class _Children extends Fake implements GetChildrenIdsUseCase {
  final s = _Script<ParentIdParams, _E<List<String>>>(
    (_) => const Right(['c1', 'c2']),
  );
  @override
  Future<_E<List<String>>> call(ParentIdParams p) => s.run(p);
}

class _Household extends Fake implements GetParentHouseholdUseCase {
  final s = _Script<ParentHouseholdParams, _E<ParentHousehold>>(
    (_) => const Right(ParentHousehold()),
  );
  @override
  Future<_E<ParentHousehold>> call(ParentHouseholdParams p) => s.run(p);
}

class _Payments extends Fake implements GetPaymentsUseCase {
  late final s = _Script<ParentIdParams, _E<List<PaymentEntity>>>(
    (_) => Right([_invoice]),
  );
  @override
  Future<_E<List<PaymentEntity>>> call(ParentIdParams p) => s.run(p);
}

class _PublicSettings extends Fake implements GetPaymentPublicSettingsUseCase {
  final s = _Script<NoParams, _E<PaymentPublicSettingsEntity>>(
    (_) => const Right(
      PaymentPublicSettingsEntity(vodafoneCashDestination: '01000000000'),
    ),
  );
  @override
  Future<_E<PaymentPublicSettingsEntity>> call(NoParams p) => s.run(p);
}

class _Access extends Fake implements GetPaymentAccessUseCase {
  final s = _Script<ParentIdParams, _E<PaymentAccessEntity?>>(
    (_) => const Right(PaymentAccessEntity(parentId: 'p1', status: 'ok')),
  );
  @override
  Future<_E<PaymentAccessEntity?>> call(ParentIdParams p) => s.run(p);
}

class _Report extends Fake implements GetWeeklyReportUseCase {
  final s = _Script<WeeklyReportParams, _E<WeeklyReportEntity>>(
    (p) => Right(_report(p.studentId)),
  );
  @override
  Future<_E<WeeklyReportEntity>> call(WeeklyReportParams p) => s.run(p);
}

class _AbsenceList extends Fake implements GetAbsenceRequestsUseCase {
  final s = _Script<ParentIdParams, _E<List<AbsenceRequestEntity>>>(
    (_) => const Right([]),
  );
  @override
  Future<_E<List<AbsenceRequestEntity>>> call(ParentIdParams p) => s.run(p);
}

class _StudentHalaqat extends Fake implements GetHalaqatForStudentUseCase {
  final s = _Script<StudentHalaqatParams, _E<List<ParentHalaqaOption>>>(
    (_) => const Right([]),
  );
  @override
  Future<_E<List<ParentHalaqaOption>>> call(StudentHalaqatParams p) => s.run(p);
}

class _SubmitAbsence extends Fake implements SubmitAbsenceRequestUseCase {
  final s = _Script<AbsenceRequestEntity, _E<Unit>>((_) => const Right(unit));
  @override
  Future<_E<Unit>> call(AbsenceRequestEntity p) => s.run(p);
}

class _SubmitProof extends Fake implements SubmitPaymentProofUseCase {
  final s = _Script<SubmitPaymentProofParams, _E<Unit>>(
    (_) => const Right(unit),
  );
  @override
  Future<_E<Unit>> call(SubmitPaymentProofParams p) => s.run(p);
}

class _Harness {
  final children = _Children();
  final household = _Household();
  final payments = _Payments();
  final publicSettings = _PublicSettings();
  final access = _Access();
  final report = _Report();
  final absenceList = _AbsenceList();
  final studentHalaqat = _StudentHalaqat();
  final submitAbsence = _SubmitAbsence();
  final submitProof = _SubmitProof();

  late final bloc = ParentBloc(
    getChildrenIds: children,
    getWeeklyReport: report,
    getPayments: payments,
    getPaymentPublicSettings: publicSettings,
    getPaymentAccess: access,
    getAbsenceRequests: absenceList,
    getHalaqatForStudent: studentHalaqat,
    submitAbsenceRequest: submitAbsence,
    getHousehold: household,
    submitPaymentProof: submitProof,
  );
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Harness h;

  setUp(() => h = _Harness());
  tearDown(() => h.bloc.close());

  test('initial state is idle', () {
    expect(h.bloc.state, ParentState.initial());
  });

  group('children + household', () {
    test('selects the first child and loads its weekly report', () async {
      h.bloc.add(const LoadChildrenEvent('p1'));
      await _settle();

      expect(h.bloc.state.childrenIds, ['c1', 'c2']);
      expect(h.bloc.state.selectedChildId, 'c1');
      expect(h.bloc.state.childrenStatus, SectionStatus.loaded);
      expect(h.household.s.params.single.childrenIds, ['c1', 'c2']);
      expect(h.bloc.state.paymentsStatus, SectionStatus.loaded);
      expect(h.bloc.state.payments, [_invoice]);
      expect(h.report.s.params.single.studentId, 'c1');
      expect(h.bloc.state.reportStatus, SectionStatus.loaded);
    });

    test('parent with no linked children loads empty, no report', () async {
      h.children.s.respond = (_) => const Right([]);
      h.bloc.add(const LoadChildrenEvent('p1'));
      await _settle();

      expect(h.bloc.state.childrenStatus, SectionStatus.loaded);
      expect(h.bloc.state.selectedChildId, isNull);
      expect(h.report.s.params, isEmpty);
    });

    test('children failure stops before household and payments', () async {
      h.children.s.respond = (_) => const Left(NetworkFailure());
      h.bloc.add(const LoadChildrenEvent('p1'));
      await _settle();

      expect(h.bloc.state.childrenStatus, SectionStatus.error);
      expect(h.bloc.state.childrenError, const NetworkFailure().message);
      expect(h.household.s.params, isEmpty);
      expect(h.payments.s.params, isEmpty);
    });

    test('payments failure is isolated from the household', () async {
      h.payments.s.respond = (_) => const Left(ServerFailure('تعذر الفواتير'));
      h.bloc.add(const LoadChildrenEvent('p1'));
      await _settle();

      expect(h.bloc.state.childrenStatus, SectionStatus.loaded);
      expect(h.bloc.state.paymentsStatus, SectionStatus.error);
      expect(h.bloc.state.paymentsError, 'تعذر الفواتير');
    });
  });

  group('weekly report', () {
    test('switching child drops the previous child\'s late report', () async {
      h.bloc.add(const LoadChildrenEvent('p1'));
      await _settle();

      h.report.s.gates[1] = Completer<void>();
      h.bloc.add(const SelectChildEvent('c2'));
      await _settle();
      h.bloc.add(const SelectChildEvent('c1'));
      await _settle();
      h.report.s.gates[1]!.complete();
      await _settle();

      expect(h.bloc.state.selectedChildId, 'c1');
      expect(h.bloc.state.weeklyReport!.studentId, 'c1');
    });

    test('report failure, then retry via re-select', () async {
      h.bloc.add(const LoadChildrenEvent('p1'));
      await _settle();
      h.report.s.respond = (_) => const Left(ServerFailure('لا يوجد تقرير'));
      h.bloc.add(const SelectChildEvent('c2'));
      await _settle();
      expect(h.bloc.state.reportStatus, SectionStatus.error);
      expect(h.bloc.state.weeklyReport, isNull);

      h.report.s.respond = (p) => Right(_report(p.studentId));
      h.bloc.add(const SelectChildEvent('c2'));
      await _settle();
      expect(h.bloc.state.reportStatus, SectionStatus.loaded);
      expect(h.bloc.state.reportError, isNull);
    });
  });

  group('payments tab', () {
    test('loads destination and payment access with the invoices', () async {
      h.bloc.add(const LoadPaymentsEvent('p1'));
      await _settle();

      expect(h.bloc.state.paymentsStatus, SectionStatus.loaded);
      expect(h.bloc.state.vodafoneCashDestination, '01000000000');
      expect(h.bloc.state.paymentAccess!.status, 'ok');
    });

    test('missing settings degrade to an empty destination', () async {
      h.publicSettings.s.respond = (_) => const Left(ServerFailure('x'));
      h.access.s.respond = (_) => const Left(ServerFailure('x'));
      h.bloc.add(const LoadPaymentsEvent('p1'));
      await _settle();

      expect(h.bloc.state.paymentsStatus, SectionStatus.loaded);
      expect(h.bloc.state.vodafoneCashDestination, '');
      expect(h.bloc.state.paymentAccess, isNull);
    });

    test('proof upload success reloads payments', () async {
      h.bloc.add(
        const SubmitPaymentProofEvent(
          parentId: 'p1',
          paymentId: 'inv_c1_2026-09',
          localFilePath: '/tmp/proof.jpg',
        ),
      );
      await _settle();

      expect(h.submitProof.s.params.single.paymentId, 'inv_c1_2026-09');
      expect(h.bloc.state.paymentProofStatus, SubmissionStatus.success);
      expect(h.payments.s.params, hasLength(1));
    });

    test('proof upload failure keeps the payment id for retry', () async {
      h.submitProof.s.respond = (_) => const Left(ServerFailure('الملف كبير'));
      h.bloc.add(
        const SubmitPaymentProofEvent(
          parentId: 'p1',
          paymentId: 'inv_c1_2026-09',
          localFilePath: '/tmp/proof.jpg',
        ),
      );
      await _settle();

      expect(h.bloc.state.paymentProofStatus, SubmissionStatus.error);
      expect(h.bloc.state.paymentProofError, 'الملف كبير');
      expect(h.bloc.state.paymentProofPaymentId, 'inv_c1_2026-09');
      expect(h.payments.s.params, isEmpty);

      h.bloc.add(const ResetPaymentProofEvent());
      await _settle();
      expect(h.bloc.state.paymentProofStatus, SubmissionStatus.idle);
      expect(h.bloc.state.paymentProofPaymentId, isNull);
    });
  });

  group('absence requests', () {
    test('submit success reloads the list for the requester', () async {
      h.bloc.add(SubmitAbsenceRequestEvent(_absence));
      await _settle();

      expect(h.bloc.state.absenceSubmissionStatus, SubmissionStatus.success);
      expect(h.absenceList.s.params.single.parentId, 'p1');
      expect(h.bloc.state.absenceRequestsStatus, SectionStatus.loaded);
    });

    test('submit failure is surfaced and does not reload', () async {
      h.submitAbsence.s.respond = (_) => const Left(ValidationFailure('مكرر'));
      h.bloc.add(SubmitAbsenceRequestEvent(_absence));
      await _settle();

      expect(h.bloc.state.absenceSubmissionStatus, SubmissionStatus.error);
      expect(h.bloc.state.absenceSubmissionError, 'مكرر');
      expect(h.absenceList.s.params, isEmpty);
    });

    test('halaqat for a stale child are dropped', () async {
      h.studentHalaqat.s.gates[0] = Completer<void>();
      h.studentHalaqat.s.respond = (p) => p.studentId == 'c1'
          ? const Right([ParentHalaqaOption(id: 'h1', name: 'أ')])
          : const Right([]);

      h.bloc.add(const LoadStudentHalaqatEvent(parentId: 'p1', studentId: 'c1'));
      await _settle();
      h.bloc.add(const LoadStudentHalaqatEvent(parentId: 'p1', studentId: 'c2'));
      await _settle();
      h.studentHalaqat.s.gates[0]!.complete();
      await _settle();

      expect(h.bloc.state.studentHalaqatStudentId, 'c2');
      expect(h.bloc.state.studentHalaqat, isEmpty);
    });
  });

  test('logout clears all parent state', () async {
    h.bloc.add(const LoadChildrenEvent('p1'));
    await _settle();
    h.bloc.add(const ClearParentSessionEvent());
    await _settle();

    expect(h.bloc.state, ParentState.initial());
  });
}
