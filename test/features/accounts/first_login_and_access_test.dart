import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/accounts/domain/onboarding_models.dart';
import 'package:rafiq_academy/features/accounts/presentation/admin_account_access_card.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/auth/presentation/pages/first_login_page.dart';

class _RecordingAuthBloc extends Fake implements AuthBloc {
  _RecordingAuthBloc(this._state);

  final AuthState _state;
  final events = <AuthEvent>[];
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  bool get isClosed => false;

  @override
  void add(AuthEvent event) => events.add(event);

  @override
  Future<void> close() => _controller.close();
}

Widget _app(Widget child, {AuthBloc? auth}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: auth == null
        ? Scaffold(body: SingleChildScrollView(child: child))
        : BlocProvider<AuthBloc>.value(value: auth, child: child),
  ),
);

void main() {
  group('first-login password policy', () {
    test('mirrors the server rules', () {
      expect(firstLoginPasswordProblem('abc12'), isNotNull);
      expect(firstLoginPasswordProblem('abcdefgh'), isNotNull);
      expect(firstLoginPasswordProblem('12345678'), isNotNull);
      expect(firstLoginPasswordProblem('abcd1234'), isNull);
      expect(firstLoginPasswordProblem('سلام1234'), isNull);
    });
  });

  group('FirstLoginPage', () {
    late _RecordingAuthBloc auth;

    setUp(() {
      auth = _RecordingAuthBloc(
        AuthAuthenticated(
          UserEntity(
            uid: 's1',
            name: 'عمر',
            role: 'student',
            email: 'st000001@members.rafiq-academy.invalid',
            isActive: true,
            createdAt: DateTime(2026),
            mustChangePassword: true,
          ),
        ),
      );
    });

    testWidgets('validates, submits, then signs in again with the new password', (
      tester,
    ) async {
      final submitted = <String>[];
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          FirstLoginPage(submit: (p) async => submitted.add(p)),
          auth: auth,
        ),
      );

      await tester.enterText(find.byKey(const Key('first-login-password')), 'short');
      await tester.ensureVisible(find.text('حفظ ومتابعة'));
      await tester.tap(find.text('حفظ ومتابعة'));
      await tester.pump();
      expect(find.text('كلمة المرور يجب أن تكون 8 أحرف على الأقل'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('first-login-password')),
        'NewPass2026',
      );
      await tester.enterText(find.byKey(const Key('first-login-confirm')), 'Other2026');
      await tester.ensureVisible(find.text('حفظ ومتابعة'));
      await tester.tap(find.text('حفظ ومتابعة'));
      await tester.pump();
      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
      expect(submitted, isEmpty);

      await tester.enterText(
        find.byKey(const Key('first-login-confirm')),
        'NewPass2026',
      );
      await tester.ensureVisible(find.text('حفظ ومتابعة'));
      await tester.tap(find.text('حفظ ومتابعة'));
      await tester.pumpAndSettle();
      expect(submitted, ['NewPass2026']);
      expect(auth.events, [
        const LoginWithEmailEvent(
          email: 'st000001@members.rafiq-academy.invalid',
          password: 'NewPass2026',
        ),
      ]);
    });

    testWidgets('a newly provisioned Admin signs in again with the Auth email '
        'after the change', (tester) async {
      final admin = _RecordingAuthBloc(
        AuthAuthenticated(
          UserEntity(
            uid: 'a2',
            name: 'مسؤول جديد',
            role: 'admin',
            email: 'new-admin@academy.test',
            isActive: true,
            createdAt: DateTime(2026),
            mustChangePassword: true,
          ),
        ),
      );
      final submitted = <String>[];
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          FirstLoginPage(submit: (p) async => submitted.add(p)),
          auth: admin,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('first-login-password')),
        'Admin2026x',
      );
      await tester.enterText(
        find.byKey(const Key('first-login-confirm')),
        'Admin2026x',
      );
      await tester.ensureVisible(find.text('حفظ ومتابعة'));
      await tester.tap(find.text('حفظ ومتابعة'));
      await tester.pumpAndSettle();
      expect(submitted, ['Admin2026x']);
      expect(admin.events, [
        const LoginWithEmailEvent(
          email: 'new-admin@academy.test',
          password: 'Admin2026x',
        ),
      ]);
    });

    testWidgets('server rejection is shown and no sign-in happens', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          FirstLoginPage(
            submit: (_) async =>
                throw const ServerException('لا يلزم تغيير كلمة المرور'),
          ),
          auth: auth,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('first-login-password')),
        'NewPass2026',
      );
      await tester.enterText(
        find.byKey(const Key('first-login-confirm')),
        'NewPass2026',
      );
      await tester.ensureVisible(find.text('حفظ ومتابعة'));
      await tester.tap(find.text('حفظ ومتابعة'));
      await tester.pumpAndSettle();
      expect(find.text('لا يلزم تغيير كلمة المرور'), findsOneWidget);
      expect(auth.events, isEmpty);
    });
  });

  group('AdminAccountAccessCard', () {
    testWidgets('issues a temporary password for the student or a linked '
        'parent after confirmation', (tester) async {
      final resets = <String>[];
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          AdminAccountAccessCard(
            studentId: 's1',
            studentName: 'عمر',
            loadParents: (_) async => const [
              MemberSearchHit(uid: 'p1', name: 'حسن'),
            ],
            reset: ({required userId, required name, required role}) async {
              resets.add('$role:$userId');
              return IssuedCredential(
                role: role,
                uid: userId,
                name: name,
                username: 'pr000009',
                temporaryPassword: 'Qw3rTy7uPz',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('حسن'), findsOneWidget);
      expect(find.textContaining('p1'), findsNothing);

      await tester.tap(find.byKey(const Key('reset-password-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(resets, isEmpty);

      await tester.tap(find.byKey(const Key('reset-password-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إصدار'));
      await tester.pumpAndSettle();
      expect(resets, ['parent:p1']);
      expect(find.text('كلمة المرور المؤقتة: Qw3rTy7uPz'), findsOneWidget);
    });
  });
}
