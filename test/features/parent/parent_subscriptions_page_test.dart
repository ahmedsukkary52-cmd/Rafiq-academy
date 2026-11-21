import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_bloc.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_event.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_state.dart';
import 'package:rafiq_academy/features/parent/presentation/pages/parent_subscriptions_page.dart';
import 'package:rafiq_academy/shared/domain/parent_payment_proof.dart';
import 'package:rafiq_academy/shared/domain/payment_entity.dart';
import 'package:rafiq_academy/shared/domain/pricing_rules_contract.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

class _AuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthAuthenticated(
    UserEntity(
      uid: 'parent1',
      name: 'ولي الأمر',
      role: 'parent',
      isActive: true,
      createdAt: DateTime(2026),
    ),
  );

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() => _controller.close();
}

class _ParentBloc extends Fake implements ParentBloc {
  _ParentBloc(this._state);

  ParentState _state;
  final _controller = StreamController<ParentState>.broadcast();
  final events = <ParentEvent>[];

  @override
  ParentState get state => _state;

  @override
  Stream<ParentState> get stream => _controller.stream;

  @override
  void add(ParentEvent event) => events.add(event);

  void emitState(ParentState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> close() => _controller.close();
}

PaymentEntity _payment({
  required String id,
  required PaymentStatus status,
  String studentId = 's1',
  String? reviewStatus,
  String? proofPath,
  DateTime? proofSubmittedAt,
  DateTime? paidAt,
}) {
  final now = DateTime.now();
  final period = PricingRulesContract.periodKeyForDate(now);
  return PaymentEntity(
    id: id,
    studentId: studentId,
    parentId: 'parent1',
    amount: 250,
    dueDate: DateTime(now.year, now.month, 28),
    status: status,
    periodKey: period,
    reviewStatus: reviewStatus,
    proofStoragePath: proofPath,
    proofSubmittedAt: proofSubmittedAt,
    paidAt: paidAt,
  );
}

ParentState _loaded(List<PaymentEntity> payments) {
  return ParentState(
    parentId: 'parent1',
    paymentsStatus: SectionStatus.loaded,
    payments: payments,
    paymentDestinationsStatus: SectionStatus.loaded,
    vodafoneCashDestination: '01012345678',
    instapayDestination: '01098765432',
    childrenSnapshots: const [
      ParentChildSnapshot(studentId: 's1', name: 'أحمد'),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ParentState state,
  _ParentBloc? bloc,
}) async {
  final parent = bloc ?? _ParentBloc(state);
  final auth = _AuthBloc();
  addTearDown(parent.close);
  addTearDown(auth.close);

  await tester.pumpWidget(
    MaterialApp(
      locale: AppLocaleConfig.locale,
      supportedLocales: AppLocaleConfig.supportedLocales,
      localizationsDelegates: AppLocaleConfig.localizationsDelegates,
      theme: AppTheme.theme,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<ParentBloc>.value(value: parent),
        ],
        child: const ParentSubscriptionsPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('error state offers retry and loads payments', (tester) async {
    final parent = _ParentBloc(
      const ParentState(
        paymentsStatus: SectionStatus.error,
        paymentsError: 'تعذر تحميل الاشتراكات',
      ),
    );
    await _pump(tester, state: parent.state, bloc: parent);

    expect(find.byType(AppErrorWidget), findsOneWidget);
    expect(find.textContaining('تعذر تحميل'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(
      parent.events.whereType<LoadPaymentsEvent>(),
      isNotEmpty,
    );
  });

  testWidgets('empty month shows honest no-invoice copy', (tester) async {
    await _pump(tester, state: _loaded(const []));

    expect(find.text('لا فواتير هذا الشهر'), findsOneWidget);
    expect(find.textContaining('لم تُصدر فاتورة'), findsOneWidget);
  });

  testWidgets('due invoice shows student, amount actions, and due badge path', (
    tester,
  ) async {
    await _pump(
      tester,
      state: _loaded([_payment(id: 'pay_due', status: PaymentStatus.due)]),
    );

    expect(find.textContaining('أحمد'), findsWidgets);
    expect(find.text('مستحق'), findsWidgets);
    expect(find.textContaining('رفع إيصال'), findsWidgets);
  });

  testWidgets('proof awaiting review shows pending badge', (tester) async {
    await _pump(
      tester,
      state: _loaded([
        _payment(
          id: 'pay_pending',
          status: PaymentStatus.due,
          reviewStatus: ParentPaymentProofContract.pendingReview,
          proofPath: 'payment_proofs/parent1/pay_pending/a.jpg',
          proofSubmittedAt: DateTime(2026, 11, 10),
        ),
      ]),
    );

    expect(find.text('قيد المراجعة'), findsOneWidget);
    expect(find.textContaining('إثبات مرسل'), findsOneWidget);
  });

  testWidgets('paid invoice shows confirmed badge', (tester) async {
    await _pump(
      tester,
      state: _loaded([
        _payment(
          id: 'pay_paid',
          status: PaymentStatus.paid,
          reviewStatus: ParentPaymentProofContract.approved,
          paidAt: DateTime(2026, 11, 12),
        ),
      ]),
    );

    expect(find.text('مؤكد'), findsOneWidget);
    expect(find.textContaining('مدفوع'), findsWidgets);
  });

  testWidgets('due filter hides paid invoices', (tester) async {
    await _pump(
      tester,
      state: _loaded([
        _payment(id: 'pay_due', status: PaymentStatus.due),
        _payment(
          id: 'pay_paid',
          status: PaymentStatus.paid,
          paidAt: DateTime(2026, 11, 1),
        ),
      ]),
    );

    expect(find.textContaining('أحمد'), findsWidgets);

    await tester.tap(find.text('مدفوع').first);
    await tester.pumpAndSettle();
    expect(find.text('مؤكد'), findsOneWidget);

    await tester.tap(find.text('مستحق'));
    await tester.pumpAndSettle();
    expect(find.text('مؤكد'), findsNothing);
    expect(find.textContaining('أحمد'), findsWidgets);
  });
}
