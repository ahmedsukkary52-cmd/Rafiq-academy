import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/payment_review_params.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/admit_student_to_halaqa_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_absence_requests_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_halaqat_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervisor_day_board_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/issue_achievement_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/payment_review_usecases.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/register_new_student_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/submit_supervisor_report_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/transfer_student_between_halaqat_usecase.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_event.dart';
import 'package:rafiq_academy/shared/domain/payment_review_amounts.dart';

class _Payments extends Fake implements GetSupervisedPaymentsUseCase {
  final loads = <SupervisedPaymentsParams>[];
  List<PaymentEntity> result = const [];

  @override
  Future<Either<Failure, List<PaymentEntity>>> call(
    SupervisedPaymentsParams p,
  ) async {
    loads.add(p);
    return Right(result);
  }
}

/// Real use case (local validation) over a recording repository.
class _Repo extends Fake implements SupervisorRepository {
  final calls = <PaymentReviewParams>[];
  Failure? failure;
  Object? throws;
  bool replayed = false;
  Completer<void>? gate;

  @override
  Future<Either<Failure, PaymentReviewResult>> reviewPaymentProof(
    PaymentReviewParams params,
  ) async {
    calls.add(params);
    await gate?.future;
    if (throws != null) throw throws!;
    return failure == null
        ? Right(
            PaymentReviewResult(
              paymentId: params.paymentId,
              replayed: replayed,
            ),
          )
        : Left(failure!);
  }
}

class _ErrorRecorder extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

class _Unused1 extends Fake implements GetSupervisedHalaqatUseCase {}

class _Unused2 extends Fake implements GetSupervisorDayBoardUseCase {}

class _Unused3 extends Fake implements GetSupervisedAbsenceRequestsUseCase {}

class _Unused4 extends Fake implements IssueAchievementUseCase {}

class _Unused5 extends Fake implements SubmitSupervisorReportUseCase {}

class _Unused6 extends Fake implements AdmitStudentToHalaqaUseCase {}

class _Unused7 extends Fake implements TransferStudentBetweenHalaqatUseCase {}

class _Unused8 extends Fake implements RegisterNewStudentUseCase {}

const _snapshot = PaymentAmountSnapshot(invoice: 20000, previous: 6000);

