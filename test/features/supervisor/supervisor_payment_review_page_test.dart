import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_payment_proof.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/submit_payment_proof_usecase.dart';
import 'package:rafiq_academy/features/parent/presentation/widgets/payment_proof_image.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_event.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_state.dart';
import 'package:rafiq_academy/features/supervisor/presentation/pages/supervisor_payments_page.dart';
import 'package:rafiq_academy/shared/domain/payment_review_amounts.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

class _FakeAuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthAuthenticated(
    UserEntity(
      uid: 'sup1',
      name: 'مشرف',
      role: 'supervisor',
      email: 's@example.com',
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

class _FakeSupervisorBloc extends Fake implements SupervisorBloc {
  _FakeSupervisorBloc(this._state);

  SupervisorState _state;
  final _controller = StreamController<SupervisorState>.broadcast();
  final events = <SupervisorEvent>[];

  @override
  SupervisorState get state => _state;

  @override
  Stream<SupervisorState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(SupervisorEvent event) => events.add(event);

  void emitState(SupervisorState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> close() => _controller.close();
}

/// 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

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

PaymentEntity _payment(String id) => PaymentEntity(
  id: id,
  studentId: 's$id',
  parentId: 'par1',
  amount: 200,
  amountPaidConfirmed: 60,
  dueDate: DateTime(2026, 10, 1),
  status: PaymentStatus.due,
  reviewStatus: ParentPaymentProofContract.pendingReview,
  proofFileName: '1790000000000.jpg',
  proofStoragePath: 'payment_proofs/par1/$id/1790000000000.jpg',
);

const _home = 'قائمة المدفوعات';
const _save = 'حفظ نتيجة المراجعة';

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

/// Image decoding is real I/O that never completes under the fake clock, so
/// the proof PNG is decoded into the image cache before the page is built.
Future<void> _openReview(
  WidgetTester tester,
  _FakeSupervisorBloc bloc,
  PaymentEntity payment, {
  _ProofRepo? proofs,
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await sl.reset();
  sl.registerFactory<DownloadPaymentProofUseCase>(
    () => DownloadPaymentProofUseCase(proofs ?? _ProofRepo()),
  );
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(
    () => precacheImage(MemoryImage(_png), tester.element(find.byType(SizedBox))),
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc()),
        BlocProvider<SupervisorBloc>.value(value: bloc),
      ],
      child: MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => supervisorPaymentReviewPageForTest(payment),
                  ),
                ),
                child: const Text(_home),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_home));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await _settle(tester);
}

final _reviewTitle = find.text('مراجعة إثبات الدفع');

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, _save));

/// Tapping a disabled save must not dispatch a review.
Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text(_save));
  await tester.tap(find.text(_save), warnIfMissed: false);
  await tester.pump();
}

PaymentReviewCommand _restorable() => PaymentReviewCommand(
  paymentId: 'pB',
  decision: PaymentReviewWire.partial,
  notes: 'الدفعة الثانية',
  amountMode: PaymentAmountMode.receipt,
  amountMinorUnits: 3350,
  expectedProofFileName: '1790000000000.jpg',
);

