import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/app_update/data/client_version_repository_impl.dart';
import 'package:rafiq_academy/features/app_update/data/client_version_source.dart';
import 'package:rafiq_academy/features/app_update/domain/client_version_config.dart';
import 'package:rafiq_academy/features/app_update/domain/client_version_repository.dart';

typedef _Read = Future<Map<String, dynamic>?> Function();

class _FakeSource implements ClientVersionSource {
  _FakeSource({required this.server, _Read? cache})
    : cache = cache ?? (() async => throw StateError('no cache'));

  final _Read server;
  final _Read cache;
  final reads = <ClientVersionReadSource>[];

  @override
  Future<Map<String, dynamic>?> read(ClientVersionReadSource from) {
    reads.add(from);
    return from == ClientVersionReadSource.server ? server() : cache();
  }
}

Future<Map<String, dynamic>?> _never() =>
    Completer<Map<String, dynamic>?>().future;

ClientVersionRepositoryImpl _repo(_FakeSource source) =>
    ClientVersionRepositoryImpl.withTimeouts(
      source,
      serverTimeout: const Duration(milliseconds: 20),
      cacheTimeout: const Duration(milliseconds: 20),
    );

void main() {
  test('production timeouts are bounded', () {
    expect(clientVersionServerTimeout, const Duration(seconds: 5));
    expect(clientVersionCacheTimeout, const Duration(seconds: 2));
  });

  test('valid server document is found without reading the cache', () async {
    final source = _FakeSource(server: () async => {'minimumBuildNumber': 7});
    final result = await _repo(source).load();
    expect(result, isA<ClientVersionFound>());
    result as ClientVersionFound;
    expect(result.config, const ClientVersionConfig(minimumBuildNumber: 7));
    expect(result.fromCache, isFalse);
    expect(source.reads, [ClientVersionReadSource.server]);
  });

  test('missing server document is final (no cache fallback)', () async {
    final source = _FakeSource(
      server: () async => null,
      cache: () async => {'minimumBuildNumber': 99},
    );
    final result = await _repo(source).load();
    expect(
      (result as ClientVersionUnavailable).reason,
      ClientVersionUnavailableReason.missing,
    );
    expect(source.reads, [ClientVersionReadSource.server]);
  });

  test('malformed server document is final (no cache fallback)', () async {
    final source = _FakeSource(
      server: () async => {'minimumBuildNumber': '7'},
      cache: () async => {'minimumBuildNumber': 99},
    );
    final result = await _repo(source).load();
    expect(
      (result as ClientVersionUnavailable).reason,
      ClientVersionUnavailableReason.malformed,
    );
    expect(source.reads, [ClientVersionReadSource.server]);
  });

  test('server error falls back to a valid cached document', () async {
    final source = _FakeSource(
      server: () async => throw Exception('unavailable'),
      cache: () async => {'minimumBuildNumber': 4},
    );
    final result = await _repo(source).load();
    result as ClientVersionFound;
    expect(result.config.minimumBuildNumber, 4);
    expect(result.fromCache, isTrue);
  });

  test('server timeout falls back to a valid cached document', () async {
    final source = _FakeSource(
      server: _never,
      cache: () async => {'minimumBuildNumber': 4},
    );
    final result = await _repo(source).load();
    expect((result as ClientVersionFound).fromCache, isTrue);
  });

  test('unreachable server and no usable cache fail open', () async {
    for (final cache in <_Read>[
      () async => null,
      () async => {'minimumBuildNumber': 0},
      () async => throw Exception('cache miss'),
      _never,
    ]) {
      final result = await _repo(
        _FakeSource(server: () async => throw Exception('x'), cache: cache),
      ).load();
      expect(
        (result as ClientVersionUnavailable).reason,
        ClientVersionUnavailableReason.unreachable,
      );
    }
  });

  test('hanging server and hanging cache still complete', () async {
    final result = await _repo(
      _FakeSource(server: _never, cache: _never),
    ).load();
    expect(result, isA<ClientVersionUnavailable>());
  });
}
