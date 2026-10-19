import 'client_version_config.dart';

/// Outcome of reading `appConfig/clientVersion`; Firebase errors never leak.
sealed class ClientVersionLookup {
  const ClientVersionLookup();
}

final class ClientVersionFound extends ClientVersionLookup {
  final ClientVersionConfig config;

  /// True when the server was unreachable and the cached copy was used.
  final bool fromCache;

  const ClientVersionFound(this.config, {this.fromCache = false});
}

enum ClientVersionUnavailableReason {
  /// The server reports no document.
  missing,

  /// The server's document is invalid.
  malformed,

  /// No server answer in time and no valid cached copy.
  unreachable,
}

/// No usable configuration; the gate fails open.
final class ClientVersionUnavailable extends ClientVersionLookup {
  final ClientVersionUnavailableReason reason;

  const ClientVersionUnavailable(this.reason);
}

abstract class ClientVersionRepository {
  /// Completes within a bounded time, never throws.
  Future<ClientVersionLookup> load();
}
