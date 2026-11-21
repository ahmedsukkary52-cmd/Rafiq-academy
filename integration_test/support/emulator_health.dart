import 'dart:io';

import 'package:rafiq_academy/core/firebase/app_firebase.dart';

/// TCP readiness probes for the local Firebase Emulator Suite.
///
/// Fail closed: if any required emulator port is closed, integration tests
/// must throw — never fall through to a real Firebase project.
class EmulatorHealth {
  EmulatorHealth({
    this.host = firebaseEmulatorHost,
    this.authPort = authEmulatorPort,
    this.firestorePort = firestoreEmulatorPort,
    this.functionsPort = functionsEmulatorPort,
    this.storagePort = storageEmulatorPort,
    this.timeout = const Duration(seconds: 2),
  });

  final String host;
  final int authPort;
  final int firestorePort;
  final int functionsPort;
  final int storagePort;
  final Duration timeout;

  /// Required services for Flutter ↔ Emulator journeys in this bootstrap.
  Map<String, int> get requiredPorts => {
    'auth': authPort,
    'firestore': firestorePort,
    'functions': functionsPort,
    'storage': storagePort,
  };

  Future<bool> isPortOpen(int port) async {
    assertLoopbackEmulatorHost(host);
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } on SocketException {
      return false;
    } on OSError {
      return false;
    }
  }

  /// Throws [StateError] listing every missing emulator — never contacts Cloud.
  Future<void> assertReady() async {
    assertLoopbackEmulatorHost(host);
    final missing = <String>[];
    for (final entry in requiredPorts.entries) {
      if (!await isPortOpen(entry.value)) {
        missing.add('${entry.key}:${entry.value}');
      }
    }
    if (missing.isNotEmpty) {
      throw StateError(
        'Firebase Emulator Suite is not reachable on $host '
        '(missing ${missing.join(', ')}). Refusing to start integration '
        'tests — would otherwise risk Production. Start with '
        '`npm --prefix functions run serve` (project demo-rafiq-rules) '
        'then re-run.',
      );
    }
  }
}
