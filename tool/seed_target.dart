/// Target selection and production guard shared by the Firestore seeders.
///
/// Pure Dart (no Firebase imports) so the safety rules are unit-testable.
/// Every seeder must go through [runGuardedSeed]: the target is resolved and
/// validated before Firebase is initialized and before any write.
library;

/// Environments a demo seeder may write to: the local emulator only.
/// Real projects (dev / staging / prod) are configured outside these tools.
enum SeedTarget { emulator }

const seedEmulatorProjectId = 'demo-rafiq-rules';

/// Real project names, recognized only to refuse them with a clear message.
const _realTargetNames = <String>{
  'dev',
  'staging',
  'prod',
  'production',
};

const seedTargetProjectIds = <SeedTarget, String>{
  SeedTarget.emulator: seedEmulatorProjectId,
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
const _allowedTargets = 'emulator';

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
  if (_realTargetNames.contains(raw)) {
    throw SeedTargetException(
      'Demo seeders never write to a real Firebase project ("$raw"). '
      'Allowed target: $_allowedTargets.',
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

/// Throws unless [projectId] is exactly the emulator demo project. Call it
/// on the resolved target and again on the initialized Firebase app.
void assertSeedProjectAllowed(String projectId) {
  if (projectId != seedEmulatorProjectId) {
    throw SeedTargetException(
      'Refusing to seed project "$projectId": demo seeders only write to '
      'the local emulator project "$seedEmulatorProjectId".',
    );
  }
}

/// Explicit password if given, otherwise the emulator demo default.
String resolveSeedPassword(
  SeedTargetConfig config, {
  required String explicitPassword,
  required String emulatorDefault,
}) {
  assertSeedProjectAllowed(config.projectId);
  final explicit = explicitPassword.trim();
  return explicit.isNotEmpty ? explicit : emulatorDefault;
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
