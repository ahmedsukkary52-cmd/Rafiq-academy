import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/auth/domain/auth_error_messages.dart';
import 'package:rafiq_academy/features/auth/domain/repositories/auth_repository.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/send_password_reset_usecase.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/password_reset_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:rafiq_academy/features/auth/presentation/pages/login_page.dart';
import 'package:rafiq_academy/features/auth/presentation/pages/splash_page.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

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

class _ResetRepo implements AuthRepository {
  Either<Failure, Unit> result = const Right(unit);
  final sent = <String>[];

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  }) async {
    sent.add(email);
    return result;
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _app(Widget child, {AuthBloc? auth}) => MaterialApp(
  locale: AppLocaleConfig.locale,
  supportedLocales: AppLocaleConfig.supportedLocales,
  localizationsDelegates: AppLocaleConfig.localizationsDelegates,
  theme: AppTheme.theme,
  home: auth == null ? child : BlocProvider.value(value: auth, child: child),
);

void main() {
  group('LoginPage', () {
    testWidgets('validates input and dispatches login; no register path', (
      tester,
    ) async {
      final bloc = _RecordingAuthBloc(const AuthUnauthenticated());
      await tester.pumpWidget(_app(const LoginPage(), auth: bloc));

      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pump();
      expect(find.text('أدخل البريد الإلكتروني'), findsOneWidget);
      expect(bloc.events, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(0), 'a@x.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pump();
      expect(
        bloc.events.single,
        const LoginWithEmailEvent(email: 'a@x.test', password: 'secret1'),
      );

      expect(find.textContaining('إنشاء حساب'), findsNothing);
      expect(
        find.text('إنشاء الحسابات يتم بواسطة إدارة الأكاديمية فقط'),
        findsOneWidget,
      );
    });

    testWidgets('shows the forced sign-out reason inline', (tester) async {
      final bloc = _RecordingAuthBloc(
        const AuthUnauthenticated(message: AuthErrorMessages.disabled),
      );
      await tester.pumpWidget(_app(const LoginPage(), auth: bloc));
      expect(find.text(AuthErrorMessages.disabled), findsOneWidget);
    });

    testWidgets('network error offers retry; loading disables the form', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const LoginPage(),
          auth: _RecordingAuthBloc(
            const AuthError(
              AuthErrorMessages.network,
              reason: AuthErrorReason.network,
            ),
          ),
        ),
      );
      expect(find.text(AuthErrorMessages.network), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.pumpWidget(
        _app(const LoginPage(), auth: _RecordingAuthBloc(const AuthLoading())),
      );
      final forgot = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'نسيت كلمة المرور؟'),
      );
      expect(forgot.onPressed, isNull);
    });

    testWidgets('forgot-password link opens the recovery route', (
      tester,
    ) async {
      final bloc = _RecordingAuthBloc(const AuthUnauthenticated());
      final router = GoRouter(
        initialLocation: AppRoutes.login,
        routes: [
          GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
          GoRoute(
            path: AppRoutes.forgotPassword,
            builder: (_, __) => const Text('recovery'),
          ),
        ],
      );
      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: bloc,
          child: MaterialApp.router(
            locale: AppLocaleConfig.locale,
            supportedLocales: AppLocaleConfig.supportedLocales,
            localizationsDelegates: AppLocaleConfig.localizationsDelegates,
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('نسيت كلمة المرور؟'));
      await tester.pumpAndSettle();
      expect(find.text('recovery'), findsOneWidget);
    });
  });

  group('ForgotPasswordPage', () {
    testWidgets('sends the reset email and shows the success state', (
      tester,
    ) async {
      final repo = _ResetRepo();
      final bloc = PasswordResetBloc(
        sendPasswordReset: SendPasswordResetUseCase(repo),
      );
      await tester.pumpWidget(_app(ForgotPasswordPage(bloc: bloc)));

      await tester.enterText(find.byType(TextFormField), 'bad');
      await tester.tap(find.text('إرسال رابط الاستعادة'));
      await tester.pump();
      expect(find.text('البريد الإلكتروني غير صالح'), findsOneWidget);
      expect(repo.sent, isEmpty);

      await tester.enterText(find.byType(TextFormField), 'a@x.test');
      await tester.tap(find.text('إرسال رابط الاستعادة'));
      await tester.pumpAndSettle();
      expect(repo.sent, ['a@x.test']);
      expect(
        find.textContaining('افتح الرابط لتعيين كلمة مرور جديدة'),
        findsOneWidget,
      );
      expect(find.text('العودة لتسجيل الدخول'), findsOneWidget);
    });

    testWidgets('network failure shows the error and a retry', (tester) async {
      final repo = _ResetRepo()..result = const Left(NetworkFailure());
      final bloc = PasswordResetBloc(
        sendPasswordReset: SendPasswordResetUseCase(repo),
      );
      await tester.pumpWidget(_app(ForgotPasswordPage(bloc: bloc)));
      await tester.enterText(find.byType(TextFormField), 'a@x.test');
      await tester.tap(find.text('إرسال رابط الاستعادة'));
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });
  });

  group('SplashPage', () {
    testWidgets('startup failure offers retry and another-account sign-in', (
      tester,
    ) async {
      final bloc = _RecordingAuthBloc(
        const AuthStartupFailure('تعذّر الاتصال'),
      );
      await tester.pumpWidget(_app(const SplashPage(), auth: bloc));

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.tap(find.text('تسجيل الدخول بحساب آخر'));
      expect(bloc.events, const [CheckAuthStatusEvent(), LogoutEvent()]);
    });

    testWidgets('restoring shows progress only', (tester) async {
      await tester.pumpWidget(
        _app(const SplashPage(), auth: _RecordingAuthBloc(const AuthLoading())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });
  });
}
