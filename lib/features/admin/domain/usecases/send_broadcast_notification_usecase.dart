import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

/// Admin ops broadcast use case — quarantined outside academy events (H3 / A-H15).
///
/// Does **not** publish [AcademyEvent]s. Prefer [AdminOpsBroadcast] schema docs.
@lazySingleton
class SendBroadcastNotificationUseCase extends UseCase<Unit, BroadcastParams> {
  final AdminRepository repository;

  SendBroadcastNotificationUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(BroadcastParams params) =>
      repository.sendBroadcastNotification(
        title: params.title,
        body: params.body,
        targetRole: params.targetRole,
      );
}
