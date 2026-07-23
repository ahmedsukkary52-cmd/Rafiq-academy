import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/review_item_entity.dart';
import '../../domain/usecases/get_review_month_usecase.dart';

part 'review_schedule_event.dart';
part 'review_schedule_state.dart';

@injectable
class ReviewScheduleBloc
    extends Bloc<ReviewScheduleEvent, ReviewScheduleState> {
  final GetReviewMonthUseCase getReviewMonth;

  ReviewScheduleBloc(this.getReviewMonth)
    : super(ReviewScheduleState.initial()) {
    on<LoadReviewMonthEvent>(_onLoad);
    on<ChangeReviewMonthEvent>(_onChangeMonth);
  }

  Future<void> _onLoad(
    LoadReviewMonthEvent event,
    Emitter<ReviewScheduleState> emit,
  ) async {
    final studentId = event.studentId ?? state.studentId ?? '';
    emit(
      state.copyWith(
        status: SectionStatus.loading,
        studentId: studentId,
        clearError: true,
      ),
    );
    final result = await getReviewMonth(
      ReviewMonthParams(
        studentId: studentId,
        hijriYear: state.hijriYear,
        hijriMonth: state.hijriMonth,
      ),
    );
    result.fold(
      (f) => emit(
        state.copyWith(
          status: SectionStatus.error,
          errorMessage: f.message,
        ),
      ),
          (month) =>
          emit(
            state.copyWith(
              status: SectionStatus.loaded,
              month: month,
              clearError: true,
            ),
          ),
    );
  }

  Future<void> _onChangeMonth(
    ChangeReviewMonthEvent event,
    Emitter<ReviewScheduleState> emit,
  ) async {
    var y = state.hijriYear;
    var m = state.hijriMonth + event.delta;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    emit(state.copyWith(hijriYear: y, hijriMonth: m));
    add(LoadReviewMonthEvent(studentId: state.studentId));
  }
}
