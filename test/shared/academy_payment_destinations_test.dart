import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_billing_usecases.dart';
import 'package:rafiq_academy/shared/data/payment_public_settings_mapper.dart';
import 'package:rafiq_academy/shared/domain/academy_payment_destinations.dart';

import '../helpers/payment_destination_placeholders.dart';

class _Repo extends Fake implements AdminRepository {
  final calls = <({String? vodafoneCash, String? instapay})>[];

  @override
  Future<Either<Failure, Unit>> updatePaymentPublicSettings({
    String? vodafoneCashDestination,
    String? instapayDestination,
  }) async {
    calls.add((
      vodafoneCash: vodafoneCashDestination,
      instapay: instapayDestination,
    ));
    return const Right(unit);
  }
}

void main() {
  const v = AcademyPaymentMethod.vodafoneCash;
  const i = AcademyPaymentMethod.instapay;

  group('Vodafone Cash wallet number', () {
    test('accepts the placeholder and normalises prefixes and digits', () {
      expect(
        AcademyPaymentDestinations.validate(v, kDevPlaceholderVodafoneCash),
        isNull,
      );
      expect(
        AcademyPaymentDestinations.normalizeVodafoneCash('+20 100-000-0000'),
        kDevPlaceholderVodafoneCash,
      );
      expect(
        AcademyPaymentDestinations.normalizeVodafoneCash('٠١٠٠٠٠٠٠٠٠٠'),
        kDevPlaceholderVodafoneCash,
      );
    });

    test(
      'rejects other operators, wrong length, links and InstaPay values',
      () {
        for (final bad in [
          '0110000000',
          '01100000000',
          '0100000000',
          '010000000000',
          kDevPlaceholderInstapayAddress,
          kDevPlaceholderInstapayLink,
        ]) {
          expect(
            AcademyPaymentDestinations.validate(v, bad),
            AcademyPaymentDestinations.vodafoneCashInvalidMessage,
            reason: bad,
          );
        }
      },
    );

    test('empty is required unless clearing', () {
      expect(
        AcademyPaymentDestinations.validate(v, '  '),
        AcademyPaymentDestinations.vodafoneCashRequiredMessage,
      );
      expect(
        AcademyPaymentDestinations.validate(v, '', allowEmpty: true),
        isNull,
      );
    });
  });

  group('InstaPay destination', () {
    test('admin saves accept Egyptian mobile only', () {
      expect(
        AcademyPaymentDestinations.validate(i, kDevPlaceholderInstapayMobile),
        isNull,
      );
      expect(
        AcademyPaymentDestinations.instapayKind(kDevPlaceholderInstapayMobile),
        InstapayDestinationKind.mobile,
      );
    });

    test('legacy address/link still classify for parent display', () {
      expect(
        AcademyPaymentDestinations.instapayKind(kDevPlaceholderInstapayAddress),
        InstapayDestinationKind.address,
      );
      expect(
        AcademyPaymentDestinations.instapayKind('Dev-Placeholder@InstaPay'),
        InstapayDestinationKind.address,
      );
      expect(
        AcademyPaymentDestinations.instapayKind(kDevPlaceholderInstapayLink),
        InstapayDestinationKind.link,
      );
      // New admin writes reject non-mobile values.
      expect(
        AcademyPaymentDestinations.validate(i, kDevPlaceholderInstapayAddress),
        AcademyPaymentDestinations.instapayInvalidMessage,
      );
      expect(
        AcademyPaymentDestinations.validate(i, kDevPlaceholderInstapayLink),
        AcademyPaymentDestinations.instapayInvalidMessage,
      );
    });

    test('rejects insecure, malformed and non-mobile values', () {
      for (final bad in [
        'http://dev-placeholder.invalid/instapay',
        'javascript:alert(1)',
        'https://',
        'https://user:pass@dev-placeholder.invalid/x',
        'https://dev placeholder.invalid',
        'name@gmail.com',
        '@instapay',
        '02xxxxxxx',
        'https://dev-placeholder.invalid/${'a' * 200}',
      ]) {
        expect(
          AcademyPaymentDestinations.validate(i, bad),
          AcademyPaymentDestinations.instapayInvalidMessage,
          reason: bad,
        );
      }
    });

    test('only https links produce a launch URI', () {
      expect(
        AcademyPaymentDestinations.instapayLinkUri(
          kDevPlaceholderInstapayLink,
        )?.scheme,
        'https',
      );
      expect(
        AcademyPaymentDestinations.instapayLinkUri(
          kDevPlaceholderInstapayAddress,
        ),
        isNull,
      );
    });
  });

  group('paymentPublic mapping', () {
    test('reads both fields independently and ignores non-strings', () {
      final s = paymentPublicSettingsFromData({
        'vodafoneCashDestination': ' $kDevPlaceholderVodafoneCash ',
        'instapayDestination': 42,
      });
      expect(s.vodafoneCashDestination, kDevPlaceholderVodafoneCash);
      expect(s.instapayDestination, '');
      expect(s.hasVodafoneCash, isTrue);
      expect(s.hasInstapay, isFalse);
      expect(paymentPublicSettingsFromData(null).hasDestination, isFalse);
    });
  });

  group('UpdatePaymentPublicSettingsUseCase', () {
    test('saving one method never writes the other', () async {
      final repo = _Repo();
      final useCase = UpdatePaymentPublicSettingsUseCase(repo);

      await useCase(
        const UpdatePaymentPublicParams(
          method: AcademyPaymentMethod.vodafoneCash,
          value: '+201000000000',
        ),
      );
      await useCase(
        const UpdatePaymentPublicParams(
          method: AcademyPaymentMethod.instapay,
          value: kDevPlaceholderInstapayMobile,
        ),
      );

      expect(repo.calls, [
        (vodafoneCash: kDevPlaceholderVodafoneCash, instapay: null),
        (vodafoneCash: null, instapay: kDevPlaceholderInstapayMobile),
      ]);
    });

    test('invalid values are rejected before any write', () async {
      final repo = _Repo();
      final result = await UpdatePaymentPublicSettingsUseCase(repo)(
        const UpdatePaymentPublicParams(
          method: AcademyPaymentMethod.instapay,
          value: 'http://dev-placeholder.invalid',
        ),
      );
      expect(
        result,
        const Left<Failure, Unit>(
          ValidationFailure(AcademyPaymentDestinations.instapayInvalidMessage),
        ),
      );
      expect(repo.calls, isEmpty);
    });

    test('an empty value clears only that method', () async {
      final repo = _Repo();
      await UpdatePaymentPublicSettingsUseCase(repo)(
        const UpdatePaymentPublicParams(
          method: AcademyPaymentMethod.vodafoneCash,
          value: '  ',
        ),
      );
      expect(repo.calls, [(vodafoneCash: '', instapay: null)]);
    });
  });
}
