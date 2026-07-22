import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/review_item_entity.dart';
import '../repositories/review_schedule_repository.dart';

class ReviewMonthParams {
  final int hijriYear;
  final int hijriMonth;

  ReviewMonthParams({required this.hijriYear, required this.hijriMonth});
}

@injectable
class GetReviewMonthUseCase
    extends UseCase<ReviewMonthEntity, ReviewMonthParams> {
  final ReviewScheduleRepository repository;

  GetReviewMonthUseCase(this.repository);

  @override
  Future<Either<Failure, ReviewMonthEntity>> call(
    ReviewMonthParams params,
  ) async {
    try {
      return Right(
        await repository.getMonth(
          hijriYear: params.hijriYear,
          hijriMonth: params.hijriMonth,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
