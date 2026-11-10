import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_operations_entities.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_operations_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_operations_usecases.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/payment_review_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/payment_review_page.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/shared/domain/payment_proof_reader.dart';
import 'package:rafiq_academy/shared/widgets/payment_proof_image.dart';
import 'package:rafiq_academy/shared/domain/payment_review_amounts.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

/// 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

class _FakeAuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthAuthenticated(
    UserEntity(
      uid: 'a1',
      name: 'مدير',
      role: 'admin',
      email: 'a@example.com',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() => _controller.close();
}

class _Repo implements AdminOperationsRepository {
  List<PaymentReviewItem> pending = [];
  final reviews = <(PaymentReviewCommand, String)>[];
  Failure? failure;
  Completer<void>? gate;

  @override
  Future<Either<Failure, List<PaymentReviewItem>>> listPendingPaymentProofs({
    required String reviewerUid,
    required bool isAdmin,
  }) async => Right(pending);

  @override
  Future<Either<Failure, PaymentReviewResult>> reviewPaymentProof({
    required PaymentReviewCommand command,
    required String requestId,
  }) async {
    reviews.add((command, requestId));
    await gate?.future;
    if (failure != null) return Left(failure!);
    return Right(PaymentReviewResult(paymentId: command.paymentId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProofRepo extends Fake implements ParentRepository {
  Either<Failure, Uint8List> result = Right(_png);
  Completer<void>? gate;
  int downloads = 0;

  @override
  Future<Either<Failure, Uint8List>> downloadPaymentProof({
    required String parentId,
    required String paymentId,
    required String storagePath,
  }) async {
    downloads++;
    await gate?.future;
    return result;
  }
}

PaymentReviewItem _item(String id, {double? confirmed}) => PaymentReviewItem(
  paymentId: id,
  parentId: 'par1',
  studentId: 's$id',
  studentName: 'طالب $id',
  amount: 100,
  amountPaidConfirmed: confirmed,
  proofFileName: '1790000000000.jpg',
  proofStoragePath: 'payment_proofs/par1/$id/1790000000000.jpg',
);

/// Image decoding is real I/O that never completes under the fake clock, so
/// the proof PNG is decoded into the image cache before the page is built.
Future<void> _precacheProof(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(
    () => precacheImage(MemoryImage(_png), tester.element(find.byType(SizedBox))),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

/// Lets a decode that started inside the page finish (or fail) in real time.
Future<void> _awaitRealDecode(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

/// Lets a test swap the listed items without the loading state of a reload,
/// which would unmount the cards.
class _TestPaymentReviewBloc extends PaymentReviewBloc {
  _TestPaymentReviewBloc({
    required super.listPending,
    required super.reviewProof,
  });

  void replaceItems(List<PaymentReviewItem> items) =>
      emit(state.copyWith(items: items));
}

Future<_TestPaymentReviewBloc> _pump(
  WidgetTester tester,
  _Repo repo, {
  _ProofRepo? proofs,
}) async {
  await _precacheProof(tester);
  await sl.reset();
  late _TestPaymentReviewBloc bloc;
  sl.registerFactory<PaymentReviewBloc>(
    () => bloc = _TestPaymentReviewBloc(
      listPending: ListPendingPaymentProofsUseCase(repo),
      reviewProof: ReviewPaymentProofUseCase(repo),
    ),
  );
  sl.registerFactory<DownloadPaymentProofUseCase>(
    () => DownloadPaymentProofUseCase(proofs ?? _ProofRepo()),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: BlocProvider<AuthBloc>.value(
        value: _FakeAuthBloc(),
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: PaymentReviewPage(isAdmin: true),
        ),
      ),
    ),
  );
  await _settle(tester);
  return bloc;
}

final _decisionLabels = [
  PaymentReviewDecision.approve.label,
  PaymentReviewDecision.partial.label,
  PaymentReviewDecision.reject.label,
];

/// The approve / partial / reject buttons of the single pending card.
List<ButtonStyleButton> _decisionButtons(WidgetTester tester) => [
  for (final label in _decisionLabels)
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    ),
];

void _expectDecisionsEnabled(WidgetTester tester, bool enabled) {
  for (final button in _decisionButtons(tester)) {
    expect(button.onPressed != null, enabled);
  }
  expect(
    find.text(kPaymentProofNotLoadedMessage),
    enabled ? findsNothing : findsOne,
  );
}

/// Tapping a disabled decision must neither open the dialog nor dispatch.
Future<void> _tapAllDecisions(WidgetTester tester) async {
  for (final label in _decisionLabels) {
    await tester.tap(find.text(label), warnIfMissed: false);
    await tester.pump();
    expect(find.text('تأكيد'), findsNothing);
  }
}

Future<void> _partial(WidgetTester tester, String amount) async {
  await tester.tap(find.text(PaymentReviewDecision.partial.label).first);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('payment-amount-input')),
    amount,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('تأكيد'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => sl.reset());

  testWidgets('invalid stored amounts are shown as invalid, never as 0 left', (
    tester,
  ) async {
    final repo = _Repo()..pending = [_item('p1', confirmed: 150)];
    await _pump(tester, repo);
    expect(find.text('المبلغ المؤكد السابق لهذه الدفعة غير صالح'), findsOne);
    expect(find.textContaining('المتبقي'), findsNothing);
  });

  testWidgets('valid partial history shows confirmed and remaining amounts', (
    tester,
  ) async {
    final repo = _Repo()..pending = [_item('p1', confirmed: 40)];
    await _pump(tester, repo);
    expect(find.textContaining('المؤكد سابقاً: 40'), findsOne);
    expect(find.textContaining('المتبقي: 60'), findsOne);
  });

  testWidgets(
    'an unresolved decision is retried with the same content and requestId',
    (tester) async {
      final repo = _Repo()
        ..pending = [_item('p1')]
        ..failure = const ServerFailure('deadline-exceeded');
      await _pump(tester, repo);
      await _partial(tester, '40');
      expect(repo.reviews, hasLength(1));
      expect(find.byKey(const ValueKey('payment-review-unresolved')), findsOne);

      repo.failure = null;
      await tester.tap(find.text('إعادة المحاولة بنفس البيانات'));
      await tester.pumpAndSettle();
      expect(repo.reviews, hasLength(2));
      expect(repo.reviews[1].$1, repo.reviews[0].$1);
      expect(repo.reviews[1].$2, repo.reviews[0].$2);
      expect(find.text('طالب p1'), findsNothing);
    },
  );

  testWidgets('other cards are blocked with a message while one is in flight', (
    tester,
  ) async {
    final repo = _Repo()
      ..pending = [_item('p1'), _item('p2')]
      ..gate = Completer<void>();
    await _pump(tester, repo);
    await tester.tap(find.text(PaymentReviewDecision.approve.label).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد'));
    await tester.pump();
    await tester.pump();

    expect(find.text(kPaymentReviewBusyMessage), findsOne);
    final approve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, PaymentReviewDecision.approve.label),
    );
    expect(approve.onPressed, isNull);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(repo.reviews, hasLength(1));
    expect(find.text(kPaymentReviewBusyMessage), findsNothing);
  });

  testWidgets('decisions stay disabled while the proof image is loading', (
    tester,
  ) async {
    final repo = _Repo()..pending = [_item('p1')];
    final proofs = _ProofRepo()..gate = Completer<void>();
    await _pump(tester, repo, proofs: proofs);

    expect(proofs.downloads, 1);
    _expectDecisionsEnabled(tester, false);
    await _tapAllDecisions(tester);
    expect(repo.reviews, isEmpty);

    proofs.gate!.complete();
    await _settle(tester);
    _expectDecisionsEnabled(tester, true);
  });

  testWidgets('a failed proof download keeps decisions disabled until a '
      'retry succeeds', (tester) async {
    final repo = _Repo()..pending = [_item('p1')];
    final proofs = _ProofRepo()
      ..result = const Left(NetworkFailure('لا يوجد اتصال'));
    await _pump(tester, repo, proofs: proofs);

    expect(find.text('لا يوجد اتصال'), findsOne);
    _expectDecisionsEnabled(tester, false);
    await _tapAllDecisions(tester);
    expect(repo.reviews, isEmpty);

    proofs.result = Right(_png);
    await tester.tap(find.text('إعادة المحاولة'));
    await _settle(tester);
    expect(proofs.downloads, 2);
    _expectDecisionsEnabled(tester, true);

    await tester.tap(find.text(PaymentReviewDecision.approve.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(repo.reviews.single.$1.decision, PaymentReviewWire.approve);
  });

  testWidgets('an undecodable proof image keeps decisions disabled', (
    tester,
  ) async {
    final broken = Uint8List.fromList(const [1, 2, 3, 4]);
    final repo = _Repo()..pending = [_item('p1')];
    final proofs = _ProofRepo()..result = Right(broken);
    await _pump(tester, repo, proofs: proofs);
    await _awaitRealDecode(tester);

    expect(find.text('تعذر عرض صورة الإيصال'), findsOne);
    _expectDecisionsEnabled(tester, false);
    await _tapAllDecisions(tester);
    expect(repo.reviews, isEmpty);
  });

  testWidgets('decisions are enabled once the proof image is shown', (
    tester,
  ) async {
    final repo = _Repo()..pending = [_item('p1')];
    await _pump(tester, repo);
    expect(find.byType(Image), findsOne);
    _expectDecisionsEnabled(tester, true);
  });

  testWidgets('a proof that becomes unavailable while the decision dialog is '
      'open blocks the confirmed decision', (tester) async {
    final repo = _Repo()..pending = [_item('p1')];
    final proofs = _ProofRepo();
    final bloc = await _pump(tester, repo, proofs: proofs);
    _expectDecisionsEnabled(tester, true);

    await tester.tap(find.text(PaymentReviewDecision.approve.label));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد'), findsOne);

    // A re-uploaded proof replaces the displayed one; its download stays
    // pending, so no image of the current proof is on screen.
    proofs.gate = Completer<void>();
    const replaced = PaymentReviewItem(
      paymentId: 'p1',
      parentId: 'par1',
      studentId: 'sp1',
      studentName: 'طالب p1',
      amount: 100,
      proofFileName: '1790000000001.jpg',
      proofStoragePath: 'payment_proofs/par1/p1/1790000000001.jpg',
    );
    bloc.replaceItems([replaced]);
    await _settle(tester);
    expect(proofs.downloads, 2);
    expect(find.text('تأكيد'), findsOne);

    await tester.tap(find.text('تأكيد'));
    await _settle(tester);

    expect(repo.reviews, isEmpty);
    expect(bloc.state.submissionStatus, isNot(SubmissionStatus.submitting));
    expect(find.text('طالب p1'), findsOne);
    expect(
      find.descendant(
        of: find.byType(PaymentProofImage),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOne,
    );
    _expectDecisionsEnabled(tester, false);

    proofs.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('تأكيد'), findsNothing);
    expect(repo.reviews, isEmpty);
    _expectDecisionsEnabled(tester, true);
  });

  testWidgets('a card without proof metadata never offers a decision', (
    tester,
  ) async {
    const item = PaymentReviewItem(
      paymentId: 'p1',
      parentId: 'par1',
      studentId: 'sp1',
      studentName: 'طالب p1',
      amount: 100,
      proofFileName: '1790000000000.jpg',
    );
    final repo = _Repo()..pending = [item];
    await _pump(tester, repo);
    _expectDecisionsEnabled(tester, false);
    await _tapAllDecisions(tester);
    expect(repo.reviews, isEmpty);
  });
}
