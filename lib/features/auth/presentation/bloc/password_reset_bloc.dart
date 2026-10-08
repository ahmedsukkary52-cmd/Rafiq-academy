import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/send_password_reset_usecase.dart';

sealed class PasswordResetEvent extends Equatable {
  const PasswordResetEvent();

  @override
  List<Object?> get props => [];
}

class PasswordResetRequested extends PasswordResetEvent {
  final String email;

  const PasswordResetRequested(this.email);

  @override
  List<Object?> get props => [email];
}

/// Back from the success/failure view to edit the address.
class PasswordResetEditRequested extends PasswordResetEvent {
  const PasswordResetEditRequested();
}

sealed class PasswordResetState extends Equatable {
  const PasswordResetState();

  @override
  List<Object?> get props => [];
}

class PasswordResetIdle extends PasswordResetState {
  const PasswordResetIdle();
}

class PasswordResetSubmitting extends PasswordResetState {
  final String email;

  const PasswordResetSubmitting(this.email);

  @override
  List<Object?> get props => [email];
}

class PasswordResetEmailSent extends PasswordResetState {
  final String email;

  const PasswordResetEmailSent(this.email);

  @override
  List<Object?> get props => [email];
}

class PasswordResetFailure extends PasswordResetState {
  final String email;
  final String message;
  final bool retryable;

  const PasswordResetFailure({
    required this.email,
    required this.message,
    required this.retryable,
  });

  @override
  List<Object?> get props => [email, message, retryable];
}

/// Forgot-password flow. Separate from [AuthBloc] so its states never drive
/// the router's auth redirects.
@injectable
class PasswordResetBloc extends Bloc<PasswordResetEvent, PasswordResetState> {
  final SendPasswordResetUseCase sendPasswordReset;

  PasswordResetBloc({required this.sendPasswordReset})
    : super(const PasswordResetIdle()) {
    on<PasswordResetRequested>(_onRequested);
    on<PasswordResetEditRequested>(
      (_, emit) => emit(const PasswordResetIdle()),
    );
  }

  Future<void> _onRequested(
    PasswordResetRequested event,
    Emitter<PasswordResetState> emit,
  ) async {
    if (state is PasswordResetSubmitting) return;
    final email = event.email.trim();
    emit(PasswordResetSubmitting(email));
    final result = await sendPasswordReset(email);
    result.fold(
      (failure) => emit(
        PasswordResetFailure(
          email: email,
          message: failure.message,
          retryable:
              failure is NetworkFailure ||
              (failure is AuthFailure &&
                  (failure.reason == AuthErrorReason.network ||
                      failure.reason == AuthErrorReason.tooManyRequests)),
        ),
      ),
      (_) => emit(PasswordResetEmailSent(email)),
    );
  }
}
