import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/app_update/domain/client_version_config.dart';
import 'package:rafiq_academy/features/app_update/domain/client_version_repository.dart';
import 'package:rafiq_academy/features/app_update/presentation/bloc/client_version_gate_bloc.dart';

class _ControlledRepository implements ClientVersionRepository {
  final pending = <Completer<ClientVersionLookup>>[];

  @override
  Future<ClientVersionLookup> load() {
    final completer = Completer<ClientVersionLookup>();
    pending.add(completer);
    return completer.future;
  }

  void answer(ClientVersionLookup lookup) => pending.last.complete(lookup);
}

class _ErrorRecordingGate extends ClientVersionGateBloc {
  _ErrorRecordingGate(super.repository, this.errors)
    : super.withBuild(installedBuild: 5);

  final List<Object> errors;

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

ClientVersionLookup _minimum(int build) =>
    ClientVersionFound(ClientVersionConfig(minimumBuildNumber: build));

const _unreachable = ClientVersionUnavailable(
  ClientVersionUnavailableReason.unreachable,
);

class _ThrowingRepository implements ClientVersionRepository {
  int calls = 0;

  @override
  Future<ClientVersionLookup> load() async {
    calls++;
    throw StateError('unexpected');
  }
}

void main() {
  group('repository that throws (contract violation)', () {
    test(
      'fails open instead of staying on checking, and reports the error',
      () async {
        final throwing = _ThrowingRepository();
        final errors = <Object>[];
        final bloc = _ErrorRecordingGate(throwing, errors);
        addTearDown(bloc.close);

        bloc.add(const ClientVersionCheckRequested());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ClientVersionGateStatus.allowed);
        expect(bloc.state.isRechecking, isFalse);
        expect(errors.single, isA<StateError>());

        bloc.add(const ClientVersionCheckRequested());
        await Future<void>.delayed(Duration.zero);
        expect(throwing.calls, 2);
        expect(bloc.state.status, ClientVersionGateStatus.allowed);
      },
    );
  });

  late _ControlledRepository repository;
  late ClientVersionGateBloc bloc;

  setUp(() {
    repository = _ControlledRepository();
    bloc = ClientVersionGateBloc.withBuild(repository, installedBuild: 5);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<ClientVersionGateState> check(ClientVersionLookup lookup) async {
    bloc.add(const ClientVersionCheckRequested());
    await settle();
    repository.answer(lookup);
    await settle();
    return bloc.state;
  }

  test('starts checking', () {
    expect(bloc.state.status, ClientVersionGateStatus.checking);
  });

  test(
    'build below the minimum requires an update and keeps the config',
    () async {
      final state = await check(_minimum(6));
      expect(state.status, ClientVersionGateStatus.updateRequired);
      expect(state.config, const ClientVersionConfig(minimumBuildNumber: 6));
    },
  );

  test('build at or above the minimum is allowed', () async {
    expect((await check(_minimum(5))).status, ClientVersionGateStatus.allowed);
    expect((await check(_minimum(1))).status, ClientVersionGateStatus.allowed);
  });

  test('missing, malformed and unreachable configuration fail open', () async {
    for (final reason in ClientVersionUnavailableReason.values) {
      final state = await check(ClientVersionUnavailable(reason));
      expect(state.status, ClientVersionGateStatus.allowed, reason: '$reason');
    }
  });

  test('a stale cached minimum still blocks', () async {
    final state = await check(
      const ClientVersionFound(
        ClientVersionConfig(minimumBuildNumber: 9),
        fromCache: true,
      ),
    );
    expect(state.status, ClientVersionGateStatus.updateRequired);
  });

  test('requests during an in-flight check are dropped', () async {
    bloc.add(const ClientVersionCheckRequested());
    bloc.add(const ClientVersionCheckRequested());
    bloc.add(const ClientVersionCheckRequested());
    await settle();
    expect(repository.pending, hasLength(1));
    repository.answer(_unreachable);
    await settle();
    bloc.add(const ClientVersionCheckRequested());
    await settle();
    expect(repository.pending, hasLength(2));
  });

  test('a re-check keeps the current status while in flight', () async {
    await check(_minimum(6));
    bloc.add(const ClientVersionCheckRequested());
    await settle();
    expect(bloc.state.status, ClientVersionGateStatus.updateRequired);
    expect(bloc.state.isRechecking, isTrue);
    expect(bloc.state.config, isNotNull);

    repository.answer(_minimum(5));
    await settle();
    expect(bloc.state.status, ClientVersionGateStatus.allowed);
    expect(bloc.state.isRechecking, isFalse);
  });

  test('an allowed app becomes blocked when the minimum is raised', () async {
    await check(_minimum(1));
    final state = await check(_minimum(10));
    expect(state.status, ClientVersionGateStatus.updateRequired);
  });
}
