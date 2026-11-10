import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/shared/domain/payment_proof_reader.dart';
import 'package:rafiq_academy/shared/widgets/payment_proof_image.dart';

/// 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Waits, in real time, for the decode the widget started for [bytes]: the
/// precache joins the same in-flight image stream and settles with it.
Future<void> _awaitDecode(WidgetTester tester, Uint8List bytes) async {
  await tester.runAsync(
    () => precacheImage(
      MemoryImage(bytes),
      tester.element(find.byType(Scaffold)),
      onError: (_, __) {},
    ),
  );
}

void main() {
  setUp(() {
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  testWidgets('loaded is reported only after a frame was decoded and shown', (
    tester,
  ) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      _host(
        PaymentProofImage(
          parentId: 'par1',
          paymentId: 'pay1',
          storagePath: 'payment_proofs/par1/pay1/1.png',
          loader: (_) async => Right(_png),
          onLoadedChanged: reports.add,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Bytes are downloaded and the Image is built, but nothing is decoded.
    expect(find.byType(Image), findsOneWidget);
    expect(reports, isEmpty);

    await _awaitDecode(tester, _png);
    expect(reports, isEmpty, reason: 'decoded but not yet painted');

    // The frame that paints the decoded image reports at its end.
    await tester.pump();
    expect(reports, [true]);
    await tester.pump();
    expect(reports, [true]);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
  });

  testWidgets('an undecodable image is never reported as loaded', (
    tester,
  ) async {
    final broken = Uint8List.fromList(const [1, 2, 3, 4]);
    final reports = <bool>[];
    await tester.pumpWidget(
      _host(
        PaymentProofImage(
          parentId: 'par1',
          paymentId: 'pay1',
          storagePath: 'payment_proofs/par1/pay1/1.png',
          loader: (_) async => Right(broken),
          onLoadedChanged: reports.add,
        ),
      ),
    );
    await tester.pump();
    await _awaitDecode(tester, broken);
    await tester.pump();
    await tester.pump();

    expect(find.text('تعذر عرض صورة الإيصال'), findsOneWidget);
    expect(reports, isNot(contains(true)));
  });

  testWidgets('a decode failure after a loaded proof reports unavailable', (
    tester,
  ) async {
    final broken = Uint8List.fromList(const [1, 2, 3, 4]);
    final reports = <bool>[];
    Widget proof(String path, Uint8List bytes) => _host(
      PaymentProofImage(
        parentId: 'par1',
        paymentId: 'pay1',
        storagePath: path,
        loader: (_) async => Right(bytes),
        onLoadedChanged: reports.add,
      ),
    );

    await tester.pumpWidget(proof('payment_proofs/par1/pay1/1.png', _png));
    await tester.pump();
    await _awaitDecode(tester, _png);
    await tester.pump();
    await tester.pump();
    expect(reports, [true]);

    await tester.pumpWidget(proof('payment_proofs/par1/pay1/2.png', broken));
    // The previous proof's image is never kept on screen for the new path.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(reports, [true, false]);

    await tester.pump();
    await _awaitDecode(tester, broken);
    await tester.pump();
    await tester.pump();
    expect(find.text('تعذر عرض صورة الإيصال'), findsOneWidget);
    expect(reports, [true, false]);
  });
  testWidgets('trusted proof path renders the downloaded bytes', (
    tester,
  ) async {
    final calls = <DownloadPaymentProofParams>[];
    await tester.pumpWidget(
      _host(
        PaymentProofImage(
          parentId: 'par1',
          paymentId: 'pay1',
          storagePath: 'payment_proofs/par1/pay1/1.png',
          loader: (p) async {
            calls.add(p);
            return Right(_png);
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(calls.single.storagePath, 'payment_proofs/par1/pay1/1.png');
    expect(calls.single.parentId, 'par1');
    expect(calls.single.paymentId, 'pay1');
  });

  testWidgets('invalid / legacy metadata fails closed without retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PaymentProofImage(
          parentId: 'par1',
          paymentId: 'pay1',
          storagePath: 'https://evil.example/proof.jpg',
          loader: (_) async => const Left(
            ValidationFailure(
              'صورة الإيصال غير متاحة. اطلب من ولي الأمر إعادة رفعها',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('غير متاحة'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });

  testWidgets('transient failure shows a recoverable error with retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _host(
        PaymentProofImage(
          parentId: 'par1',
          paymentId: 'pay1',
          storagePath: 'payment_proofs/par1/pay1/1.png',
          loader: (_) async {
            attempts++;
            return attempts == 1
                ? const Left(NetworkFailure('لا يوجد اتصال'))
                : Right(_png);
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('لا يوجد اتصال'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
    expect(find.byType(Image), findsOneWidget);
  });
}
