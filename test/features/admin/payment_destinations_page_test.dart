import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/admin/data/payment_destination_errors.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_billing_usecases.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_payment_destinations_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_payment_destinations_page.dart';
import 'package:rafiq_academy/shared/domain/academy_billing_entities.dart';
import 'package:rafiq_academy/shared/domain/academy_payment_destinations.dart';

import '../../helpers/payment_destination_placeholders.dart';

class _Repo extends Fake implements AdminRepository {
  final loads = <Completer<Either<Failure, PaymentPublicSettingsEntity>>>[];
  final writes = <({String? vodafoneCash, String? instapay})>[];
  final saves = <Completer<Either<Failure, Unit>>>[];

  @override
  Future<Either<Failure, PaymentPublicSettingsEntity>>
  getPaymentPublicSettings() {
    final c = Completer<Either<Failure, PaymentPublicSettingsEntity>>();
    loads.add(c);
    return c.future;
  }

  @override
  Future<Either<Failure, Unit>> updatePaymentPublicSettings({
    String? vodafoneCashDestination,
    String? instapayDestination,
  }) {
    writes.add((
      vodafoneCash: vodafoneCashDestination,
      instapay: instapayDestination,
    ));
    final c = Completer<Either<Failure, Unit>>();
    saves.add(c);
    return c.future;
  }
}

AdminPaymentDestinationsBloc _bloc(_Repo r) => AdminPaymentDestinationsBloc(
  getSettings: GetAdminPaymentPublicSettingsUseCase(r),
  updateSettings: UpdatePaymentPublicSettingsUseCase(r),
);

Future<void> _pump(
  WidgetTester tester,
  AdminPaymentDestinationsBloc bloc,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: bloc,
        child: const AdminPaymentDestinationsPage(),
      ),
    ),
  );
  await tester.pump();
}

Finder _k(String key) => find.byKey(Key(key));

Future<void> _close(WidgetTester tester, Bloc<Object?, Object?> bloc) async {
  unawaited(bloc.close());
  await tester.pump();
}

void main() {
  testWidgets('load failure shows Arabic error with retry and no editors', (
    tester,
  ) async {
    final repo = _Repo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    expect(_k('payment-destinations-loading'), findsOneWidget);

    repo.loads.single.complete(
      const Left(ServerFailure(kPaymentDestinationsLoadFailedMessage)),
    );
    await tester.pumpAndSettle();

    expect(_k('payment-destinations-load-error'), findsOneWidget);
    expect(find.text(kPaymentDestinationsLoadFailedMessage), findsOneWidget);
    expect(_k('vodafone-cash-field'), findsNothing);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(repo.loads, hasLength(2));
    repo.loads.last.complete(const Right(PaymentPublicSettingsEntity()));
    await tester.pumpAndSettle();
    expect(_k('vodafone-cash-field'), findsOneWidget);
    await _close(tester, bloc);
  });

  testWidgets('each method shows its own saved value and status', (
    tester,
  ) async {
    final repo = _Repo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    repo.loads.single.complete(
      const Right(
        PaymentPublicSettingsEntity(
          instapayDestination: kDevPlaceholderInstapayAddress,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final vodafone = tester.widget<TextField>(_k('vodafone-cash-field'));
    final instapay = tester.widget<TextField>(_k('instapay-field'));
    expect(vodafone.controller!.text, '');
    expect(instapay.controller!.text, kDevPlaceholderInstapayAddress);
    expect(
      tester.widget<Text>(_k('vodafone-cash-status')).data,
      AdminPaymentDestinationsText.notConfigured,
    );
    expect(
      tester.widget<Text>(_k('instapay-status')).data,
      AdminPaymentDestinationsText.configured,
    );
    await _close(tester, bloc);
  });

  testWidgets('invalid format and missing confirmation block the save', (
    tester,
  ) async {
    final repo = _Repo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    repo.loads.single.complete(const Right(PaymentPublicSettingsEntity()));
    await tester.pumpAndSettle();

    await tester.enterText(_k('vodafone-cash-field'), '0110000000');
    await tester.tap(_k('vodafone-cash-save'));
    await tester.pump();
    expect(
      find.text(AcademyPaymentDestinations.vodafoneCashInvalidMessage),
      findsOneWidget,
    );

    await tester.enterText(
      _k('vodafone-cash-field'),
      kDevPlaceholderVodafoneCash,
    );
    await tester.tap(_k('vodafone-cash-save'));
    await tester.pump();
    expect(
      find.text(AdminPaymentDestinationsText.confirmRequired),
      findsOneWidget,
    );
    expect(repo.writes, isEmpty);
    await _close(tester, bloc);
  });

  testWidgets('saving InstaPay writes only InstaPay and keeps Vodafone Cash', (
    tester,
  ) async {
    final repo = _Repo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    repo.loads.single.complete(
      const Right(
        PaymentPublicSettingsEntity(
          vodafoneCashDestination: kDevPlaceholderVodafoneCash,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_k('instapay-field'), kDevPlaceholderInstapayLink);
    await tester.tap(_k('instapay-confirm'));
    await tester.pump();
    await tester.tap(_k('instapay-save'));
    await tester.pump();

    expect(repo.writes, [
      (vodafoneCash: null, instapay: kDevPlaceholderInstapayLink),
    ]);
    expect(find.text(AdminPaymentDestinationsText.saved), findsNothing);

    repo.saves.single.complete(const Right(unit));
    await tester.pump();
    await tester.pump();
    expect(find.text(AdminPaymentDestinationsText.saved), findsOneWidget);
    expect(
      bloc.state.settings!.vodafoneCashDestination,
      kDevPlaceholderVodafoneCash,
    );
    expect(
      bloc.state.settings!.instapayDestination,
      kDevPlaceholderInstapayLink,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _close(tester, bloc);
  });

  testWidgets('failed save shows the mapped message and keeps the edit', (
    tester,
  ) async {
    final repo = _Repo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    repo.loads.single.complete(const Right(PaymentPublicSettingsEntity()));
    await tester.pumpAndSettle();

    await tester.enterText(
      _k('vodafone-cash-field'),
      kDevPlaceholderVodafoneCash,
    );
    await tester.tap(_k('vodafone-cash-confirm'));
    await tester.pump();
    await tester.tap(_k('vodafone-cash-save'));
    await tester.pump();
    repo.saves.single.complete(
      const Left(ServerFailure(kPaymentDestinationsDeniedMessage)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(kPaymentDestinationsDeniedMessage), findsOneWidget);
    expect(
      tester.widget<TextField>(_k('vodafone-cash-field')).controller!.text,
      kDevPlaceholderVodafoneCash,
    );
    expect(bloc.state.settings!.vodafoneCashDestination, '');
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _close(tester, bloc);
  });

  test('raw Firestore codes never reach the admin', () {
    for (final save in [true, false]) {
      for (final code in ['permission-denied', 'unavailable', 'internal']) {
        expect(
          paymentDestinationsErrorMessage(code, save: save),
          isNot(contains(code)),
        );
      }
    }
  });
}
