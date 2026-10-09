import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/firebase_options.dart';

import '../../tool/seed_firebase.dart';
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

    test('only the emulator target exists', () {
      final emulator = resolveSeedTarget(const ['--target=emulator']);
      expect(emulator.target, SeedTarget.emulator);
      expect(emulator.projectId, 'demo-rafiq-rules');
      expect(
        resolveSeedTarget(const [], definedTarget: 'EMULATOR').projectId,
        'demo-rafiq-rules',
      );
      expect(SeedTarget.values, [SeedTarget.emulator]);
      expect(seedTargetProjectIds, {SeedTarget.emulator: 'demo-rafiq-rules'});
    });

    test('real targets are rejected from args and dart-define', () {
      for (final value in [
        'dev',
        'staging',
        'prod',
        'production',
        'PROD',
        'Dev',
      ]) {
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
          const ['--target=emulator'],
          definedTarget: 'dev',
        ),
        throwsA(isA<SeedTargetException>()),
      );
    });
  });

  group('assertSeedProjectAllowed', () {
    test('rejects every project except the exact emulator project', () {
      for (final id in [
        'rafiq-academy',
        'rafiq-academy-staging',
        'rafiq-academy-prod',
        'demo-other',
        'demo-rafiq-rules-x',
        ' demo-rafiq-rules',
        'DEMO-RAFIQ-RULES',
        '',
      ]) {
        expect(
          () => assertSeedProjectAllowed(id),
          throwsA(isA<SeedTargetException>()),
          reason: id,
        );
      }
      assertSeedProjectAllowed('demo-rafiq-rules');
    });
  });

  group('resolveSeedPassword', () {
    const emulator = SeedTargetConfig(
      target: SeedTarget.emulator,
      projectId: seedEmulatorProjectId,
    );

    test('emulator falls back to the demo default or uses an explicit one', () {
      expect(
        resolveSeedPassword(
          emulator,
          explicitPassword: ' ',
          emulatorDefault: 'demo',
        ),
        'demo',
      );
      expect(
        resolveSeedPassword(
          emulator,
          explicitPassword: 'explicit',
          emulatorDefault: 'demo',
        ),
        'explicit',
      );
    });

    test('a config naming another project is refused', () {
      expect(
        () => resolveSeedPassword(
          const SeedTargetConfig(
            target: SeedTarget.emulator,
            projectId: 'rafiq-academy',
          ),
          explicitPassword: '',
          emulatorDefault: 'demo',
        ),
        throwsA(isA<SeedTargetException>()),
      );
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
        const ['--target=dev'],
        const ['--target=staging'],
        const ['--target=unknown'],
      ]) {
        calls = [];
        expect(await run(args), isNot(0), reason: '$args');
        expect(calls, ['err'], reason: '$args');
      }
    });

    test('a failing preflight stops before initialization', () async {
      final code = await run(
        const ['--target=emulator'],
        preflight: (_) => throw const SeedTargetException('no password'),
      );
      expect(code, isNot(0));
      expect(calls, ['preflight', 'err']);
    });

    test('a guard failure during initialization stops before any write',
        () async {
      final code = await run(
        const ['--target=emulator'],
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

  group('seedFirebaseOptions', () {
    const realOptions = [
      DefaultFirebaseOptions.android,
      DefaultFirebaseOptions.ios,
    ];

    test('emulator options use the demo project and no real credentials', () {
      final options = seedFirebaseOptions(SeedTarget.emulator);
      expect(options.projectId, 'demo-rafiq-rules');
      for (final real in realOptions) {
        expect(options.projectId, isNot(real.projectId));
        expect(options.apiKey, isNot(real.apiKey));
        expect(options.appId, isNot(real.appId));
        expect(options.messagingSenderId, isNot(real.messagingSenderId));
      }
      for (final value in options.asMap.values.whereType<String>()) {
        expect(value, isNot(contains('rafiq-academy')), reason: value);
        expect(value, isNot(contains('AIza')), reason: value);
      }
      expect(options.storageBucket, isNull);
    });

    test('every seeder target resolves to the emulator options', () {
      for (final target in SeedTarget.values) {
        expect(seedFirebaseOptions(target), seedEmulatorFirebaseOptions);
      }
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

    test('seeder tools never reference real Firebase options or projects', () {
      for (final path in [
        'tool/seed_target.dart',
        'tool/seed_firebase.dart',
        'tool/seed_firestore.dart',
        'tool/seed_teacher_flow.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('firebase_options.dart')), reason: path);
        expect(source, isNot(contains('DefaultFirebaseOptions')), reason: path);
        expect(source, isNot(contains('rafiq-academy')), reason: path);
        expect(source, isNot(contains('SEED_TARGET=dev')), reason: path);
      }
    });

    test('emulator connections use the IPv4 loopback the emulators bind to',
        () {
      final source = File('tool/seed_firebase.dart').readAsStringSync();
      expect(source, contains("_emulatorHost = '127.0.0.1'"));
    });
  });
}