ReviewPaymentProofEvent _review({
  PaymentReviewDecision decision = PaymentReviewDecision.partial,
  int? amount = 5000,
  String proof = '1790000000000.jpg',
  String paymentId = 'p1',
  String supervisorId = 'sup1',
  String? notes,
}) {
  final partial = decision == PaymentReviewDecision.partial;
  return ReviewPaymentProofEvent(
    supervisorId: supervisorId,
    snapshot: _snapshot,
    command: PaymentReviewCommand(
      paymentId: paymentId,
      notes: notes,
      decision: decision.wire,
      amountMode: partial ? PaymentAmountMode.receipt : null,
      amountMinorUnits: partial ? amount : null,
      expectedProofFileName: proof,
    ),
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Repo repo;
  late _Payments payments;
  late SupervisorBloc bloc;

  SupervisorBloc buildBloc() => SupervisorBloc(
    getSupervisedHalaqat: _Unused1(),
    getSupervisorDayBoard: _Unused2(),
    getSupervisedAbsenceRequests: _Unused3(),
    issueAchievement: _Unused4(),
    submitSupervisorReport: _Unused5(),
    admitStudentToHalaqa: _Unused6(),
    transferStudentBetweenHalaqat: _Unused7(),
    getSupervisedPayments: payments,
    reviewPaymentProof: ReviewPaymentProofUseCase(repo),
    registerNewStudent: _Unused8(),
  );

  setUp(() {
    repo = _Repo();
    payments = _Payments();
    bloc = buildBloc();
  });

  tearDown(() => bloc.close());

  test('success sends a valid requestId and reloads payments', () async {
    bloc.add(_review());
    await _settle();
    final sent = repo.calls.single;
    expect(sent.supervisorId, 'sup1');
    expect(sent.command.amountMinorUnits, 5000);
    expect(kPaymentReviewRequestIdPattern.hasMatch(sent.requestId), isTrue);
    expect(bloc.state.reviewPaymentStatus, SubmissionStatus.success);
    expect(payments.loads.single.supervisorId, 'sup1');
  });

  test(
    'a retry after timeout reuses the requestId; a change does not',
    () async {
      repo.failure = const ServerFailure('deadline-exceeded');
      bloc.add(_review());
      await _settle();
      expect(bloc.state.reviewPaymentStatus, SubmissionStatus.error);
      bloc.add(_review());
      await _settle();
      expect(repo.calls[1].requestId, repo.calls[0].requestId);
      expect(payments.loads, isEmpty);

      bloc.add(_review(amount: 5100));
      await _settle();
      expect(repo.calls[2].requestId, isNot(repo.calls[0].requestId));
    },
  );

  test('a new decision after success gets a new requestId', () async {
    bloc.add(_review());
    await _settle();
    bloc.add(_review());
    await _settle();
    expect(repo.calls[1].requestId, isNot(repo.calls[0].requestId));
  });

  test(
    'a changed proof reports the message and reloads without resending',
    () async {
      repo.failure = const ServerFailure(kPaymentProofChangedMessage);
      bloc.add(_review());
      await _settle();
      expect(repo.calls, hasLength(1));
      expect(bloc.state.reviewPaymentError, kPaymentProofChangedMessage);
      expect(payments.loads, hasLength(1));
    },
  );

  test('invalid amounts never reach the repository', () async {
    bloc.add(_review(amount: 14000));
    await _settle();
    expect(repo.calls, isEmpty);
    expect(bloc.state.reviewPaymentStatus, SubmissionStatus.error);
    expect(bloc.state.reviewPaymentError, contains('الاعتماد الكامل'));
  });

  test('concurrent review taps are dropped while one is in flight', () async {
    repo.gate = Completer<void>();
    bloc
      ..add(_review())
      ..add(_review())
      ..add(_review(decision: PaymentReviewDecision.approved));
    await _settle();
    repo.gate!.complete();
    await _settle();
    expect(repo.calls, hasLength(1));
  });

  test('approval and rejection send no amounts', () async {
    bloc.add(_review(decision: PaymentReviewDecision.approved));
    await _settle();
    bloc.add(_review(decision: PaymentReviewDecision.rejected));
    await _settle();
    for (final call in repo.calls) {
      expect(call.command.amountMode, isNull);
      expect(call.command.amountMinorUnits, isNull);
    }
    expect(repo.calls.map((c) => c.command.decision), ['approve', 'reject']);
  });

  test('every review outcome names the payment it belongs to', () async {
    repo.gate = Completer<void>();
    bloc.add(_review(paymentId: 'pA'));
    await _settle();
    expect(bloc.state.reviewPaymentId, 'pA');
    expect(bloc.state.reviewStatusFor('pA'), SubmissionStatus.submitting);
    expect(bloc.state.reviewStatusFor('pB'), SubmissionStatus.idle);
    repo.gate!.complete();
    await _settle();
    expect(bloc.state.reviewStatusFor('pA'), SubmissionStatus.success);
    expect(bloc.state.reviewStatusFor('pB'), SubmissionStatus.idle);
  });

  test('a new review is accepted once the first one finished', () async {
    repo.gate = Completer<void>();
    bloc.add(_review(paymentId: 'pA'));
    await _settle();
    bloc.add(_review(paymentId: 'pB'));
    await _settle();
    expect(repo.calls, hasLength(1));
    repo.gate!.complete();
    await _settle();
    repo.gate = null;
    bloc.add(_review(paymentId: 'pB'));
    await _settle();
    expect(repo.calls.map((c) => c.paymentId), ['pA', 'pB']);
    expect(bloc.state.reviewStatusFor('pB'), SubmissionStatus.success);
  });

  test('clearing the session mid-review drops the old result', () async {
    repo.gate = Completer<void>();
    bloc.add(_review(paymentId: 'pA'));
    await _settle();
    bloc.add(const ClearSupervisorSessionEvent());
    await _settle();
    expect(bloc.state.reviewPaymentStatus, SubmissionStatus.idle);

    repo.gate!.complete();
    await _settle();
    expect(bloc.state.reviewPaymentStatus, SubmissionStatus.idle);
    expect(bloc.state.reviewPaymentId, isNull);
    expect(
      payments.loads,
      isEmpty,
      reason: 'no reload with the old supervisor',
    );
  });

  test('an old session result never touches the new session review', () async {
    final oldGate = Completer<void>();
    repo.gate = oldGate;
    bloc.add(_review(paymentId: 'pA', supervisorId: 'supOld'));
    await _settle();
    bloc.add(const ClearSupervisorSessionEvent());
    await _settle();

    final newGate = Completer<void>();
    repo.gate = newGate;
    bloc.add(_review(paymentId: 'pB', supervisorId: 'supNew'));
    await _settle();
    expect(repo.calls.map((c) => c.supervisorId), ['supOld', 'supNew']);

    oldGate.complete();
    await _settle();
    expect(bloc.state.reviewPaymentId, 'pB');
    expect(bloc.state.reviewPaymentStatus, SubmissionStatus.submitting);
    expect(payments.loads, isEmpty);

    newGate.complete();
    await _settle();
    expect(bloc.state.reviewStatusFor('pB'), SubmissionStatus.success);
    expect(payments.loads.single.supervisorId, 'supNew');
  });

  test(
    'an unexpected exception releases the busy state and is reported',
    () async {
      final recorder = _ErrorRecorder();
      final previous = Bloc.observer;
      Bloc.observer = recorder;
      addTearDown(() => Bloc.observer = previous);
      await bloc.close();
      bloc = buildBloc();

      repo.throws = StateError('boom');
      bloc.add(_review());
      await _settle();
      expect(bloc.state.reviewPaymentStatus, SubmissionStatus.error);
      expect(bloc.state.reviewPaymentError, isNotNull);
      expect(recorder.errors.single, isA<StateError>());
      expect(bloc.state.reviewPaymentUnresolved['p1'], isNotNull);

      // Outcome unknown: the identical retry keeps the requestId.
      repo.throws = null;
      bloc.add(_review());
      await _settle();
      expect(repo.calls[1].requestId, repo.calls[0].requestId);
      expect(bloc.state.reviewPaymentStatus, SubmissionStatus.success);
    },
  );

  test('a reset never releases an in-flight review', () async {
    repo.gate = Completer<void>();
    bloc.add(_review());
    await _settle();
    bloc.add(const ResetReviewPaymentEvent());
    await _settle();
    expect(bloc.state.reviewPaymentStatus, SubmissionStatus.submitting);
    repo.gate!.complete();
    await _settle();
  });

  for (final message in kPaymentNoLongerPendingMessages) {
    test('"$message" reloads, settles and never resends', () async {
      repo.failure = ServerFailure(message);
      bloc.add(_review());
      await _settle();
      expect(repo.calls, hasLength(1));
      expect(bloc.state.reviewPaymentError, kPaymentNoLongerPendingNotice);
      expect(bloc.state.reviewPaymentUnresolved, isEmpty);
      expect(payments.loads, hasLength(1));
    });
  }

  test('a replayed result is reported as an earlier decision', () async {
    repo.replayed = true;
    bloc.add(_review());
    await _settle();
    expect(bloc.state.reviewPaymentStatus, SubmissionStatus.success);
    expect(bloc.state.reviewPaymentMessage, kPaymentReviewReplayedMessage);
    expect(payments.loads, hasLength(1));
  });

  test('an unresolved command is kept until a definitive outcome', () async {
    repo.failure = const NetworkFailure();
    bloc.add(_review(notes: 'دفعة'));
    await _settle();
    final kept = bloc.state.reviewPaymentUnresolved['p1']!;
    expect(kept.notes, 'دفعة');
    expect(kept.amountMinorUnits, 5000);

    bloc.add(_review(notes: 'تعديل'));
    await _settle();
    expect(repo.calls[1].requestId, isNot(repo.calls[0].requestId));
    expect(bloc.state.reviewPaymentUnresolved['p1']!.notes, 'تعديل');

    repo.failure = null;
    bloc.add(_review(notes: 'تعديل'));
    await _settle();
    expect(repo.calls[2].requestId, repo.calls[1].requestId);
    expect(bloc.state.reviewPaymentUnresolved, isEmpty);
  });

  test('locally refused commands are never kept for retry', () async {
    bloc.add(_review(amount: 14000));
    await _settle();
    expect(repo.calls, isEmpty);
    expect(bloc.state.reviewPaymentUnresolved, isEmpty);
  });

  group('proof cycle', () {
    const cycleA = 'pc_AAAAAAAAAAAAAAAAAAAAAAAA';
    const cycleB = 'pc_BBBBBBBBBBBBBBBBBBBBBBBB';

    PaymentEntity pending({String? cycle, String? review = 'pending_review'}) =>
        PaymentEntity(
          id: 'p1',
          studentId: 's1',
          parentId: 'par1',
          amount: 200,
          dueDate: DateTime(2026, 10, 1),
          status: PaymentStatus.due,
          proofFileName: '1790000000000.jpg',
          proofCycleId: cycle,
          reviewStatus: review,
        );

    ReviewPaymentProofEvent onCycle(String cycle) => ReviewPaymentProofEvent(
      supervisorId: 'sup1',
      snapshot: _snapshot,
      command: PaymentReviewCommand(
        paymentId: 'p1',
        decision: PaymentReviewWire.partial,
        amountMode: PaymentAmountMode.receipt,
        amountMinorUnits: 5000,
        expectedProofFileName: '1790000000000.jpg',
        expectedProofCycleId: cycle,
      ),
    );

    Future<void> load() async {
      bloc.add(
        const LoadSupervisedPaymentsEvent(
          supervisorId: 'sup1',
          studentIds: ['s1'],
        ),
      );
      await _settle();
    }

    test('the reviewed cycle is sent with the command', () async {
      bloc.add(onCycle(cycleA));
      await _settle();
      expect(repo.calls.single.command.expectedProofCycleId, cycleA);
    });

    test('a reload on the same cycle keeps the unresolved command', () async {
      repo.failure = const NetworkFailure();
      bloc.add(onCycle(cycleA));
      await _settle();
      payments.result = [pending(cycle: cycleA)];
      await load();
      expect(bloc.state.reviewPaymentUnresolved['p1'], isNotNull);
    });

    test('a reload showing a new cycle drops the unresolved command', () async {
      repo.failure = const NetworkFailure();
      bloc.add(onCycle(cycleA));
      await _settle();
      payments.result = [pending(cycle: cycleB)];
      await load();
      expect(bloc.state.reviewPaymentUnresolved, isEmpty);

      // The new cycle's decision is a new request.
      repo.failure = null;
      bloc.add(onCycle(cycleB));
      await _settle();
      expect(repo.calls[1].requestId, isNot(repo.calls[0].requestId));
    });

    test('a reload showing the payment no longer pending drops it', () async {
      repo.failure = const NetworkFailure();
      bloc.add(onCycle(cycleA));
      await _settle();
      payments.result = [pending(cycle: cycleA, review: 'partial')];
      await load();
      expect(bloc.state.reviewPaymentUnresolved, isEmpty);
    });

    test('a stale-cycle reply settles and reloads, never resends', () async {
      repo.failure = const ServerFailure(kPaymentProofCycleRequiredMessage);
      bloc.add(onCycle(cycleA));
      await _settle();
      expect(bloc.state.reviewPaymentUnresolved, isEmpty);
      expect(payments.loads, hasLength(1));
      expect(repo.calls, hasLength(1));
    });
  });
}
