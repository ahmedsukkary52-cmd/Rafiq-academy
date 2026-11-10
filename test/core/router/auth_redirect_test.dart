import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/router/app_routes.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';

UserEntity _user(String role) => UserEntity(
  uid: 'u1',
  name: 'x',
  role: role,
  isActive: true,
  createdAt: DateTime(2026),
);

String? _go(AuthState state, String path) =>
    AuthRedirect.resolve(state: state, path: path);

void main() {
  group('unauthenticated (fail closed)', () {
    const states = <AuthState>[
      AuthUnauthenticated(),
      AuthUnauthenticated(message: 'موقوف'),
      AuthError('خطأ'),
    ];

    test('role routes and deep links land on login', () {
      for (final s in states) {
        for (final path in [
          AppRoutes.admin,
          AppRoutes.adminAccess,
          AppRoutes.teacher,
          '/student/chat/abc',
          AppRoutes.splash,
        ]) {
          expect(_go(s, path), AppRoutes.login, reason: '$s $path');
        }
      }
    });

    test('login and forgot-password stay reachable', () {
      for (final s in states) {
        expect(_go(s, AppRoutes.login), isNull);
        expect(_go(s, AppRoutes.forgotPassword), isNull);
      }
    });

    test('public self-registration is unavailable (/register -> login)', () {
      expect(
        _go(const AuthUnauthenticated(), AppRoutes.register),
        AppRoutes.login,
      );
    });
  });

  group('restoring / loading', () {
    test('Initial, Loading and StartupFailure hold Splash', () {
      for (final s in const <AuthState>[
        AuthInitial(),
        AuthLoading(),
        AuthStartupFailure('offline'),
      ]) {
        expect(_go(s, AppRoutes.admin), AppRoutes.splash);
        expect(_go(s, AppRoutes.splash), isNull);
      }
    });

    test('a sign-in in progress keeps the login page', () {
      expect(_go(const AuthLoading(), AppRoutes.login), isNull);
      expect(_go(const AuthLoading(), AppRoutes.forgotPassword), isNull);
    });
  });

  group('authenticated', () {
    test('auth pages send each role to its own home', () {
      for (final (role, home) in [
        ('student', AppRoutes.student),
        ('parent', AppRoutes.parent),
        ('teacher', AppRoutes.teacher),
        ('supervisor', AppRoutes.supervisor),
        ('admin', AppRoutes.admin),
      ]) {
        final s = AuthAuthenticated(_user(role));
        expect(_go(s, AppRoutes.splash), home);
        expect(_go(s, AppRoutes.login), home);
        expect(_go(s, AppRoutes.forgotPassword), home);
        expect(_go(s, AppRoutes.register), home);
      }
    });

    test('wrong-role routes are redirected home', () {
      expect(
        _go(AuthAuthenticated(_user('student')), AppRoutes.adminAccess),
        AppRoutes.student,
      );
      expect(
        _go(AuthAuthenticated(_user('parent')), AppRoutes.teacher),
        AppRoutes.parent,
      );
      expect(
        _go(AuthAuthenticated(_user('teacher')), AppRoutes.adminPayments),
        AppRoutes.teacher,
      );
      expect(_go(AuthAuthenticated(_user('admin')), AppRoutes.admin), isNull);
    });

    test('an unknown role never reaches a role route', () {
      final s = AuthAuthenticated(_user('superadmin'));
      expect(_go(s, AppRoutes.admin), AppRoutes.login);
      expect(_go(s, AppRoutes.login), isNull);
    });

    test('a failed logout keeps role routing', () {
      final s = AuthLogoutFailure(_user('teacher'), 'x');
      expect(_go(s, AppRoutes.teacher), isNull);
      expect(_go(s, AppRoutes.admin), AppRoutes.teacher);
    });
  });
}
