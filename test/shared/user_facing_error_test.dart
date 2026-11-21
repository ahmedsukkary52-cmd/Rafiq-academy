import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/error/user_facing_error.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

void main() {
  test('Firebase error codes map to short Arabic sentences', () {
    expect(
      userFacingErrorText(
        '[cloud_firestore/permission-denied] The caller does not have '
        'permission to execute the specified operation.',
      ),
      permissionDeniedErrorText,
    );
    expect(
      userFacingErrorText('[cloud_firestore/unavailable] The service is down'),
      connectionErrorText,
    );
    expect(
      userFacingErrorText('[firebase_functions/unauthenticated] no token'),
      signedOutErrorText,
    );
    expect(
      userFacingErrorText('[firebase_storage/object-not-found] gs://x/y'),
      notFoundErrorText,
    );
    expect(
      userFacingErrorText(
        '[cloud_firestore/failed-precondition] The query requires an index.',
      ),
      missingIndexErrorText,
    );
    expect(
      userFacingErrorText('[firebase_functions/failed-precondition] index'),
      genericErrorText,
    );
  });

  test('other technical text never reaches the user', () {
    expect(
      userFacingErrorText("Bad state: field 'x' does not exist"),
      genericErrorText,
    );
    expect(userFacingErrorText("Instance of 'Foo'"), genericErrorText);
    expect(
      userFacingErrorText('SocketException: Failed host lookup'),
      connectionErrorText,
    );
    expect(userFacingErrorText('   '), genericErrorText);
  });

  test('callable errors keep the backend-authored Arabic message', () {
    expect(
      userFacingErrorText(
        '[firebase_functions/failed-precondition] لا يمكن اعتماد دفعة مرفوضة',
      ),
      'لا يمكن اعتماد دفعة مرفوضة',
    );
  });

  test('ServerFailure exposes the user-facing text, not the raw wrap', () {
    const failure = ServerFailure(
      '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
    );
    expect(failure.message, permissionDeniedErrorText);
    expect(const ServerFailure('تعذر الحفظ').message, 'تعذر الحفظ');
  });

  test('user-facing copy keeps its wording', () {
    expect(userFacingErrorText('تعذر تحميل البيانات'), 'تعذر تحميل البيانات');
    expect(
      userFacingErrorText('Exception: لا يمكن حذف حلقة بها طلاب'),
      'لا يمكن حذف حلقة بها طلاب',
    );
    expect(userFacingErrorText('boom'), 'boom');
  });

  testWidgets('AppErrorWidget shows the translated message, not the raw one', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppErrorWidget(
            message: '[cloud_firestore/permission-denied] Missing permissions',
          ),
        ),
      ),
    );
    expect(find.text(permissionDeniedErrorText), findsOneWidget);
    expect(find.textContaining('cloud_firestore'), findsNothing);
  });
}
