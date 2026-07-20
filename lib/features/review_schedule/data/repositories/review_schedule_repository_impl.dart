import 'package:injectable/injectable.dart';

import '../../domain/entities/review_item_entity.dart';
import '../../domain/repositories/review_schedule_repository.dart';
import '../datasources/review_schedule_remote_datasource.dart';

@LazySingleton(as: ReviewScheduleRepository)
class ReviewScheduleRepositoryImpl implements ReviewScheduleRepository {
  final ReviewScheduleRemoteDatasource remoteDatasource;

  ReviewScheduleRepositoryImpl(this.remoteDatasource);

  @override
  Future<ReviewMonthEntity> getMonth({
    required int hijriYear,
    required int hijriMonth,
  }) => remoteDatasource.getMonth(hijriYear: hijriYear, hijriMonth: hijriMonth);
}
