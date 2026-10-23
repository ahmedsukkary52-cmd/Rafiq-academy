import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/data/datasources/admin_operations_remote_datasource.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_operations_entities.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_operations_repository.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_billing_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_operations_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/approve_new_student_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/provision_user_usecase.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_operations_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/payment_review_bloc.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/shared/domain/payment_review_amounts.dart';

class _FakeOpsRepo implements AdminOperationsRepository {
  final calls = <String>[];
  Map<String, List<String>> children = {};
  List<PaymentReviewItem> pending = [];
  Failure? reviewFailure;
  Failure? directoryFailure;

  @override
  Future<Either<Failure, List<AdminDirectoryUser>>> listUsersByRole(
    String role,
  ) async {
    if (directoryFailure != null) return Left(directoryFailure!);
    return Right([
      AdminDirectoryUser(uid: '${role}1', name: 'اسم $role', role: role),
    ]);
  }

  @override
  Future<Either<Failure, List<HalaqaEntity>>> listHalaqat() async =>
      const Right([]);

  @override
  Future<Either<Failure, List<String>>> getParentChildrenIds(
    String parentId,
  ) async => Right(children[parentId] ?? const []);

  @override
  Future<Either<Failure, ParentLinkResult>> linkParentChild({
    required String parentId,
    required String studentId,
    required ParentLinkOperation operation,
  }) async {
    calls.add('link:$parentId:$studentId:${operation.wire}');
    final current = [...?children[parentId]];
    final had = current.contains(studentId);
    if (operation == ParentLinkOperation.link && !had) current.add(studentId);
    if (operation == ParentLinkOperation.unlink) current.remove(studentId);
    children[parentId] = current;
    return Right(
      ParentLinkResult(
        childrenIds: current,
        changed: operation == ParentLinkOperation.link ? !had : had,
      ),
    );
  }

  @override
  Future<Either<Failure, String>> createHalaqa({
    required String name,
    required String teacherId,
    String? supervisorId,
    String? meetingLink,
    required List<HalaqaSlotInput> schedule,
    required String requestId,
  }) async {
    calls.add('create:$name:$teacherId:${schedule.length}:$requestId');
    return const Right('h1');
  }

  @override
  Future<Either<Failure, String>> addHalaqaSlot({
    required String halaqaId,
    required HalaqaSlotInput slot,
  }) async {
    calls.add('slot:$halaqaId:${slot.day}');
    return const Right('s1');
  }

  Failure? meetingLinkFailure;

  @override
  Future<Either<Failure, MeetingLinkChange>> setHalaqaMeetingLink({
    required String halaqaId,
    String? meetingLink,
    bool clear = false,
  }) async {
    calls.add(
      clear ? 'link-clear:$halaqaId' : 'link-set:$halaqaId:$meetingLink',
    );
    if (meetingLinkFailure != null) return Left(meetingLinkFailure!);
    return Right(clear ? MeetingLinkChange.clear : MeetingLinkChange.update);
  }

