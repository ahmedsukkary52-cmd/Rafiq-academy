import '../../domain/entities/award_entities.dart';
import '../models/granted_award_model.dart';

abstract class AwardsRemoteDatasource {
  Future<AwardsStatsEntity> getAwardsStats(String halaqaId);

  Future<List<GrantedAwardModel>> getGrantedAwards(String halaqaId);

  Future<void> grantAward(GrantedAwardModel award);
}
