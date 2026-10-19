import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/app_update/presentation/bloc/client_version_gate_bloc.dart';
import 'package:rafiq_academy/features/app_update/presentation/version_gate_session.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';

const _checking = ClientVersionGateState();
const _allowed = ClientVersionGateState(
  status: ClientVersionGateStatus.allowed,
);
const _blocked = ClientVersionGateState(
  status: ClientVersionGateStatus.updateRequired,
);
const _blockedRechecking = ClientVersionGateState(
  status: ClientVersionGateStatus.updateRequired,
  isRechecking: true,
);
const _allowedRechecking = ClientVersionGateState(
  status: ClientVersionGateStatus.allowed,
  isRechecking: true,
);

class _FakeGate extends Fake implements ClientVersionGateBloc {
  final _controller = StreamController<ClientVersionGateState>.broadcast();

  @override
  ClientVersionGateState state = _checking;

  @override
  Stream<ClientVersionGateState> get stream => _controller.stream;

  void push(ClientVersionGateState next) {
    state = next;
    _controller.add(next);
  }

  @override
  Future<void> close() => _controller.close();
}

class _FakeAuth extends Fake implements AuthBloc {
  _FakeAuth(this.state);

  @override
  AuthState state;

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() async {}
}

class _FakeUser extends Fake implements UserEntity {}

void main() {
  group('AuthStartAfterGate', () {
    test('checking and update-required never start auth', () {
      var starts = 0;
      final gate = AuthStartAfterGate(() => starts++);
      gate
        ..onGateState(_checking)
        ..onGateState(_blocked)
        ..onGateState(_blockedRechecking);
      expect(starts, 0);
    });

    test('the first allowed result starts auth exactly once', () {
      var starts = 0;
      final gate = AuthStartAfterGate(() => starts++);
      gate.onGateState(_allowed);
      expect(starts, 1);
      gate
        ..onGateState(_allowedRechecking)
        ..onGateState(_allowed)
        ..onGateState(_blocked)
        ..onGateState(_allowed);
      expect(starts, 1);
    });

    test('allowed after an initial block starts auth once', () {
      var starts = 0;
      final gate = AuthStartAfterGate(() => starts++);
      gate
        ..onGateState(_blocked)
        ..onGateState(_allowed)
        ..onGateState(_allowed);
      expect(starts, 1);
    });
  });

  group('blocksAllowedSession', () {
    test('only allowed to update-required while signed in', () {
      expect(
        blocksAllowedSession(
          previous: _allowed,
          current: _blocked,
          signedIn: true,
        ),
        isTrue,
      );
      expect(
        blocksAllowedSession(
          previous: _allowedRechecking,
          current: _blocked,
          signedIn: true,
        ),
        isTrue,
        reason: 'on resume a re-check emission precedes the block result',
      );
      expect(
        blocksAllowedSession(
          previous: _allowed,
          current: _blocked,
          signedIn: false,
        ),
        isFalse,
      );
      expect(
        blocksAllowedSession(
          previous: _checking,
          current: _blocked,
          signedIn: true,
        ),
        isFalse,
        reason: 'cold-start block: no session was restored',
      );
      expect(
        blocksAllowedSession(
          previous: _blocked,
          current: _blockedRechecking,
          signedIn: true,
        ),
        isFalse,
      );
      expect(
        blocksAllowedSession(
          previous: _blockedRechecking,
          current: _blocked,
          signedIn: true,
        ),
        isFalse,
      );
    });
  });

  group('VersionGateSessionGuard', () {
    Future<({_FakeGate gate, List<int> cleared})> pump(
      WidgetTester tester,
      AuthState auth,
    ) async {
      final gate = _FakeGate();
      final cleared = <int>[];
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: _FakeAuth(auth)),
            BlocProvider<ClientVersionGateBloc>.value(value: gate),
          ],
          child: VersionGateSessionGuard(
            onBlocked: (_) => cleared.add(1),
            child: const SizedBox.shrink(),
          ),
        ),
      );
      return (gate: gate, cleared: cleared);
    }

    Future<void> emit(
      WidgetTester tester,
      _FakeGate gate,
      ClientVersionGateState state,
    ) async {
      gate.push(state);
      await tester.pump();
    }

    testWidgets('clears once when a signed-in session becomes blocked on '
        'resume, and again only after being allowed', (tester) async {
      final (:gate, :cleared) = await pump(
        tester,
        AuthAuthenticated(_FakeUser()),
      );
      await emit(tester, gate, _allowed);
      expect(cleared, isEmpty);

      // Resume re-check: allowed (rechecking) -> allowed -> rechecking -> blocked.
      await emit(tester, gate, _allowedRechecking);
      await emit(tester, gate, _allowed);
      expect(cleared, isEmpty);

      await emit(tester, gate, _allowedRechecking);
      await emit(tester, gate, _blocked);
      // A rechecking emission precedes the result, so the block is seen as
      // allowedRechecking -> blocked; the guard must still fire.
      expect(cleared, hasLength(1));

      await emit(tester, gate, _blockedRechecking);
      await emit(tester, gate, _blocked);
      expect(cleared, hasLength(1), reason: 'no repeat while blocked');

      await emit(tester, gate, _blockedRechecking);
      await emit(tester, gate, _allowed);
      expect(cleared, hasLength(1));

      await emit(tester, gate, _allowedRechecking);
      await emit(tester, gate, _blocked);
      expect(cleared, hasLength(2));
    });

    testWidgets('cold-start block does not clear', (tester) async {
      final (:gate, :cleared) = await pump(tester, const AuthInitial());
      await emit(tester, gate, _blocked);
      expect(cleared, isEmpty);
    });

    testWidgets('signed-out session does not clear', (tester) async {
      final (:gate, :cleared) = await pump(tester, const AuthUnauthenticated());
      await emit(tester, gate, _allowed);
      await emit(tester, gate, _allowedRechecking);
      await emit(tester, gate, _blocked);
      expect(cleared, isEmpty);
    });
  });
}
