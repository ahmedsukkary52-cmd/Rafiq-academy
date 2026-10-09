/// Target selection and production guard shared by the Firestore seeders.
///
/// Pure Dart (no Firebase imports) so the safety rules are unit-testable.
/// Every seeder must go through [runGuardedSeed]: the target is resolved and
/// validated before Firebase is initialized and before any write.
library;

/// Environments a seeder may write to. Production is intentionally absent.
enum SeedTarget { emulator, dev, staging }

/// Firebase project IDs per environment (see `.firebaserc`).
const seedEmulatorProjectId = 'demo-rafiq-rules';
const seedDevProjectId = 'rafiq-academy';
const seedStagingProjectId = 'rafiq-academy-staging';
const productionProjectId = 'rafiq-academy-prod';

/// Project IDs a seeder must never initialize against, whatever the target.
const seedForbiddenProjectIds = <String>{productionProjectId};

const seedTargetProjectIds = <SeedTarget, String>{
  SeedTarget.emulator: seedEmulatorProjectId,
  SeedTarget.dev: seedDevProjectId,
  SeedTarget.staging: seedStagingProjectId,
};

class SeedTargetException implements Exception {
  final String message;
  const SeedTargetException(this.message);

  @override
  String toString() => message;
}

class SeedTargetConfig {
  final SeedTarget target;
  final String projectId;

  const SeedTargetConfig({required this.target, required this.projectId});

  bool get isEmulator => target == SeedTarget.emulator;
}

const _targetFlag = '--target=';
const _allowedTargets = 'emulator | dev | staging';

/// Resolves the target from `--target=<value>` in [args] and/or the
/// `SEED_TARGET` dart-define ([definedTarget]). There is no default.
SeedTargetConfig resolveSeedTarget(
  List<String> args, {
  String definedTarget = '',
}) {
  String? fromArgs;
  for (final a in args) {
    if (a.startsWith(_targetFlag)) fromArgs = a.substring(_targetFlag.length);
  }
  final fromDefine = definedTarget.trim();
  final argValue = fromArgs?.trim() ?? '';

  if (argValue.isNotEmpty &&
      fromDefine.isNotEmpty &&
      argValue != fromDefine) {
    throw SeedTargetException(
      'Conflicting seed targets: --target=$argValue and '
      'SEED_TARGET=$fromDefine. Pass exactly one.',
    );
  }
  final raw = (argValue.isNotEmpty ? argValue : fromDefine).toLowerCase();

  if (raw.isEmpty) {
    throw const SeedTargetException(
      'No seed target. Pass --dart-define=SEED_TARGET=<target> '
      '(or --target=<target>) where <target> is $_allowedTargets. '
      'Use "emulator" for local development.',
    );
  }
  if (raw == 'prod' || raw == 'production') {
    throw const SeedTargetException(
      'Seeding production is not allowed. Allowed targets: $_allowedTargets.',
    );
  }
  final target = SeedTarget.values.where((t) => t.name == raw).firstOrNull;
  if (target == null) {
    throw SeedTargetException(
      'Unknown seed target "$raw". Allowed targets: $_allowedTargets.',
    );
  }
  final config = SeedTargetConfig(
    target: target,
    projectId: seedTargetProjectIds[target]!,
  );
  assertSeedProjectAllowed(config.projectId);
  return config;
}

/// Throws when [projectId] is production (or otherwise forbidden). Call it
/// on the resolved target and again on the initialized Firebase app.
void assertSeedProjectAllowed(String projectId) {
  final id = projectId.trim();
  if (id.isEmpty) {
    throw const SeedTargetException('Seed project ID is empty.');
  }
  if (seedForbiddenProjectIds.contains(id)) {
    throw SeedTargetException(
      'Refusing to seed project "$id": seeders never write to production.',
    );
  }
}

/// Default passwords are only acceptable against the local emulator.
String resolveSeedPassword(
  SeedTargetConfig config, {
  required String explicitPassword,
  required String emulatorDefault,
}) {
  final explicit = explicitPassword.trim();
  if (explicit.isNotEmpty) return explicit;
  if (config.isEmulator) return emulatorDefault;
  throw SeedTargetException(
    'Target "${config.target.name}" needs an explicit password: pass '
    '--dart-define=SEED_PASSWORD=<password> (or --password=<password>). '
    'The default demo password is emulator-only.',
  );
}

/// Validates the target, then runs [preflight] (pure checks), then
/// [initialize] (Firebase setup), then [seed] (writes), in that order.
/// Returns a process exit code; nothing after a failed step runs.
Future<int> runGuardedSeed({
  required List<String> args,
  required String definedTarget,
  required Future<void> Function(SeedTargetConfig config) initialize,
  required Future<void> Function(SeedTargetConfig config) seed,
  void Function(SeedTargetConfig config)? preflight,
  void Function(String line) out = print,
  void Function(String line) err = print,
}) async {
  final SeedTargetConfig config;
  try {
    config = resolveSeedTarget(args, definedTarget: definedTarget);
    preflight?.call(config);
  } on SeedTargetException catch (e) {
    err('Seed aborted before Firebase initialization: ${e.message}');
    return 64;
  }

  out('Target: ${config.target.name}');
  out('Project: ${config.projectId}');

  try {
    await initialize(config);
  } on SeedTargetException catch (e) {
    err('Seed aborted before any write: ${e.message}');
    return 64;
  }
  await seed(config);
  return 0;
}
