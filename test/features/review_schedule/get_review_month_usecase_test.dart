import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/error/user_facing_error.dart';
import 'package:rafiq_academy/features/review_schedule/domain/entities/review_item_entity.dart';
import 'package:rafiq_academy/features/review_schedule/domain/repositories/review_schedule_repository.dart';
import 'package:rafiq_academy/features/review_schedule/domain/usecases/get_review_month_usecase.dart';

class _FakeRepo implements ReviewScheduleRepository {
  String? lastStudentId;
  Object? toThrow;
  ReviewMonthEntity result = const ReviewMonthEntity(
    hijriYear: 1446,
    hijriMonth: 1,
    monthTitle: 'محرم 1446',
    daysWithReview: [],
    weekItems: [],
  );

  @override
  Future<ReviewMonthEntity> getMonth({
    required String studentId,
    required int hijriYear,
    required int hijriMonth,
  }) async {
    lastStudentId = studentId;
    if (toThrow != null) {
      // ignore: only_throw_errors
      throw toThrow!;
    }
    return result;
  }
}

void main() {
  late _FakeRepo repo;
  late GetReviewMonthUseCase useCase;

  setUp(() {
    repo = _FakeRepo();
    useCase = GetReviewMonthUseCase(repo);
  });

  test('forwards params and returns Right on success', () async {
    final either = await useCase(
      const ReviewMonthParams(
        studentId: 'stu-1',
        hijriYear: 1446,
        hijriMonth: 2,
      ),
    );
    expect(repo.lastStudentId, 'stu-1');
    expect(either.isRight(), isTrue);
    either.fold((_) => fail('expected Right'), (m) {
      expect(m.monthTitle, 'محرم 1446');
    });
  });

  test('maps ServerException to ServerFailure', () async {
    repo.toThrow = const ServerException('boom');
    final either = await useCase(
      const ReviewMonthParams(
        studentId: 'stu-1',
        hijriYear: 1446,
        hijriMonth: 1,
      ),
    );
    expect(either, isA<Left<Failure, ReviewMonthEntity>>());
    either.fold((f) {
      expect(f, isA<ServerFailure>());
      expect(f.message, 'boom');
    }, (_) => fail('expected Left'));
  });

  test('maps unexpected errors to user-facing ServerFailure', () async {
    repo.toThrow = StateError('unexpected');
    final either = await useCase(
      const ReviewMonthParams(
        studentId: 'stu-1',
        hijriYear: 1446,
        hijriMonth: 1,
      ),
    );
    either.fold((f) {
      expect(f, isA<ServerFailure>());
      // ServerFailure.message is sanitized via userFacingErrorText.
      expect(f.message, genericErrorText);
    }, (_) => fail('expected Left'));
  });
}
