import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WA-18 — Quarantine wallet / Paymob client surface / supervisorProfiles.
void main() {
  group('WA-18 Paymob Flutter client surface removed', () {
    test('PaymentInitiationEntity and accept.paymob.com absent from lib', () {
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        for (final needle in [
          'PaymentInitiationEntity',
          'InitiatePayment',
          'initiatePayment',
          'accept.paymob.com',
        ]) {
          if (text.contains(needle)) {
            hits.add('${entity.path}: $needle');
          }
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('initiatePayment usecase file deleted', () {
      expect(
        File(
          'lib/features/parent/domain/usecases/initiate_payment_usecase.dart',
        ).existsSync(),
        isFalse,
      );
    });
  });

  group('WA-18 wallet Parent UX removed', () {
    test('wallet domain/usecase files deleted', () {
      expect(
        File('lib/features/parent/domain/parent_wallet.dart').existsSync(),
        isFalse,
      );
      expect(
        File(
          'lib/features/parent/domain/usecases/get_wallet_usecase.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          'lib/features/parent/domain/usecases/pay_payment_from_wallet_usecase.dart',
        ).existsSync(),
        isFalse,
      );
    });

    test('Parent subscriptions page has no wallet balance/pay path', () {
      final page = File(
        'lib/features/parent/presentation/pages/parent_subscriptions_page.dart',
      ).readAsStringSync();
      expect(page.contains('LoadWalletEvent'), isFalse);
      expect(page.contains('PayPaymentFromWalletEvent'), isFalse);
      expect(page.contains('رصيد المحفظة'), isFalse);
      expect(page.contains('ParentWalletContract'), isFalse);
      expect(page.contains('walletBalance'), isFalse);
    });

    test('ParentBloc has no wallet/Paymob handlers', () {
      final bloc = File(
        'lib/features/parent/presentation/bloc/parent_bloc.dart',
      ).readAsStringSync();
      expect(bloc.contains('getWallet'), isFalse);
      expect(bloc.contains('payFromWallet'), isFalse);
      expect(bloc.contains('initiatePayment'), isFalse);
      expect(bloc.contains('LoadWalletEvent'), isFalse);
      expect(bloc.contains('InitiatePaymentEvent'), isFalse);
    });

    test('no client path sets payments status paid via wallet', () {
      final ds = File(
        'lib/features/parent/data/data_source/parent_remote_datasource_impl.dart',
      ).readAsStringSync();
      expect(ds.contains("status': 'paid'"), isFalse);
      expect(ds.contains('payPaymentFromWallet'), isFalse);
      expect(ds.contains('getWallet'), isFalse);
    });
  });

  group('WA-18 supervisorProfiles app dependency', () {
    test('FirestoreCollections.supervisorProfiles constant removed', () {
      final constants = File(
        'lib/core/constants/app_constants.dart',
      ).readAsStringSync();
      expect(constants.contains('supervisorProfiles'), isFalse);
      expect(constants.contains("wallets = 'wallets'"), isFalse);
    });

    test('no Dart collection reads of supervisorProfiles under lib/', () {
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        if (text.contains('supervisorProfiles')) {
          hits.add(entity.path);
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
