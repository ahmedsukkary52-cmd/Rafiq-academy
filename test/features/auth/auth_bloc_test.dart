import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/auth/domain/auth_error_messages.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/domain/repositories/auth_repository.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/login_with_email_usecase.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/logout_usecase.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/send_password_reset_usecase.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/watch_auth_session_usecase.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/password_reset_bloc.dart';

final _student = UserEntity(
  uid: 'stu1',
  name: 'طالب',
  role: 'student',
  isActive: true,
  createdAt: DateTime(2026),
);

class _ScriptedAuthRepository implements AuthRepository {
  Either<Failure, UserEntity?> current = const Right(null);
  Either<Failure, UserEntity> login = Right(_student);
  Either<Failure, Unit> logoutResult = const Right(unit);
  Either<Failure, Unit> resetResult = const Right(unit);
  final session = StreamController<String?>.broadcast();
  int resetCalls = 0;
  Completer<void>? resetGate;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async => current;

  @override
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  }) async => login;

  @override
  Future<Either<Failure, Unit>> logout() async {
    session.add(null);
    await Future<void>.delayed(Duration.zero);
    return logoutResult;
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  }) async {
    resetCalls++;
    await resetGate?.future;
    return resetResult;
  }

  @override
  Stream<String?> get sessionUidChanges => session.stream;
}

AuthBloc _bloc(_ScriptedAuthRepository repo) => AuthBloc(
  loginWithEmail: LoginWithEmailUseCase(repo),
  logout: LogoutUseCase(repo),
  getCurrentUser: GetCurrentUserUseCase(repo),
  watchSession: WatchAuthSessionUseCase(repo),
);

Future<AuthState> _settle(AuthBloc bloc) async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return bloc.state;
}

