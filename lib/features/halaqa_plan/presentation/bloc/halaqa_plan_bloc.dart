import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/halaqa_plan.dart';
import '../../domain/usecases/get_student_halaqa_plan_usecase.dart';

sealed class HalaqaPlanEvent extends Equatable {
  const HalaqaPlanEvent();

  @override
  List<Object?> get props => [];
}

class LoadStudentHalaqaPlanEvent extends HalaqaPlanEvent {
  final String studentId;
  final String? halaqaId;

  const LoadStudentHalaqaPlanEvent({required this.studentId, this.halaqaId});

  @override
  List<Object?> get props => [studentId, halaqaId];
}

class HalaqaPlanState extends Equatable {
  final SectionStatus status;
  final HalaqaPlan? plan;
  final String? error;

  const HalaqaPlanState({
    this.status = SectionStatus.initial,
    this.plan,
    this.error,
  });

  @override
  List<Object?> get props => [status, plan, error];
}

/// §9–14 «خطة الحلقة / تقدمي في الحلقة» — read-only projection.
@injectable
class HalaqaPlanBloc extends Bloc<HalaqaPlanEvent, HalaqaPlanState> {
  final GetStudentHalaqaPlanUseCase getPlan;

  HalaqaPlanBloc({required this.getPlan}) : super(const HalaqaPlanState()) {
    on<LoadStudentHalaqaPlanEvent>(_onLoad, transformer: restartable());
  }

  Future<void> _onLoad(
    LoadStudentHalaqaPlanEvent event,
    Emitter<HalaqaPlanState> emit,
  ) async {
    emit(HalaqaPlanState(status: SectionStatus.loading, plan: state.plan));
    final result = await getPlan(
      StudentHalaqaPlanParams(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
      ),
    );
    result.fold(
      (f) => emit(
        HalaqaPlanState(
          status: SectionStatus.error,
          plan: state.plan,
          error: f.message,
        ),
      ),
      (plan) => emit(HalaqaPlanState(status: SectionStatus.loaded, plan: plan)),
    );
  }
}