void main() {
  tearDown(() => sl.reset());

  testWidgets('the result of payment A never closes the screen of B', (
    tester,
  ) async {
    final bloc = _FakeSupervisorBloc(SupervisorState.initial());
    await _openReview(tester, bloc, _payment('pB'));

    bloc.emitState(
      bloc.state.copyWith(
        reviewPaymentStatus: SubmissionStatus.submitting,
        reviewPaymentId: 'pA',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(kPaymentReviewBusyMessage), findsOne);
    expect(find.text('جاري الحفظ…'), findsNothing);

    bloc.emitState(
      bloc.state.copyWith(reviewPaymentStatus: SubmissionStatus.success),
    );
    await tester.pumpAndSettle();
    expect(_reviewTitle, findsOne);

    bloc.emitState(
      bloc.state.copyWith(
        reviewPaymentStatus: SubmissionStatus.error,
        reviewPaymentError: kPaymentProofChangedMessage,
      ),
    );
    await tester.pumpAndSettle();
    expect(_reviewTitle, findsOne);
    await bloc.close();
  });

  testWidgets('the screen of B closes on its own success', (tester) async {
    final bloc = _FakeSupervisorBloc(SupervisorState.initial());
    await _openReview(tester, bloc, _payment('pB'));
    bloc.emitState(
      bloc.state.copyWith(
        reviewPaymentStatus: SubmissionStatus.submitting,
        reviewPaymentId: 'pB',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('جاري الحفظ…'), findsOne);
    bloc.emitState(
      bloc.state.copyWith(reviewPaymentStatus: SubmissionStatus.success),
    );
    await tester.pumpAndSettle();
    expect(_reviewTitle, findsNothing);
    await bloc.close();
  });

  testWidgets('"no longer pending" on B closes B for the reloaded list', (
    tester,
  ) async {
    final bloc = _FakeSupervisorBloc(SupervisorState.initial());
    await _openReview(tester, bloc, _payment('pB'));
    bloc.emitState(
      bloc.state.copyWith(
        reviewPaymentStatus: SubmissionStatus.error,
        reviewPaymentId: 'pB',
        reviewPaymentError: kPaymentNoLongerPendingNotice,
      ),
    );
    await tester.pumpAndSettle();
    expect(_reviewTitle, findsNothing);
    await bloc.close();
  });

  testWidgets('saving while another review is in flight is blocked', (
    tester,
  ) async {
    final bloc = _FakeSupervisorBloc(SupervisorState.initial());
    await _openReview(tester, bloc, _payment('pB'));
    bloc.emitState(
      bloc.state.copyWith(
        reviewPaymentStatus: SubmissionStatus.submitting,
        reviewPaymentId: 'pA',
      ),
    );
    await tester.pumpAndSettle();
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'حفظ نتيجة المراجعة'),
    );
    expect(save.onPressed, isNull);
    expect(bloc.events, isEmpty);
    await bloc.close();
  });

  testWidgets('an unresolved command is restored and re-sent unchanged', (
    tester,
  ) async {
    final command = _restorable();
    final bloc = _FakeSupervisorBloc(
      SupervisorState.initial().copyWith(
        reviewPaymentUnresolved: {'pB': command},
      ),
    );
    await _openReview(tester, bloc, _payment('pB'));
    expect(find.byKey(const ValueKey('payment-review-restored')), findsOne);
    expect(find.text('33.50'), findsOne);
    expect(find.text('الدفعة الثانية'), findsOne);

    await tester.ensureVisible(find.text('حفظ نتيجة المراجعة'));
    await tester.tap(find.text('حفظ نتيجة المراجعة'));
    await tester.pump();
    final sent = bloc.events.whereType<ReviewPaymentProofEvent>().single;
    expect(sent.command, command);
    await bloc.close();
  });

  testWidgets('a command bound to an older proof is not restored', (
    tester,
  ) async {
    final command = PaymentReviewCommand(
      paymentId: 'pB',
      decision: PaymentReviewWire.reject,
      expectedProofFileName: '1700000000000.jpg',
    );
    final bloc = _FakeSupervisorBloc(
      SupervisorState.initial().copyWith(
        reviewPaymentUnresolved: {'pB': command},
      ),
    );
    await _openReview(tester, bloc, _payment('pB'));
    expect(find.byKey(const ValueKey('payment-review-restored')), findsNothing);
    await bloc.close();
  });

  _FakeSupervisorBloc restoredBloc() => _FakeSupervisorBloc(
    SupervisorState.initial().copyWith(
      reviewPaymentUnresolved: {'pB': _restorable()},
    ),
  );

  testWidgets('saving stays disabled while the proof image is loading', (
    tester,
  ) async {
    final bloc = restoredBloc();
    final proofs = _ProofRepo()..gate = Completer<void>();
    await _openReview(tester, bloc, _payment('pB'), proofs: proofs);

    expect(proofs.downloads, 1);
    expect(_saveButton(tester).onPressed, isNull);
    expect(find.text(kPaymentProofNotLoadedMessage), findsOne);
    await _tapSave(tester);
    expect(bloc.events, isEmpty);

    proofs.gate!.complete();
    await _settle(tester);
    expect(_saveButton(tester).onPressed, isNotNull);
    expect(find.text(kPaymentProofNotLoadedMessage), findsNothing);
    await bloc.close();
  });

  testWidgets('a failed proof download keeps saving disabled until a retry '
      'succeeds', (tester) async {
    final bloc = restoredBloc();
    final proofs = _ProofRepo()
      ..result = const Left(NetworkFailure('لا يوجد اتصال'));
    await _openReview(tester, bloc, _payment('pB'), proofs: proofs);

    expect(find.text('لا يوجد اتصال'), findsOne);
    expect(_saveButton(tester).onPressed, isNull);
    expect(find.text(kPaymentProofNotLoadedMessage), findsOne);
    await _tapSave(tester);
    expect(bloc.events, isEmpty);

    proofs.result = Right(_png);
    await tester.tap(find.text('إعادة المحاولة'));
    await _settle(tester);
    expect(proofs.downloads, 2);
    expect(_saveButton(tester).onPressed, isNotNull);

    await _tapSave(tester);
    final sent = bloc.events.whereType<ReviewPaymentProofEvent>().single;
    expect(sent.command, _restorable());
    await bloc.close();
  });

  testWidgets('an undecodable proof image keeps saving disabled', (
    tester,
  ) async {
    final bloc = restoredBloc();
    final proofs = _ProofRepo()
      ..result = Right(Uint8List.fromList(const [1, 2, 3, 4]));
    await _openReview(tester, bloc, _payment('pB'), proofs: proofs);
    await _awaitRealDecode(tester);

    expect(find.text('تعذر عرض صورة الإيصال'), findsOne);
    expect(_saveButton(tester).onPressed, isNull);
    await _tapSave(tester);
    expect(bloc.events, isEmpty);
    await bloc.close();
  });

  testWidgets('saving is enabled once the proof image is shown', (
    tester,
  ) async {
    final bloc = restoredBloc();
    await _openReview(tester, bloc, _payment('pB'));
    expect(find.byType(Image), findsOne);
    expect(_saveButton(tester).onPressed, isNotNull);
    expect(find.text(kPaymentProofNotLoadedMessage), findsNothing);
    await bloc.close();
  });
}
