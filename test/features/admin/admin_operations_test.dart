import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  Future<Either<Failure, Unit>> reviewPaymentProof({
    required String paymentId,
    required PaymentReviewDecision decision,
    String? notes,
    double? amountPaidConfirmed,
  }) async {
    calls.add('review:$paymentId:${decision.wire}:$amountPaidConfirmed');
    if (reviewFailure != null) return Left(reviewFailure!);
    return const Right(unit);
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
    String? phone,
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

    test('partial amount must be strictly between 0 and the invoice', () {
      expect(validatePartialAmount(invoiceAmount: 100, confirmed: 40), isNull);
      expect(
        validatePartialAmount(invoiceAmount: 100, confirmed: 100),
        isNotNull,
      );
      expect(
        validatePartialAmount(invoiceAmount: 100, confirmed: 0),
        isNotNull,
      );
      expect(
        validatePartialAmount(invoiceAmount: 100, confirmed: null),
        isNotNull,
      );
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

    test('non-partial review never forwards a confirmed amount', () async {
      final ops = _FakeOpsRepo();
      await ReviewPaymentProofUseCase(ops)(
        const ReviewPaymentProofParams(
          paymentId: 'p1',
          decision: PaymentReviewDecision.approve,
          invoiceAmount: 100,
          amountPaidConfirmed: 30,
        ),
      );
      expect(ops.calls.single, 'review:p1:approve:null');
    });

    test('invalid partial review does not reach the callable', () async {
      final ops = _FakeOpsRepo();
      final result = await ReviewPaymentProofUseCase(ops)(
        const ReviewPaymentProofParams(
          paymentId: 'p1',
          decision: PaymentReviewDecision.partial,
          invoiceAmount: 100,
          amountPaidConfirmed: 150,
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(ops.calls, isEmpty);
    });
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
        'proofDownloadUrl': 'https://example.test/p.jpg',
        'proofSubmittedAt': Timestamp.fromDate(DateTime(2026, 10, 3)),
      });
      expect(item.paymentId, 'pay1');
      expect(item.amount, 250);
      expect(item.dueDate, DateTime(2026, 10, 5));
      expect(item.hasProofImage, isTrue);
      expect(item.reviewStatus, 'pending_review');
    });

    test('missing proof url yields no image', () {
      final item = paymentReviewItemFromMap('pay2', {'amount': 10});
      expect(item.hasProofImage, isFalse);
      expect(item.parentId, '');
    });
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
    );

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
      bloc.add(
        const SubmitPaymentReviewEvent(
          item: item,
          decision: PaymentReviewDecision.partial,
          amountPaidConfirmed: 40,
        ),
      );
      await _settle();
      expect(ops.calls.last, 'review:p1:partial:40.0');
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
  });
}
