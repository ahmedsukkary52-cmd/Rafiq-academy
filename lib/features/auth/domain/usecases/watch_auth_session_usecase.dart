import 'package:injectable/injectable.dart';

import '../repositories/auth_repository.dart';

/// Firebase session uid stream; `null` means the session ended (sign-out,
/// revoked/expired token, disabled Auth account).
@lazySingleton
class WatchAuthSessionUseCase {
  final AuthRepository repository;

  WatchAuthSessionUseCase(this.repository);

  Stream<String?> call() => repository.sessionUidChanges;
}
