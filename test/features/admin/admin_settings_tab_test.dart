import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_settings_tab.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final calls = <(String, String)>[];
  Object? nextError;

  Future<void> changer(String current, String next) async {
    calls.add((current, next));
    final e = nextError;
    if (e != null) throw e;
  }

  setUp(() {
    calls.clear();
    nextError = null;
  });

  Future<void> pump(WidgetTester tester, {String? email}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: _AuthBlocStub(
            AuthAuthenticated(
              UserEntity(
                uid: 'a1',
                name: 'مدير الأكاديمية',
                role: 'admin',
                email: email,
                isActive: true,
                createdAt: DateTime(2026),
              ),
            ),
          ),
          child: AdminSettingsTab(changePassword: changer),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('login identifier shows the username for internal addresses', () {
    expect(
      loginIdentifierLabel('admin01@members.rafiq-academy.invalid'),
      'اسم الدخول: admin01',
    );
    expect(loginIdentifierLabel('owner@example.com'), 'البريد: owner@example.com');
    expect(loginIdentifierLabel(null), isNull);
  });

  testWidgets('settings lists real destinations, no unenforced policy', (
    tester,
  ) async {
    await pump(tester, email: 'admin01@members.rafiq-academy.invalid');
    expect(find.text('اسم الدخول: admin01'), findsOneWidget);
    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
    expect(find.text('وسائل الدفع'), findsOneWidget);
    expect(find.text('إعادة تفعيل الوصول'), findsOneWidget);
    expect(find.text('استيراد بيانات الأكاديمية'), findsOneWidget);
    expect(find.text('إعدادات التواصل'), findsNothing);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('password change validates, shows a refusal, then succeeds', (
    tester,
  ) async {
    await pump(tester, email: 'owner@example.com');
    await tester.tap(find.byKey(const Key('settings-change-password')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('password-current')), 'old12345');
    await tester.enterText(find.byKey(const Key('password-new')), 'short');
    await tester.enterText(find.byKey(const Key('password-confirm')), 'short');
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(find.text('كلمة المرور يجب أن تكون 8 أحرف على الأقل'), findsOneWidget);
    expect(calls, isEmpty);

    await tester.enterText(find.byKey(const Key('password-new')), 'newpass2026');
    await tester.enterText(find.byKey(const Key('password-confirm')), 'newpass2027');
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    expect(calls, isEmpty);

    nextError = const ServerException('كلمة المرور الحالية غير صحيحة');
    await tester.enterText(find.byKey(const Key('password-confirm')), 'newpass2026');
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('password-error')), findsOneWidget);
    expect(find.text('كلمة المرور الحالية غير صحيحة'), findsOneWidget);
    expect(calls, [('old12345', 'newpass2026')]);

    nextError = null;
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(find.byKey(const Key('password-current')), findsNothing);
    expect(find.text('تم تغيير كلمة المرور'), findsOneWidget);
  });
}