  @override
  Future<Either<Failure, Unit>> transferStudent({
    required String studentId,
    required String fromHalaqaId,
    required String toHalaqaId,
  }) async {
    calls.add('transfer:$studentId:$fromHalaqaId:$toHalaqaId');
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<PaymentReviewItem>>> listPendingPaymentProofs({
    required String reviewerUid,
    required bool isAdmin,
  }) async {
    calls.add('pending:$reviewerUid:$isAdmin');
    return Right(pending);
  }

  final reviews = <(PaymentReviewCommand, String)>[];
  Completer<void>? reviewGate;
  bool replayed = false;

  @override
  Future<Either<Failure, PaymentReviewResult>> reviewPaymentProof({
    required PaymentReviewCommand command,
    required String requestId,
  }) async {
    reviews.add((command, requestId));
    calls.add(
      'review:${command.paymentId}:${command.decision}:'
      '${command.amountMode?.wire}:${command.amountMinorUnits}',
    );
    await reviewGate?.future;
    if (reviewFailure != null) return Left(reviewFailure!);
    return Right(
      PaymentReviewResult(
        paymentId: command.paymentId,
        reviewStatus: command.decision,
        replayed: replayed,
      ),
    );
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

class _FakeAdminRepo implements AdminRepository {
  final calls = <String>[];

  @override
  Future<Either<Failure, String>> provisionUser({
    required String email,
    required String password,
    required String name,
    required String role,
    bool isActive = true,
  }) async {
    calls.add('provision:$email:$role');
    return const Right('newUid');
  }

  @override
  Future<Either<Failure, Unit>> approveNewStudent({
    required String studentId,
    required String halaqaId,
  }) async {
    calls.add('admit:$studentId:$halaqaId');
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> reinstatePaymentAccess({
    required String parentId,
    String? reason,
  }) async {
    calls.add('reinstate:$parentId:$reason');
    return const Right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _slot = HalaqaSlotInput(
  day: 'السبت',
  startTime: '16:00',
  endTime: '17:00',
);

AdminOperationsBloc _opsBloc(_FakeOpsRepo ops, _FakeAdminRepo admin) =>
    AdminOperationsBloc(
      listUsersByRole: ListUsersByRoleUseCase(ops),
      listHalaqat: ListAdminHalaqatUseCase(ops),
      getParentChildren: GetParentChildrenUseCase(ops),
      provisionUser: ProvisionUserUseCase(admin),
      linkParentChild: LinkParentChildUseCase(ops),
      createHalaqa: CreateHalaqaUseCase(ops),
      addHalaqaSlot: AddHalaqaSlotUseCase(ops),
      setMeetingLink: SetHalaqaMeetingLinkUseCase(ops),
      admitStudent: ApproveNewStudentUseCase(admin),
      transferStudent: TransferStudentUseCase(ops),
      reinstatePaymentAccess: ReinstatePaymentAccessUseCase(admin),
    );

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('Admin operations validation (client pre-checks)', () {
    test('slot validator enforces HH:mm and end after start', () {
      expect(validateSlotInput(_slot), isNull);
      expect(
        validateSlotInput(
          const HalaqaSlotInput(day: 'السبت', startTime: '9', endTime: '10:00'),
        ),
        'أدخل الوقت بصيغة HH:mm',
      );
      expect(
        validateSlotInput(
          const HalaqaSlotInput(
            day: 'السبت',
            startTime: '17:00',
            endTime: '17:00',
          ),
        ),
        'وقت النهاية يجب أن يكون بعد وقت البداية',
      );
      expect(isValidClockTime('24:00'), isFalse);
    });

    test('halaqa request ids match the callable idempotency pattern', () {
      final id = newHalaqaRequestId();
      expect(RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(id), isTrue);
      expect(newHalaqaRequestId(), isNot(id));
    });

    test(
      'D8: CreateHalaqa rejects an empty schedule before any call',
      () async {
        final ops = _FakeOpsRepo();
        final result = await CreateHalaqaUseCase(ops)(
          CreateHalaqaParams(
            name: 'حلقة',
            teacherId: 't1',
            schedule: const [],
            requestId: newHalaqaRequestId(),
          ),
        );
        expect(result.isLeft(), isTrue);
        expect(ops.calls, isEmpty);
      },
    );

    test('transfer to the same halaqa is rejected locally', () async {
      final ops = _FakeOpsRepo();
      final result = await TransferStudentUseCase(ops)(
        const TransferStudentParams(
          studentId: 's1',
          fromHalaqaId: 'h1',
          toHalaqaId: 'h1',
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(ops.calls, isEmpty);
    });

    const snapshot = PaymentAmountSnapshot(invoice: 10000, previous: 4000);
    const requestId = 'req_0123456789abcdef';

    test('an approval carrying an amount is refused locally', () async {
      final ops = _FakeOpsRepo();
      final result = await ReviewPaymentProofUseCase(ops)(
        ReviewPaymentProofParams(
          command: PaymentReviewCommand(
            paymentId: 'p1',
            decision: PaymentReviewWire.approve,
            amountMode: PaymentAmountMode.receipt,
            amountMinorUnits: 3000,
            expectedProofFileName: '1.jpg',
          ),
          requestId: requestId,
          snapshot: snapshot,
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(ops.calls, isEmpty);
    });

    test('invalid partial review does not reach the callable', () async {
      final ops = _FakeOpsRepo();
      for (final (mode, amount) in [
        (PaymentAmountMode.receipt, 6000),
        (PaymentAmountMode.receipt, 0),
        (PaymentAmountMode.cumulative, 4000),
        (PaymentAmountMode.cumulative, 10001),
      ]) {
        final result = await ReviewPaymentProofUseCase(ops)(
          ReviewPaymentProofParams(
            command: PaymentReviewCommand(
              paymentId: 'p1',
              decision: PaymentReviewWire.partial,
              amountMode: mode,
              amountMinorUnits: amount,
              expectedProofFileName: '1.jpg',
            ),
            requestId: requestId,
            snapshot: snapshot,
          ),
        );
        expect(result.isLeft(), isTrue, reason: '$mode $amount');
      }
      expect(ops.calls, isEmpty);
    });

    test(
      'a missing proof name or bad requestId never reaches the callable',
      () async {
        final ops = _FakeOpsRepo();
        for (final (proof, id) in [('', requestId), ('1.jpg', 'short')]) {
          final result = await ReviewPaymentProofUseCase(ops)(
            ReviewPaymentProofParams(
              command: PaymentReviewCommand(
                paymentId: 'p1',
                decision: PaymentReviewWire.reject,
                expectedProofFileName: proof,
              ),
              requestId: id,
              snapshot: snapshot,
            ),
          );
          expect(result.isLeft(), isTrue);
        }
        expect(ops.calls, isEmpty);
      },
    );
  });

  group('paymentReviewItemFromMap', () {
    test('maps invoice context and proof fields', () {
      final item = paymentReviewItemFromMap('pay1', {
        'parentId': 'par1',
        'studentId': 'stu1',
        'amount': 250,
        'currency': 'EGP',
        'periodKey': '2026-10',
        'dueDate': Timestamp.fromDate(DateTime(2026, 10, 5)),
        'status': 'pending',
        'reviewStatus': 'pending_review',
        'proofStoragePath': 'payment_proofs/par1/pay1/1760000000000.jpg',
        'proofSubmittedAt': Timestamp.fromDate(DateTime(2026, 10, 3)),
      });
      expect(item.paymentId, 'pay1');
      expect(item.amount, 250);
      expect(item.dueDate, DateTime(2026, 10, 5));
      expect(item.hasProofImage, isTrue);
      expect(item.reviewStatus, 'pending_review');
      expect(item.amountPaidConfirmed, isNull);
      expect(item.amountSnapshot, const PaymentAmountSnapshot(invoice: 25000));
    });

    test('maps the previously confirmed cumulative total', () {
      final item = paymentReviewItemFromMap('pay5', {
        'amount': 200,
        'amountPaidConfirmed': 60,
        'proofFileName': '1790000000000.jpg',
      });
      expect(item.amountPaidConfirmed, 60);
      expect(item.amountSnapshot.remaining, 14000);
      expect(item.proofFileName, '1790000000000.jpg');
      expect(item.withStudentName('x').amountPaidConfirmed, 60);
    });

    test('missing proof path yields no image', () {
      final item = paymentReviewItemFromMap('pay2', {'amount': 10});
      expect(item.hasProofImage, isFalse);
      expect(item.hasProofMetadata, isFalse);
      expect(item.parentId, '');
    });

    test('a legacy download URL alone is never treated as a proof image', () {
      final item = paymentReviewItemFromMap('pay3', {
        'parentId': 'par1',
        'proofDownloadUrl': 'https://evil.example/p.jpg',
      });
      expect(item.hasProofImage, isFalse);
      expect(item.hasProofMetadata, isFalse);
    });

    test(
      'a path for another parent or payment is metadata but not trusted',
      () {
        for (final path in [
          'payment_proofs/other/pay4/1.jpg',
          'payment_proofs/par1/other/1.jpg',
          'https://evil.example/payment_proofs/par1/pay4/1.jpg',
          'payment_proofs/par1/pay4/../x.jpg',
          'payment_proofs/par1/pay4/1.gif',
        ]) {
          final item = paymentReviewItemFromMap('pay4', {
            'parentId': 'par1',
            'proofStoragePath': path,
          });
          expect(item.hasProofMetadata, isTrue, reason: path);
          expect(item.hasProofImage, isFalse, reason: path);
        }
      },
    );
  });

  group('AdminOperationsBloc', () {
    test('loads the role directory', () async {
      final bloc = _opsBloc(_FakeOpsRepo(), _FakeAdminRepo());
      bloc.add(const LoadAdminDirectoryEvent());
      await _settle();
      expect(bloc.state.directoryStatus, SectionStatus.loaded);
      expect(bloc.state.parents.single.uid, '${AppRoles.parent}1');
      expect(bloc.state.teachers, hasLength(1));
      await bloc.close();
    });

    test('directory failure surfaces an error state', () async {
      final ops = _FakeOpsRepo()
        ..directoryFailure = const ServerFailure('تعذر');
      final bloc = _opsBloc(ops, _FakeAdminRepo());
      bloc.add(const LoadAdminDirectoryEvent());
      await _settle();
      expect(bloc.state.directoryStatus, SectionStatus.error);
      expect(bloc.state.directoryError, 'تعذر');
      await bloc.close();
    });

    test('P0-01 link updates the selected parent children', () async {
      final ops = _FakeOpsRepo();
      final bloc = _opsBloc(ops, _FakeAdminRepo());
      bloc.add(const SelectParentEvent('par1'));
      await _settle();
      bloc.add(
        const LinkParentChildEvent(
          LinkParentChildParams(
            parentId: 'par1',
            studentId: 'stu1',
            operation: ParentLinkOperation.link,
          ),
        ),
      );
      await _settle();
      expect(ops.calls, contains('link:par1:stu1:link'));
      expect(bloc.state.selectedParentChildren, ['stu1']);
      expect(bloc.state.submissionStatus, SubmissionStatus.success);
      expect(bloc.state.message, 'تم ربط الطالب بولي الأمر');
      await bloc.close();
    });

    test('P0-04 create halaqa forwards the idempotency key', () async {
      final ops = _FakeOpsRepo();
      final bloc = _opsBloc(ops, _FakeAdminRepo());
      bloc.add(
        const CreateHalaqaEvent(
          CreateHalaqaParams(
            name: ' حلقة الفجر ',
            teacherId: 't1',
            schedule: [_slot],
            requestId: 'req_12345678',
          ),
        ),
      );
      await _settle();
      expect(ops.calls, contains('create:حلقة الفجر:t1:1:req_12345678'));
      expect(bloc.state.message, 'تم إنشاء الحلقة ومواعيدها');
      await bloc.close();
    });

    test('validation failure reports an error message', () async {
      final ops = _FakeOpsRepo();
      final bloc = _opsBloc(ops, _FakeAdminRepo());
      bloc.add(
        const AddHalaqaSlotEvent(
          AddHalaqaSlotParams(
            halaqaId: 'h1',
            slot: HalaqaSlotInput(
              day: 'السبت',
              startTime: '18:00',
              endTime: '17:00',
            ),
          ),
        ),
      );
      await _settle();
      expect(ops.calls, isEmpty);
      expect(bloc.state.submissionStatus, SubmissionStatus.error);
      expect(bloc.state.message, 'وقت النهاية يجب أن يكون بعد وقت البداية');
      bloc.add(const ClearAdminOperationMessageEvent());
      await _settle();
      expect(bloc.state.submissionStatus, SubmissionStatus.idle);
      expect(bloc.state.message, isNull);
      await bloc.close();
    });

    test(
      'provision, admit, transfer and reinstate use existing callables',
      () async {
        final ops = _FakeOpsRepo();
        final admin = _FakeAdminRepo();
        final bloc = _opsBloc(ops, admin);
        bloc.add(
          const ProvisionAccountEvent(
            ProvisionUserParams(
              email: 'a@b.c',
              password: 'secret1',
              name: 'ولي',
              role: AppRoles.parent,
            ),
          ),
        );
        await _settle();
        bloc.add(const AdmitStudentEvent(studentId: 's1', halaqaId: 'h1'));
        await _settle();
        bloc.add(
          const TransferStudentEvent(
            TransferStudentParams(
              studentId: 's1',
              fromHalaqaId: 'h1',
              toHalaqaId: 'h2',
            ),
          ),
        );
        await _settle();
        bloc.add(const ReinstateParentAccessEvent(parentId: 'par1'));
        await _settle();
        expect(admin.calls, [
          'provision:a@b.c:${AppRoles.parent}',
          'admit:s1:h1',
          'reinstate:par1:null',
        ]);
        expect(ops.calls, contains('transfer:s1:h1:h2'));
        await bloc.close();
      },
    );

    test(
      'B14 create halaqa rejects a non-https meeting link locally',
      () async {
        final ops = _FakeOpsRepo();
        final result = await CreateHalaqaUseCase(ops)(
          const CreateHalaqaParams(
            name: 'حلقة',
            teacherId: 't1',
            schedule: [_slot],
            requestId: 'req_12345678',
            meetingLink: 'http://meet.example.com/abc',
          ),
        );
        expect(result.isLeft(), isTrue);
        expect(ops.calls, isEmpty);
      },
    );

    test('B14 edit sends the trimmed link and reloads the directory', () async {
      final ops = _FakeOpsRepo();
      final bloc = _opsBloc(ops, _FakeAdminRepo());
      bloc.add(
        const SetHalaqaMeetingLinkEvent(
          SetHalaqaMeetingLinkParams(
            halaqaId: 'h1',
            meetingLink: '  https://meet.example.com/new  ',
          ),
        ),
      );
      await _settle();
      expect(ops.calls, contains('link-set:h1:https://meet.example.com/new'));
      expect(bloc.state.submissionStatus, SubmissionStatus.success);
      expect(bloc.state.message, 'تم تحديث رابط الاجتماع');
      await bloc.close();
    });

    test('B14 invalid link never reaches the callable', () async {
      final ops = _FakeOpsRepo();
      final bloc = _opsBloc(ops, _FakeAdminRepo());
      for (final bad in [
        '',
        'meet.example.com/abc',
        'https://user:pw@meet.example.com',
        'https://meet.example.com/a b',
      ]) {
        bloc.add(
          SetHalaqaMeetingLinkEvent(
            SetHalaqaMeetingLinkParams(halaqaId: 'h1', meetingLink: bad),
          ),
        );
        await _settle();
        expect(bloc.state.submissionStatus, SubmissionStatus.error);
      }
      expect(ops.calls.where((c) => c.startsWith('link-')), isEmpty);
      await bloc.close();
    });

    test('B14 clear is explicit and separate from an empty save', () async {
      final ops = _FakeOpsRepo();
      final bloc = _opsBloc(ops, _FakeAdminRepo());
      bloc.add(
        const SetHalaqaMeetingLinkEvent(SetHalaqaMeetingLinkParams.clear('h1')),
      );
      await _settle();
      expect(ops.calls, contains('link-clear:h1'));
      expect(bloc.state.message, 'تم حذف رابط الاجتماع');
      await bloc.close();
    });

    test('B14 server rejection is surfaced without echoing the link', () async {
      final ops = _FakeOpsRepo()
        ..meetingLinkFailure = const ServerFailure('رابط الاجتماع غير صالح');
      final bloc = _opsBloc(ops, _FakeAdminRepo());
      bloc.add(
        const SetHalaqaMeetingLinkEvent(
          SetHalaqaMeetingLinkParams(
            halaqaId: 'h1',
            meetingLink: 'https://meet.example.com/x',
          ),
        ),
      );
      await _settle();
      expect(bloc.state.submissionStatus, SubmissionStatus.error);
      expect(bloc.state.message, isNot(contains('meet.example.com')));
      await bloc.close();
    });
  });

  group('PaymentReviewBloc (P0-03)', () {
    const item = PaymentReviewItem(
      paymentId: 'p1',
      parentId: 'par1',
      studentId: 's1',
      amount: 100,
      proofFileName: '1790000000000.jpg',
    );

    PaymentReviewBloc newBloc(_FakeOpsRepo ops) => PaymentReviewBloc(
      listPending: ListPendingPaymentProofsUseCase(ops),
      reviewProof: ReviewPaymentProofUseCase(ops),
    );

    SubmitPaymentReviewEvent partial(int amount, {String? notes}) =>
        SubmitPaymentReviewEvent(
          item: item,
          decision: PaymentReviewDecision.partial,
          notes: notes,
          amountMode: PaymentAmountMode.receipt,
          amountMinorUnits: amount,
        );

    test(
      'partial sends the receipt mode bound to the reviewed proof',
      () async {
        final ops = _FakeOpsRepo()..pending = [item];
        final bloc = newBloc(ops);
        bloc.add(
          const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true),
        );
        await _settle();
        bloc.add(partial(4000, notes: ' دفعة أولى '));
        await _settle();
        final (command, requestId) = ops.reviews.single;
        expect(command.decision, 'partial');
        expect(command.amountMode, PaymentAmountMode.receipt);
        expect(command.amountMinorUnits, 4000);
        expect(command.notes, 'دفعة أولى');
        expect(command.expectedProofFileName, '1790000000000.jpg');
        expect(kPaymentReviewRequestIdPattern.hasMatch(requestId), isTrue);
        await bloc.close();
      },
    );

    test('approval ignores any amount typed by the reviewer', () async {
      final ops = _FakeOpsRepo()..pending = [item];
      final bloc = newBloc(ops);
      bloc.add(
        const SubmitPaymentReviewEvent(
          item: item,
          decision: PaymentReviewDecision.approve,
          amountMode: PaymentAmountMode.cumulative,
          amountMinorUnits: 3000,
        ),
      );
      await _settle();
      expect(ops.calls.single, 'review:p1:approve:null:null');
      await bloc.close();
    });

    test('a retry after a network error reuses the requestId', () async {
      final ops = _FakeOpsRepo()
        ..pending = [item]
        ..reviewFailure = const NetworkFailure();
      final bloc = newBloc(ops);
      bloc.add(partial(4000));
      await _settle();
      bloc.add(partial(4000));
      await _settle();
      expect(ops.reviews[1].$2, ops.reviews[0].$2);

      bloc.add(partial(4500));
      await _settle();
      expect(ops.reviews[2].$2, isNot(ops.reviews[0].$2));

      ops.reviewFailure = null;
      bloc.add(partial(4500));
      await _settle();
      expect(ops.reviews[3].$2, ops.reviews[2].$2);
      expect(bloc.state.submissionStatus, SubmissionStatus.success);
      await bloc.close();
    });

    test('a new decision after success gets a new requestId', () async {
      final ops = _FakeOpsRepo()..pending = [item];
      final bloc = newBloc(ops);
      bloc.add(partial(4000));
      await _settle();
      bloc.add(partial(4000));
      await _settle();
      expect(ops.reviews[1].$2, isNot(ops.reviews[0].$2));
      await bloc.close();
    });

    test('a changed proof reloads the list and never resends', () async {
      final ops = _FakeOpsRepo()
        ..pending = [item]
        ..reviewFailure = const ServerFailure(kPaymentProofChangedMessage);
      final bloc = newBloc(ops);
      bloc.add(const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true));
      await _settle();
      ops.calls.clear();
      bloc.add(partial(4000));
      await _settle();
      expect(ops.calls, ['review:p1:partial:receipt:4000', 'pending:a1:true']);
      expect(ops.reviews, hasLength(1));
      expect(bloc.state.status, SectionStatus.loaded);
      await bloc.close();
    });

    test('concurrent submissions are dropped while one is in flight', () async {
      final ops = _FakeOpsRepo()
        ..pending = [item]
        ..reviewGate = Completer<void>();
      final bloc = newBloc(ops);
      bloc
        ..add(partial(4000))
        ..add(partial(4000))
        ..add(
          const SubmitPaymentReviewEvent(
            item: item,
            decision: PaymentReviewDecision.reject,
          ),
        );
      await _settle();
      ops.reviewGate!.complete();
      await _settle();
      expect(ops.reviews, hasLength(1));
      await bloc.close();
    });

    test('loads pending proofs for a supervisor scope', () async {
      final ops = _FakeOpsRepo()..pending = [item];
      final bloc = PaymentReviewBloc(
        listPending: ListPendingPaymentProofsUseCase(ops),
        reviewProof: ReviewPaymentProofUseCase(ops),
      );
      bloc.add(
        const LoadPendingProofsEvent(reviewerUid: 'sup1', isAdmin: false),
      );
      await _settle();
      expect(ops.calls.single, 'pending:sup1:false');
      expect(bloc.state.status, SectionStatus.loaded);
      expect(bloc.state.items, [item]);
      await bloc.close();
    });

    test('a decision removes the proof from the pending list', () async {
      final ops = _FakeOpsRepo()..pending = [item];
      final bloc = PaymentReviewBloc(
        listPending: ListPendingPaymentProofsUseCase(ops),
        reviewProof: ReviewPaymentProofUseCase(ops),
      );
      bloc.add(const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true));
      await _settle();
      bloc.add(partial(4000));
      await _settle();
      expect(ops.calls.last, 'review:p1:partial:receipt:4000');
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.submissionStatus, SubmissionStatus.success);
      await bloc.close();
    });

    test('a server rejection keeps the proof and reports the error', () async {
      final ops = _FakeOpsRepo()
        ..pending = [item]
        ..reviewFailure = const ServerFailure('تمت مراجعة الإيصال مسبقاً');
      final bloc = PaymentReviewBloc(
        listPending: ListPendingPaymentProofsUseCase(ops),
        reviewProof: ReviewPaymentProofUseCase(ops),
      );
      bloc.add(const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true));
      await _settle();
      bloc.add(
        const SubmitPaymentReviewEvent(
          item: item,
          decision: PaymentReviewDecision.reject,
        ),
      );
      await _settle();
      expect(bloc.state.items, [item]);
      expect(bloc.state.submissionStatus, SubmissionStatus.error);
      expect(bloc.state.message, 'تمت مراجعة الإيصال مسبقاً');
      await bloc.close();
    });

    Future<PaymentReviewBloc> loaded(_FakeOpsRepo ops) async {
      final bloc = newBloc(ops);
      bloc.add(const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true));
      await _settle();
      ops.calls.clear();
      return bloc;
    }

    test('closing the page mid-review never adds to the closed bloc', () async {
      final recorder = _ErrorRecorder();
      final previous = Bloc.observer;
      Bloc.observer = recorder;
      addTearDown(() => Bloc.observer = previous);
      final ops = _FakeOpsRepo()
        ..pending = [item]
        ..reviewGate = Completer<void>()
        ..reviewFailure = const ServerFailure(kPaymentProofChangedMessage);
      final bloc = await loaded(ops);
      bloc.add(partial(4000));
      await _settle();
      final closing = bloc.close();
      ops.reviewGate!.complete();
      await closing;
      await _settle();
      expect(recorder.errors, isEmpty);
      expect(ops.calls, ['review:p1:partial:receipt:4000']);
    });

    for (final message in kPaymentNoLongerPendingMessages) {
      test('"$message" settles, reloads and never resends', () async {
        final ops = _FakeOpsRepo()
          ..pending = [item]
          ..reviewFailure = ServerFailure(message);
        final bloc = await loaded(ops);
        bloc.add(partial(4000));
        await _settle();
        expect(ops.calls, [
          'review:p1:partial:receipt:4000',
          'pending:a1:true',
        ]);
        expect(bloc.state.message, kPaymentNoLongerPendingNotice);
        expect(bloc.state.unresolved, isEmpty);

        // The reload shows the server truth; a new attempt is a new request.
        ops.reviewFailure = null;
        bloc.add(partial(4000));
        await _settle();
        expect(ops.reviews, hasLength(2));
        expect(ops.reviews[1].$2, isNot(ops.reviews[0].$2));
        await bloc.close();
      });
    }

    test('other preconditions are not mistaken for "already reviewed"', () {
      for (final message in [
        'الدفعة خارج نطاق إشرافك',
        'مبلغ الفاتورة غير صالح',
        kPaymentProofChangedMessage,
      ]) {
        expect(isPaymentNoLongerPendingMessage(message), isFalse);
      }
      expect(
        paymentReviewFailureKind(const ServerFailure('deadline-exceeded')),
        PaymentReviewFailureKind.unresolved,
      );
    });

    test(
      'a replayed result reloads instead of removing the current row',
      () async {
        final ops = _FakeOpsRepo()
          ..pending = [item]
          ..replayed = true;
        final bloc = await loaded(ops);
        bloc.add(partial(4000));
        await _settle();
        expect(ops.calls, [
          'review:p1:partial:receipt:4000',
          'pending:a1:true',
        ]);
        expect(bloc.state.message, kPaymentReviewReplayedMessage);
        await bloc.close();
      },
    );

    test('an old result never removes a newer proof of the payment', () async {
      final ops = _FakeOpsRepo()
        ..pending = [item]
        ..reviewGate = Completer<void>();
      final bloc = await loaded(ops);
      bloc.add(partial(4000));
      await _settle();
      const newer = PaymentReviewItem(
        paymentId: 'p1',
        parentId: 'par1',
        studentId: 's1',
        amount: 100,
        proofFileName: '1790000009999.jpg',
      );
      ops.pending = [newer];
      bloc.add(const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true));
      await _settle();
      ops.reviewGate!.complete();
      await _settle();
      expect(bloc.state.submissionStatus, SubmissionStatus.success);
      expect(bloc.state.items, [newer]);
      await bloc.close();
    });

    test(
      'an unresolved decision is kept and retried verbatim with its id',
      () async {
        final ops = _FakeOpsRepo()
          ..pending = [item]
          ..reviewFailure = const ServerFailure('deadline-exceeded');
        final bloc = await loaded(ops);
        bloc.add(partial(4000, notes: 'دفعة أولى'));
        await _settle();
        final kept = bloc.state.unresolvedFor(item)!;
        expect(kept.amountMinorUnits, 4000);
        expect(kept.notes, 'دفعة أولى');

        ops.reviewFailure = null;
        bloc.add(SubmitPaymentReviewEvent.retry(item, kept));
        await _settle();
        expect(ops.reviews[1].$1, ops.reviews[0].$1);
        expect(ops.reviews[1].$2, ops.reviews[0].$2);
        expect(bloc.state.unresolved, isEmpty);
        await bloc.close();
      },
    );

    test('a changed command never reuses the unresolved id', () async {
      final ops = _FakeOpsRepo()
        ..pending = [item]
        ..reviewFailure = const NetworkFailure();
      final bloc = await loaded(ops);
      bloc.add(partial(4000));
      await _settle();
      bloc.add(partial(4000, notes: 'تعديل'));
      await _settle();
      bloc.add(
        const SubmitPaymentReviewEvent(
          item: item,
          decision: PaymentReviewDecision.reject,
        ),
      );
      await _settle();
      final ids = ops.reviews.map((r) => r.$2).toSet();
      expect(ids, hasLength(3));
      expect(bloc.state.unresolvedFor(item)!.decision, 'reject');
      await bloc.close();
    });

    test(
      'a reload with a newer proof drops the stale unresolved decision',
      () async {
        final ops = _FakeOpsRepo()
          ..pending = [item]
          ..reviewFailure = const NetworkFailure();
        final bloc = await loaded(ops);
        bloc.add(partial(4000));
        await _settle();
        expect(bloc.state.unresolved, isNotEmpty);
        ops.pending = [
          const PaymentReviewItem(
            paymentId: 'p1',
            parentId: 'par1',
            studentId: 's1',
            amount: 100,
            proofFileName: '1790000009999.jpg',
          ),
        ];
        bloc.add(
          const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true),
        );
        await _settle();
        expect(bloc.state.unresolved, isEmpty);
        await bloc.close();
      },
    );

    group('proof cycle', () {
      const cycleA = 'pc_AAAAAAAAAAAAAAAAAAAAAAAA';
      const cycleB = 'pc_BBBBBBBBBBBBBBBBBBBBBBBB';
      const onA = PaymentReviewItem(
        paymentId: 'p1',
        parentId: 'par1',
        studentId: 's1',
        amount: 100,
        proofFileName: '1790000000000.jpg',
        proofCycleId: cycleA,
      );
      // Same file name, newer server cycle.
      const onB = PaymentReviewItem(
        paymentId: 'p1',
        parentId: 'par1',
        studentId: 's1',
        amount: 100,
        proofFileName: '1790000000000.jpg',
        proofCycleId: cycleB,
      );

      SubmitPaymentReviewEvent partialOn(PaymentReviewItem i) =>
          SubmitPaymentReviewEvent(
            item: i,
            decision: PaymentReviewDecision.partial,
            amountMode: PaymentAmountMode.receipt,
            amountMinorUnits: 4000,
          );

      test('the command carries the reviewed cycle', () async {
        final ops = _FakeOpsRepo()..pending = [onA];
        final bloc = await loaded(ops);
        bloc.add(partialOn(onA));
        await _settle();
        expect(ops.reviews.single.$1.expectedProofCycleId, cycleA);
        await bloc.close();
      });

      test('a result for cycle A never removes cycle B', () async {
        final ops = _FakeOpsRepo()
          ..pending = [onA]
          ..reviewGate = Completer<void>();
        final bloc = await loaded(ops);
        bloc.add(partialOn(onA));
        await _settle();
        ops.pending = [onB];
        bloc.add(
          const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true),
        );
        await _settle();
        ops.reviewGate!.complete();
        await _settle();
        expect(bloc.state.items, [onB]);
        await bloc.close();
      });

      test(
        'an unresolved decision on A is dropped once B is pending',
        () async {
          final ops = _FakeOpsRepo()
            ..pending = [onA]
            ..reviewFailure = const NetworkFailure();
          final bloc = await loaded(ops);
          bloc.add(partialOn(onA));
          await _settle();
          expect(bloc.state.unresolvedFor(onA), isNotNull);
          expect(bloc.state.unresolvedFor(onB), isNull);

          ops.pending = [onB];
          bloc.add(
            const LoadPendingProofsEvent(reviewerUid: 'a1', isAdmin: true),
          );
          await _settle();
          expect(bloc.state.unresolved, isEmpty);

          ops.reviewFailure = null;
          bloc.add(partialOn(onB));
          await _settle();
          expect(ops.reviews[1].$2, isNot(ops.reviews[0].$2));
          expect(ops.reviews[1].$1.expectedProofCycleId, cycleB);
          await bloc.close();
        },
      );

      test('a stale-cycle reply settles, reloads and never resends', () async {
        final ops = _FakeOpsRepo()
          ..pending = [onA]
          ..reviewFailure = const ServerFailure(
            kPaymentProofCycleRequiredMessage,
          );
        final bloc = await loaded(ops);
        bloc.add(partialOn(onA));
        await _settle();
        expect(bloc.state.unresolved, isEmpty);
        expect(ops.calls.last, 'pending:a1:true');
        expect(ops.reviews, hasLength(1));
        await bloc.close();
      });
    });
  });
}
