import 'package:equatable/equatable.dart';

import '../../domain/entities/award_entities.dart';

abstract class AwardsEvent extends Equatable {
  const AwardsEvent();

  @override
  List<Object?> get props => [];
}

class LoadAwardsDashboardEvent extends AwardsEvent {
  final String halaqaId;

  const LoadAwardsDashboardEvent(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

class GrantAwardEvent extends AwardsEvent {
  final GrantedAwardEntity award;

  const GrantAwardEvent(this.award);

  @override
  List<Object?> get props => [award];
}

class ResetGrantAwardEvent extends AwardsEvent {
  const ResetGrantAwardEvent();
}

/// توليد PDF لشهادة طالب معيّن
class GenerateCertificateEvent extends AwardsEvent {
  final CertificateDataEntity data;

  const GenerateCertificateEvent(this.data);

  @override
  List<Object?> get props => [data];
}

class ResetCertificateEvent extends AwardsEvent {
  const ResetCertificateEvent();
}
