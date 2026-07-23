import '../entities/review_item_entity.dart';

abstract class ReviewScheduleRepository {
  Future<ReviewMonthEntity> getMonth({
    required String studentId,
    required int hijriYear,
    required int hijriMonth,
  });
}
