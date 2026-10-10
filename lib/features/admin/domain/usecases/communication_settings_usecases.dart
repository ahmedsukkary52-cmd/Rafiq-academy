import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/communication_settings_entity.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetCommunicationSettingsUseCase
    extends UseCase<CommunicationSettingsEntity, NoParams> {
  final AdminRepository repository;

  GetCommunicationSettingsUseCase(this.repository);

  @override
  Future<Either<Failure, CommunicationSettingsEntity>> call(NoParams params) =>
      repository.getCommunicationSettings();
}

@lazySingleton
class SaveCommunicationSettingsUseCase
    extends UseCase<Unit, CommunicationSettingsEntity> {
  final AdminRepository repository;

  SaveCommunicationSettingsUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(CommunicationSettingsEntity params) =>
      repository.saveCommunicationSettings(params);
}
