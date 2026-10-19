import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_build_number.dart';
import '../../domain/client_version_config.dart';
import '../../domain/client_version_repository.dart';

enum ClientVersionGateStatus { checking, allowed, updateRequired }

class ClientVersionGateState extends Equatable {
  final ClientVersionGateStatus status;

  /// The configuration that required the update (store links).
  final ClientVersionConfig? config;

  /// A re-check (resume or retry) is in flight; [status] keeps its value.
  final bool isRechecking;

  const ClientVersionGateState({
    this.status = ClientVersionGateStatus.checking,
    this.config,
    this.isRechecking = false,
  });

  @override
  List<Object?> get props => [status, config, isRechecking];
}

/// Startup, resume and retry checks share this event; while one check runs,
/// further requests are dropped.
class ClientVersionCheckRequested {
  const ClientVersionCheckRequested();
}

/// B10 minimum-version gate. Fails open: only a valid configuration whose
/// minimum exceeds [installedBuild] blocks the app.
@injectable
class ClientVersionGateBloc
    extends Bloc<ClientVersionCheckRequested, ClientVersionGateState> {
  final ClientVersionRepository repository;
  final int installedBuild;

  ClientVersionGateBloc(this.repository)
    : installedBuild = kAppBuildNumber,
      super(const ClientVersionGateState()) {
    _register();
  }

  @visibleForTesting
  ClientVersionGateBloc.withBuild(
    this.repository, {
    required this.installedBuild,
  }) : super(const ClientVersionGateState()) {
    _register();
  }

  void _register() =>
      on<ClientVersionCheckRequested>(_onCheck, transformer: droppable());

  Future<void> _onCheck(
    ClientVersionCheckRequested event,
    Emitter<ClientVersionGateState> emit,
  ) async {
    if (state.status != ClientVersionGateStatus.checking) {
      emit(
        ClientVersionGateState(
          status: state.status,
          config: state.config,
          isRechecking: true,
        ),
      );
    }
    final ClientVersionLookup lookup;
    try {
      lookup = await repository.load();
    } catch (error, stackTrace) {
      // The repository contract is "never throws"; if it does, fail open
      // rather than hold startup on splash. Reported, not logged.
      addError(error, stackTrace);
      emit(
        const ClientVersionGateState(status: ClientVersionGateStatus.allowed),
      );
      return;
    }
    if (lookup is ClientVersionFound &&
        !meetsMinimumBuild(
          installedBuild: installedBuild,
          minimumBuild: lookup.config.minimumBuildNumber,
        )) {
      emit(
        ClientVersionGateState(
          status: ClientVersionGateStatus.updateRequired,
          config: lookup.config,
        ),
      );
      return;
    }
    emit(const ClientVersionGateState(status: ClientVersionGateStatus.allowed));
  }
}
