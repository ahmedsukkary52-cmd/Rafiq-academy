import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class CreateHalaqaUseCase extends UseCase<String, CreateHalaqaParams> {
  final AdminRepository repository;

  CreateHalaqaUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(CreateHalaqaParams params) =>
      repository.createHalaqa(
        name: params.name,
        teacherId: params.teacherId,
        supervisorId: params.supervisorId,
        meetingLink: params.meetingLink,
      );
}

@lazySingleton
class EnsureAdminInternalChatUseCase
    extends UseCase<String, EnsureAdminInternalChatParams> {
  final AdminRepository repository;

  EnsureAdminInternalChatUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(EnsureAdminInternalChatParams params) =>
      repository.ensureAdminInternalChat(adminUid: params.adminUid);
}
