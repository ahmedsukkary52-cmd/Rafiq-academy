import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B10 checks the minimum build only at cold start and on resume. A session
/// left in the foreground keeps running after the minimum is raised until the
/// next resume (J.10 release runbook).
void main() {
  test('the version gate is checked at start and on resume only', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect('ClientVersionCheckRequested()'.allMatches(main).length, 2);
    expect(
      RegExp(
        r'sl<ClientVersionGateBloc>\(\)\s*\.\.add\(const ClientVersionCheckRequested\(\)\)',
      ).hasMatch(main),
      isTrue,
    );
    expect(
      RegExp(
        r'onResume:\s*\(\)\s*=>\s*versionGate\.add\(const ClientVersionCheckRequested\(\)\)',
      ).hasMatch(main),
      isTrue,
    );

    final periodic = <String>[];
    for (final file in [
      File('lib/main.dart'),
      ...Directory('lib/features/app_update')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    ]) {
      if (file.readAsStringSync().contains('Timer.periodic')) {
        periodic.add(file.path);
      }
    }
    expect(periodic, isEmpty);
  });
}
