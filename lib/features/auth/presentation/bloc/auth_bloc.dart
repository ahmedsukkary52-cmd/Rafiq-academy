import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../domain/auth_error_messages.dart';
import '../../domain/services/sign_out_preparation.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_with_email_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/watch_auth_session_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

@singleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginWithEmailUseCase loginWithEmail;
  final LogoutUseCase logout;
  final GetCurrentUserUseCase getCurrentUser;
  final WatchAuthSessionUseCase watchSession;

  StreamSubscription<String?>? _sessionSub;
  bool _loggingOut = false;
  SignOutPreparation _signOutPreparation;

  AuthBloc({
    required this.loginWithEmail,
    required this.logout,
    required this.getCurrentUser,
    required this.watchSession,
    @ignoreParam
    SignOutPreparation signOutPreparation = const NoSignOutPreparation(),
  }) : _signOutPreparation = signOutPreparation,
       super(const AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginWithEmailEvent>(_onLoginWithEmail);
    on<LogoutEvent>(_onLogout, transformer: droppable());
    on<SessionEndedEvent>(_onSessionEnded);
    _sessionSub = watchSession().listen((uid) {
      if (uid == null && !_loggingOut && state is AuthAuthenticated) {
        add(const SessionEndedEvent());
      }
    });
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await getCurrentUser(const NoParams());
    result.fold(
      (failure) => emit(_startupStateFor(failure)),
      (user) => emit(
        user == null ? const AuthUnauthenticated() : AuthAuthenticated(user),
      ),
    );
  }

  /// Connectivity problems are retryable on Splash; anything else about the
  /// account fails closed to the login page with an explanation.
  AuthState _startupStateFor(Failure failure) {
    final retryable =
        failure is NetworkFailure ||
        failure is ServerFailure ||
        (failure is AuthFailure && failure.reason == AuthErrorReason.network);
    if (retryable) return AuthStartupFailure(failure.message);
    return AuthUnauthenticated(message: failure.message);
  }

  Future<void> _onLoginWithEmail(
    LoginWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await loginWithEmail(
      LoginParams(email: event.email, password: event.password),
    );
    result.fold(
      (failure) => emit(
        AuthError(
          failure.message,
          reason: switch (failure) {
            AuthFailure(:final reason) => reason,
            NetworkFailure() => AuthErrorReason.network,
            _ => AuthErrorReason.generic,
          },
        ),
      ),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// The generated DI config is frozen (OA-56), so the composition root
  /// attaches the push revocation instead of the constructor receiving it.
  void attachSignOutPreparation(SignOutPreparation preparation) {
    _signOutPreparation = preparation;
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    final current = state;
    _loggingOut = true;
    final revocation = await _prepareSignOut();
    final result = await logout(const NoParams());
    _loggingOut = false;
    result.fold(
      (failure) {
        if (current is AuthAuthenticated) {
          unawaited(_signOutPreparation.signOutAborted(current.user.uid));
          emit(AuthLogoutFailure(current.user, failure.message));
        } else {
          emit(const AuthUnauthenticated());
        }
      },
      (_) => emit(
        AuthUnauthenticated(
          message: revocation == DeviceRevocation.unconfirmed
              ? AuthErrorMessages.pushRevocationUnconfirmed
              : null,
        ),
      ),
    );
  }

  /// Logout is never blocked by push revocation; an error is reported to the
  /// user as unconfirmed rather than thrown out of the handler.
  Future<DeviceRevocation> _prepareSignOut() async {
    try {
      return await _signOutPreparation.beforeSignOut();
    } catch (_) {
      return DeviceRevocation.unconfirmed;
    }
  }

  void _onSessionEnded(SessionEndedEvent event, Emitter<AuthState> emit) {
    if (_loggingOut || state is! AuthAuthenticated) return;
    emit(const AuthUnauthenticated(message: AuthErrorMessages.sessionEnded));
  }

  @override
  Future<void> close() {
    _sessionSub?.cancel();
    return super.close();
  }
}
