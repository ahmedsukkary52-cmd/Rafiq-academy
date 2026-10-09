import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed_target.dart';

void main() {
  group('resolveSeedTarget', () {
    test('no target fails', () {
      expect(
        () => resolveSeedTarget(const []),
        throwsA(isA<SeedTargetException>()),
      );
      expect(
        () => resolveSeedTarget(const ['--target='], definedTarget: '  '),
        throwsA(isA<SeedTargetException>()),
      );
    });

    test('emulator, dev and staging are accepted with their project IDs', () {
      final emulator = resolveSeedTarget(const ['--target=emulator']);
      expect(emulator.target, SeedTarget.emulator);
      expect(emulator.projectId, 'demo-rafiq-rules');

      final dev = resolveSeedTarget(const [], definedTarget: 'dev');
      expect(dev.target, SeedTarget.dev);
      expect(dev.projectId, 'rafiq-academy');

      final staging = resolveSeedTarget(const ['--target=staging']);
      expect(staging.target, SeedTarget.staging);
      expect(staging.projectId, 'rafiq-academy-staging');
    });

    test('prod / production are rejected from args and dart-define', () {
      for (final value in ['prod', 'production', 'PROD']) {
        expect(
          () => resolveSeedTarget(['--target=$value']),
          throwsA(isA<SeedTargetException>()),
          reason: value,
        );
        expect(
          () => resolveSeedTarget(const [], definedTarget: value),
          throwsA(isA<SeedTargetException>()),
          reason: value,
        );
      }
    });

    test('unknown or conflicting targets are rejected', () {
      expect(
        () => resolveSeedTarget(const ['--target=qa']),
        throwsA(isA<SeedTargetException>()),
      );
      expect(
        () => resolveSeedTarget(
          const ['--target=dev'],
          definedTarget: 'staging',
        ),
        throwsA(isA<SeedTargetException>()),
      );
    });

    test('no target resolves to the production project', () {
      expect(seedTargetProjectIds.values, isNot(contains(productionProjectId)));
    });
  });

  group('assertSeedProjectAllowed', () {
    test('rejects the production project ID', () {
      expect(productionProjectId, 'rafiq-academy-prod');
      expect(
        () => assertSeedProjectAllowed('rafiq-academy-prod'),
        throwsA(isA<SeedTargetException>()),
      );
      expect(
        () => assertSeedProjectAllowed(' rafiq-academy-prod '),
        throwsA(isA<SeedTargetException>()),
      );
      expect(
        () => assertSeedProjectAllowed(''),
        throwsA(isA<SeedTargetException>()),
      );
    });

    test('allows the non-production projects', () {
      for (final id in seedTargetProjectIds.values) {
        assertSeedProjectAllowed(id);
      }
    });
  });

  group('resolveSeedPassword', () {
    const emulator = SeedTargetConfig(
      target: SeedTarget.emulator,
      projectId: seedEmulatorProjectId,
    );
    const dev = SeedTargetConfig(
      target: SeedTarget.dev,
      projectId: seedDevProjectId,
    );
    const staging = SeedTargetConfig(
      target: SeedTarget.staging,
      projectId: seedStagingProjectId,
    );

    test('emulator may fall back to the demo default', () {
      expect(
        resolveSeedPassword(
          emulator,
          explicitPassword: '',
          emulatorDefault: 'demo',
        ),
        'demo',
      );
    });

    test('dev and staging require an explicit password', () {
      for (final config in [dev, staging]) {
        expect(
          () => resolveSeedPassword(
            config,
            explicitPassword: ' ',
            emulatorDefault: 'demo',
          ),
          throwsA(isA<SeedTargetException>()),
        );
        expect(
          resolveSeedPassword(
            config,
            explicitPassword: 'explicit',
            emulatorDefault: 'demo',
          ),
          'explicit',
        );
      }
    });
  });

  group('runGuardedSeed', () {
    late List<String> calls;

    Future<int> run(
      List<String> args, {
      String define = '',
      void Function(SeedTargetConfig)? preflight,
      Future<void> Function(SeedTargetConfig)? initialize,
    }) {
      return runGuardedSeed(
        args: args,
        definedTarget: define,
        preflight: (c) {
          calls.add('preflight');
          preflight?.call(c);
        },
        initialize: (c) async {
          calls.add('initialize');
          await initialize?.call(c);
        },
        seed: (c) async => calls.add('seed:${c.projectId}'),
        out: (line) => calls.add('out:$line'),
        err: (line) => calls.add('err'),
      );
    }

    setUp(() => calls = []);

    test('invalid targets never initialize Firebase or write', () async {
      for (final args in [
        const <String>[],
        const ['--target=prod'],
        const ['--target=production'],
        const ['--target=unknown'],
      ]) {
        calls = [];
        expect(await run(args), isNot(0), reason: '$args');
        expect(calls, ['err'], reason: '$args');
      }
    });

    test('a failing preflight stops before initialization', () async {
      final code = await run(
        const ['--target=dev'],
        preflight: (_) => throw const SeedTargetException('no password'),
      );
      expect(code, isNot(0));
      expect(calls, ['preflight', 'err']);
    });

    test('a guard failure during initialization stops before any write',
        () async {
      final code = await run(
        const ['--target=staging'],
        initialize: (_) async =>
            throw const SeedTargetException('not configured'),
      );
      expect(code, isNot(0));
      expect(calls, isNot(contains(startsWith('seed:'))));
      expect(calls.last, 'err');
    });

    test('valid target prints target and project, then initializes, then seeds',
        () async {
      final code = await run(const ['--target=emulator']);
      expect(code, 0);
      expect(calls, [
        'preflight',
        'out:Target: emulator',
        'out:Project: demo-rafiq-rules',
        'initialize',
        'seed:demo-rafiq-rules',
      ]);
    });
  });

  group('seeder entry points', () {
    for (final path in [
      'tool/seed_firestore.dart',
      'tool/seed_teacher_flow.dart',
    ]) {
      test('$path initializes only through the target guard', () {
        final source = File(path).readAsStringSync();
        expect(source, contains('runGuardedSeed('));
        expect(source, contains('initializeSeedFirebase('));
        expect(source, isNot(contains('Firebase.initializeApp(')));
        expect(source, isNot(contains('DefaultFirebaseOptions')));
      });
    }

    test('only the emulator target may use the demo default password', () {
      final source = File('tool/seed_firestore.dart').readAsStringSync();
      expect(source, contains('emulatorDefault: demoPasswordDefault'));
      expect(source, isNot(contains('return demoPasswordDefault')));
    });
  });
}
