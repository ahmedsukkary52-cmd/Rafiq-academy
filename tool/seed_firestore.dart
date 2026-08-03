/// Full-academy Firestore seeder for development (permanent Demo Academy dataset).
///
/// Expands the original W1–W8 smoke seeder into a realistic multi-halaqa academy.
/// Does **not** modify production app code beyond what the app already reads.
///
/// Run from project root:
///
/// ```bash
/// flutter run -d windows -t tool/seed_firestore.dart
/// ```
///
/// Optional:
///   --password=YourPassword123!
///   --dart-define=SEED_PASSWORD=YourPassword123!
///
/// Idempotent: fixed Auth emails + document IDs; re-runs overwrite the same docs.
///
/// See: docs/DEMO_ACADEMY_DATASET.md
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:rafiq_academy/firebase_options.dart';

import 'demo_academy_dataset.dart';

Future<void> main(List<String> rawArgs) async {
  WidgetsFlutterBinding.ensureInitialized();

  final password = _readPassword(rawArgs);
  stdout.writeln('Initializing Firebase…');
  // Android options so the tool runs on desktop without a Windows Firebase entry.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);

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
  exit(0);
}

String _readPassword(List<String> rawArgs) {
  const fromDefine = String.fromEnvironment('SEED_PASSWORD');
  if (fromDefine.isNotEmpty) return fromDefine;
  for (final a in rawArgs) {
    if (a.startsWith('--password=')) {
      return a.substring('--password='.length);
    }
  }
  return demoPasswordDefault;
}
