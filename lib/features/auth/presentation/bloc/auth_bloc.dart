import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecases.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_with_email_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_with_email_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

@singleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginWithEmailUseCase loginWithEmail;
  final RegisterWithEmailUseCase registerWithEmail;
  final LogoutUseCase logout;
  final GetCurrentUserUseCase getCurrentUser;

  AuthBloc({
    required this.loginWithEmail,
    required this.registerWithEmail,
    required this.logout,
    required this.getCurrentUser,
  }) : super(const AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginWithEmailEvent>(_onLoginWithEmail);
    on<RegisterWithEmailEvent>(_onRegisterWithEmail);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await getCurrentUser(const NoParams());

    result.fold((failure) => emit(const AuthUnauthenticated()), (user) {
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    });
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
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    final result = await logout(const NoParams());

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(const AuthUnauthenticated()),
    );
  }

  Future<void> _onRegisterWithEmail(
    RegisterWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await registerWithEmail(
      RegisterParams(
        email: event.email,
        password: event.password,
        name: event.name,
        phone: event.phone,
        role: event.role,
      ),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }
}