void main() {
  late _ScriptedAuthRepository repo;

  setUp(() => repo = _ScriptedAuthRepository());

  group('startup', () {
    test('already authenticated -> AuthAuthenticated', () async {
      repo.current = Right(_student);
      final bloc = _bloc(repo)..add(const CheckAuthStatusEvent());
      expect(await _settle(bloc), AuthAuthenticated(_student));
    });

    test('no session -> AuthUnauthenticated without a message', () async {
      final bloc = _bloc(repo)..add(const CheckAuthStatusEvent());
      expect(await _settle(bloc), const AuthUnauthenticated());
    });

    test(
      'network failure -> retryable startup failure, then retry succeeds',
      () async {
        repo.current = const Left(
          AuthFailure(
            AuthErrorMessages.network,
            reason: AuthErrorReason.network,
          ),
        );
        final bloc = _bloc(repo)..add(const CheckAuthStatusEvent());
        expect(await _settle(bloc), isA<AuthStartupFailure>());

        repo.current = Right(_student);
        bloc.add(const CheckAuthStatusEvent());
        expect(await _settle(bloc), AuthAuthenticated(_student));
      },
    );

    test(
      'disabled / missing profile -> login with the reason (fail closed)',
      () async {
        repo.current = const Left(
          AuthFailure(
            AuthErrorMessages.disabled,
            reason: AuthErrorReason.disabled,
          ),
        );
        final bloc = _bloc(repo)..add(const CheckAuthStatusEvent());
        expect(
          await _settle(bloc),
          const AuthUnauthenticated(message: AuthErrorMessages.disabled),
        );
      },
    );
  });

  group('login / logout', () {
    test('success -> AuthAuthenticated', () async {
      final bloc = _bloc(
        repo,
      )..add(const LoginWithEmailEvent(email: 'a@x.test', password: 'secret1'));
      expect(await _settle(bloc), AuthAuthenticated(_student));
    });

    test('invalid credentials -> AuthError (not retryable)', () async {
      repo.login = const Left(
        AuthFailure(
          AuthErrorMessages.invalidCredentials,
          reason: AuthErrorReason.invalidCredentials,
        ),
      );
      final bloc = _bloc(repo)
        ..add(const LoginWithEmailEvent(email: 'a@x.test', password: 'bad'));
      final state = await _settle(bloc);
      expect(state, isA<AuthError>());
      expect((state as AuthError).isRetryable, isFalse);
    });

    test('offline login -> retryable AuthError', () async {
      repo.login = const Left(NetworkFailure());
      final bloc = _bloc(
        repo,
      )..add(const LoginWithEmailEvent(email: 'a@x.test', password: 'secret1'));
      final state = await _settle(bloc);
      expect((state as AuthError).isRetryable, isTrue);
    });

    test(
      'logout -> AuthUnauthenticated with no "session ended" message',
      () async {
        repo.current = Right(_student);
        final bloc = _bloc(repo)..add(const CheckAuthStatusEvent());
        await _settle(bloc);
        bloc.add(const LogoutEvent());
        expect(await _settle(bloc), const AuthUnauthenticated());
      },
    );

    test('logout failure keeps the session and reports it', () async {
      repo
        ..current = Right(_student)
        ..logoutResult = const Left(
          AuthFailure(AuthErrorMessages.logoutFailed),
        );
      final bloc = _bloc(repo)..add(const CheckAuthStatusEvent());
      await _settle(bloc);
      bloc.add(const LogoutEvent());
      final state = await _settle(bloc);
      expect(state, isA<AuthLogoutFailure>());
      expect((state as AuthLogoutFailure).user, _student);
    });

    test(
      'session ended by Firebase (revoked/expired) -> login with reason',
      () async {
        repo.current = Right(_student);
        final bloc = _bloc(repo)..add(const CheckAuthStatusEvent());
        await _settle(bloc);
        repo.session.add(null);
        expect(
          await _settle(bloc),
          const AuthUnauthenticated(message: AuthErrorMessages.sessionEnded),
        );
      },
    );
  });

  group('password reset', () {
    PasswordResetBloc resetBloc() =>
        PasswordResetBloc(sendPasswordReset: SendPasswordResetUseCase(repo));

    test('success -> email sent state with the trimmed address', () async {
      final bloc = resetBloc()..add(const PasswordResetRequested(' a@x.test '));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state, const PasswordResetEmailSent('a@x.test'));
    });

    test('invalid email -> terminal failure; network -> retryable', () async {
      repo.resetResult = const Left(
        AuthFailure(
          AuthErrorMessages.invalidEmail,
          reason: AuthErrorReason.invalidEmail,
        ),
      );
      final bloc = resetBloc()..add(const PasswordResetRequested('bad'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((bloc.state as PasswordResetFailure).retryable, isFalse);

      repo.resetResult = const Left(NetworkFailure());
      bloc.add(const PasswordResetRequested('a@x.test'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((bloc.state as PasswordResetFailure).retryable, isTrue);
    });

    test('academy usernames and their internal .invalid address never '
        'trigger a reset email; the member is sent to the Admin', () async {
      final bloc = resetBloc();
      for (final input in [
        'st000001@members.rafiq-academy.invalid',
        ' ST000001@Members.Rafiq-Academy.Invalid ',
        'st000001',
      ]) {
        bloc.add(PasswordResetRequested(input));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final state = bloc.state as PasswordResetFailure;
        expect(state.message, kUsernameRecoveryMessage, reason: input);
        expect(state.retryable, isFalse, reason: input);
      }
      expect(repo.resetCalls, 0);
    });

    test('double submit while sending sends only one email', () async {
      repo.resetGate = Completer<void>();
      final bloc = resetBloc()
        ..add(const PasswordResetRequested('a@x.test'))
        ..add(const PasswordResetRequested('a@x.test'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repo.resetGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.resetCalls, 1);
      expect(bloc.state, const PasswordResetEmailSent('a@x.test'));
    });

    test('edit after success returns to the form', () async {
      final bloc = resetBloc()..add(const PasswordResetRequested('a@x.test'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const PasswordResetEditRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state, const PasswordResetIdle());
    });
  });
}
