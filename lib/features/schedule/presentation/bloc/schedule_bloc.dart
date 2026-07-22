import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/usecases/usecases.dart';
import '../../domain/entities/class_session_entity.dart';
import '../../domain/usecases/get_weekly_sessions_usecase.dart';

part 'schedule_event.dart';

part 'schedule_state.dart';

@injectable
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final GetWeeklySessionsUseCase getWeeklySessions;

  ScheduleBloc(this.getWeeklySessions) : super(const ScheduleState()) {
    on<LoadWeeklySessionsEvent>(_onLoad);
  }

  Future<void> _onLoad(
    LoadWeeklySessionsEvent event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(state.copyWith(status: SectionStatus.loading));
    final result = await getWeeklySessions(const NoParams());
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SectionStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (sessions) => emit(
        state.copyWith(status: SectionStatus.loaded, sessions: sessions),
      ),
    );
  }
}
