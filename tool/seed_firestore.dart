/// Full-academy Firestore seeder for development (permanent Demo Academy dataset).
///
/// Expands the original W1–W8 smoke seeder into a realistic multi-halaqa academy.
/// Does **not** modify production app code beyond what the app already reads.
///
/// Run from project root with an explicit target (no default; production is
/// never accepted):
///
/// ```bash
/// # Local emulators (preferred): cd functions && npm run serve
/// flutter run -d windows -t tool/seed_firestore.dart --dart-define=SEED_TARGET=emulator
///
/// # Real dev project (rafiq-academy) — password is required
/// flutter run -d windows -t tool/seed_firestore.dart --dart-define=SEED_TARGET=dev --dart-define=SEED_PASSWORD=<password>
/// ```
///
/// `--target=<target>` / `--password=<password>` entrypoint args are accepted
/// too. The default demo password is used only for the emulator target.
///
/// Idempotent: fixed Auth emails + document IDs; re-runs overwrite the same docs.
///
/// See: docs/DEMO_ACADEMY_DATASET.md
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'demo_academy_dataset.dart';
import 'seed_firebase.dart';
import 'seed_target.dart';

Future<void> main(List<String> rawArgs) async {
  WidgetsFlutterBinding.ensureInitialized();

  late String password;
  final code = await runGuardedSeed(
    args: rawArgs,
    definedTarget: const String.fromEnvironment('SEED_TARGET'),
    preflight: (config) {
      password = resolveSeedPassword(
        config,
        explicitPassword: _readExplicitPassword(rawArgs),
        emulatorDefault: demoPasswordDefault,
      );
    },
    initialize: (config) async {
      stdout.writeln('Initializing Firebase…');
      await initializeSeedFirebase(config);
    },
    seed: (_) => _seed(password),
    out: stdout.writeln,
    err: stderr.writeln,
  );
  exit(code);
}

Future<void> _seed(String password) async {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final now = DateTime.now();

  stdout.writeln('Creating / reusing Auth accounts…');
  final users = await ensureAllDemoAuthUsers(auth, password: password);

  // Prefer writing while signed in as primary teacher (typical staff rules).
  await auth.signInWithEmailAndPassword(
    email: 'teacher@rafiq.demo',
    password: password,
  );

  stdout.writeln('Seeding Demo Academy dataset…');
  await seedDemoAcademyDataset(db, auth, users: users, now: now);

  printDemoCredentials(password);
}

String _readExplicitPassword(List<String> rawArgs) {
  const fromDefine = String.fromEnvironment('SEED_PASSWORD');
  if (fromDefine.isNotEmpty) return fromDefine;
  for (final a in rawArgs) {
    if (a.startsWith('--password=')) {
      return a.substring('--password='.length);
    }
  }
  return '';
}
