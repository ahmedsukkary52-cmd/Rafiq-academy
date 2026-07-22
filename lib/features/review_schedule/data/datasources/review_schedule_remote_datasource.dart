import '../../domain/entities/review_item_entity.dart';

abstract class ReviewScheduleRemoteDatasource {
  Future<ReviewMonthEntity> getMonth({
    required int hijriYear,
    required int hijriMonth,
  });
}
