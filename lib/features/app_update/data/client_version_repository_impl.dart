import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/client_version_config.dart';
import '../domain/client_version_repository.dart';
import 'client_version_source.dart';

const Duration clientVersionServerTimeout = Duration(seconds: 5);
const Duration clientVersionCacheTimeout = Duration(seconds: 2);

/// Server first; the cache only when the server cannot answer. A server
/// answer (missing or malformed) is final, so stale cached data never
/// overrides it.
@LazySingleton(as: ClientVersionRepository)
class ClientVersionRepositoryImpl implements ClientVersionRepository {
  final ClientVersionSource source;
  final Duration serverTimeout;
  final Duration cacheTimeout;

  ClientVersionRepositoryImpl(this.source)
    : serverTimeout = clientVersionServerTimeout,
      cacheTimeout = clientVersionCacheTimeout;

  @visibleForTesting
  ClientVersionRepositoryImpl.withTimeouts(
    this.source, {
    required this.serverTimeout,
    required this.cacheTimeout,
  });

  @override
  Future<ClientVersionLookup> load() async {
    final Map<String, dynamic>? data;
    try {
      data = await source
          .read(ClientVersionReadSource.server)
          .timeout(serverTimeout);
    } catch (_) {
      return _loadCached();
    }
    if (data == null) {
      return const ClientVersionUnavailable(
        ClientVersionUnavailableReason.missing,
      );
    }
    return switch (parseClientVersionConfig(data)) {
      ValidClientVersionConfig(:final config) => ClientVersionFound(config),
      InvalidClientVersionConfig() => const ClientVersionUnavailable(
        ClientVersionUnavailableReason.malformed,
      ),
    };
  }

  Future<ClientVersionLookup> _loadCached() async {
    const unreachable = ClientVersionUnavailable(
      ClientVersionUnavailableReason.unreachable,
    );
    try {
      final data = await source
          .read(ClientVersionReadSource.cache)
          .timeout(cacheTimeout);
      if (data == null) return unreachable;
      return switch (parseClientVersionConfig(data)) {
        ValidClientVersionConfig(:final config) => ClientVersionFound(
          config,
          fromCache: true,
        ),
        InvalidClientVersionConfig() => unreachable,
      };
    } catch (_) {
      return unreachable;
    }
  }
}
