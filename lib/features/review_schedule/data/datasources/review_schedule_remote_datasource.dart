import '../models/review_schedule_doc_model.dart';

abstract class ReviewScheduleRemoteDatasource {
  /// Loads `reviewSchedules` for [studentId] with Gregorian [startInclusive, endExclusive).
  Future<List<ReviewScheduleDocModel>> getReviewsInRange({
    required String studentId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  });
}
