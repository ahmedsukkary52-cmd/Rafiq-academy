import 'package:injectable/injectable.dart';

import '../../domain/entities/review_item_entity.dart';
import '../../domain/repositories/review_schedule_repository.dart';
import '../datasources/review_schedule_remote_datasource.dart';
import '../mappers/review_month_mapper.dart';

@LazySingleton(as: ReviewScheduleRepository)
class ReviewScheduleRepositoryImpl implements ReviewScheduleRepository {
  final ReviewScheduleRemoteDatasource remoteDatasource;
  final ReviewMonthMapper _mapper;

  ReviewScheduleRepositoryImpl(this.remoteDatasource)
    : _mapper = const ReviewMonthMapper();

  @override
  Future<ReviewMonthEntity> getMonth({
    required String studentId,
    required int hijriYear,
    required int hijriMonth,
  }) async {
    final id = studentId.trim();
    if (id.isEmpty) {
      return _mapper.map(
        hijriYear: hijriYear,
        hijriMonth: hijriMonth,
        docs: const [],
      );
    }

    final range = _mapper.gregorianRangeForHijriMonth(
      hijriYear: hijriYear,
      hijriMonth: hijriMonth,
    );

    final docs = await remoteDatasource.getReviewsInRange(
      studentId: id,
      startInclusive: range.start,
      endExclusive: range.end,
    );

    return _mapper.map(
      hijriYear: hijriYear,
      hijriMonth: hijriMonth,
      docs: docs,
    );
  }
}
