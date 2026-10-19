import 'bloc/client_version_gate_bloc.dart';

/// Pure B10 routing decision, applied before onboarding and auth.
class VersionGateRedirect {
  const VersionGateRedirect._();

  /// While checking, everything waits on [splashPath]; while an update is
  /// required, only [updatePath] is reachable. Once allowed, [updatePath]
  /// is left and every other decision is delegated to [otherwise].
  static String? resolve({
    required ClientVersionGateStatus status,
    required String path,
    required String splashPath,
    required String updatePath,
    required String? Function() otherwise,
  }) => switch (status) {
    ClientVersionGateStatus.checking => path == splashPath ? null : splashPath,
    ClientVersionGateStatus.updateRequired =>
      path == updatePath ? null : updatePath,
    ClientVersionGateStatus.allowed =>
      path == updatePath ? splashPath : otherwise(),
  };
}
