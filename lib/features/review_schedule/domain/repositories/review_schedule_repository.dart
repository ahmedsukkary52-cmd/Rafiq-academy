import '../entities/review_item_entity.dart';

abstract class ReviewScheduleRepository {
  Future<ReviewMonthEntity> getMonth({
    required int hijriYear,
    required int hijriMonth,
  });
}
