import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/clear_session_projections.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import 'bloc/client_version_gate_bloc.dart';

/// Defers session restoration (B10): [startAuth] runs once, on the first
/// allowed gate result. Checking and update-required never start it.
class AuthStartAfterGate {
  AuthStartAfterGate(this._startAuth);

  final void Function() _startAuth;
  bool _started = false;

  void onGateState(ClientVersionGateState state) {
    if (_started || state.status != ClientVersionGateStatus.allowed) return;
    _started = true;
    _startAuth();
  }
}

/// Whether a gate transition blocks a session that was allowed and signed in.
/// Re-check emissions while already blocked do not match again.
bool blocksAllowedSession({
  required ClientVersionGateState previous,
  required ClientVersionGateState current,
  required bool signedIn,
}) =>
    signedIn &&
    previous.status == ClientVersionGateStatus.allowed &&
    current.status == ClientVersionGateStatus.updateRequired;

/// Clears session-scoped projections when an allowed signed-in session
/// becomes update-required. The Firebase session and push registration are
/// kept; allowing again reloads data through the role home pages.
class VersionGateSessionGuard extends StatelessWidget {
  final Widget child;
  final void Function(BuildContext context) onBlocked;

  const VersionGateSessionGuard({
    super.key,
    required this.child,
    this.onBlocked = clearSessionProjections,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClientVersionGateBloc, ClientVersionGateState>(
      listenWhen: (previous, current) => blocksAllowedSession(
        previous: previous,
        current: current,
        signedIn: context.read<AuthBloc>().state is AuthAuthenticated,
      ),
      listener: (context, _) => onBlocked(context),
      child: child,
    );
  }
}
