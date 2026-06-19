import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

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
