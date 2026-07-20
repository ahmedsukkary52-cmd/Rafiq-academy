import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/usecases/analytics_usecases.dart';
import 'analytics_event.dart';
import 'analytics_state.dart';

/// @injectable لأن لوحة التحليلات بتتفتح لحلقة محددة في كل مرة
@injectable
class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final GetHalaqaAnalyticsUseCase getHalaqaAnalytics;
  final GetAtRiskStudentsUseCase getAtRiskStudents;
  final GetTopStudentsUseCase getTopStudents;

  AnalyticsBloc({
    required this.getHalaqaAnalytics,
    required this.getAtRiskStudents,
    required this.getTopStudents,
  }) : super(AnalyticsState.initial()) {
    on<LoadHalaqaAnalyticsDashboardEvent>(_onLoadDashboard);
    on<RefreshAnalyticsEvent>(_onRefresh);
  }

  Future<void> _onLoadDashboard(LoadHalaqaAnalyticsDashboardEvent event,
      Emitter<AnalyticsState> emit,) async {
    // نبدأ كل الأقسام بـ loading مع بعض
    emit(state.copyWith(
      analyticsStatus: SectionStatus.loading,
      atRiskStatus: SectionStatus.loading,
      topStudentsStatus: SectionStatus.loading,
    ));

    // نجيب الثلاث قطع بالتوازي - أسرع من التتابع
    await Future.wait([
      _loadAnalytics(event, emit),
      _loadAtRisk(event.halaqaId, emit),
      _loadTopStudents(event.halaqaId, emit),
    ]);
  }

  Future<void> _onRefresh(RefreshAnalyticsEvent event,
      Emitter<AnalyticsState> emit,) async {
    final now = DateTime.now();
    final oneMonth = now.subtract(const Duration(days: 30));

    add(LoadHalaqaAnalyticsDashboardEvent(
      halaqaId: event.halaqaId,
      from: oneMonth,
      to: now,
    ));
  }

  Future<void> _loadAnalytics(LoadHalaqaAnalyticsDashboardEvent event,
      Emitter<AnalyticsState> emit,) async {
    final result = await getHalaqaAnalytics(HalaqaAnalyticsParams(
      halaqaId: event.halaqaId,
      from: event.from,
      to: event.to,
    ));

    result.fold(
          (failure) =>
          emit(state.copyWith(
            analyticsStatus: SectionStatus.error,
            analyticsError: failure.message,
          )),
          (analytics) =>
          emit(state.copyWith(
            analyticsStatus: SectionStatus.loaded,
            analytics: analytics,
          )),
    );
  }

  Future<void> _loadAtRisk(String halaqaId,
      Emitter<AnalyticsState> emit,) async {
    final result = await getAtRiskStudents(HalaqaIdParams(halaqaId));

    result.fold(
          (failure) =>
          emit(state.copyWith(
            atRiskStatus: SectionStatus.error,
            atRiskError: failure.message,
          )),
          (students) =>
          emit(state.copyWith(
            atRiskStatus: SectionStatus.loaded,
            atRiskStudents: students,
          )),
    );
  }

  Future<void> _loadTopStudents(String halaqaId,
      Emitter<AnalyticsState> emit,) async {
    final result = await getTopStudents(
      TopStudentsParams(halaqaId: halaqaId, limit: 5),
    );

    result.fold(
          (failure) =>
          emit(state.copyWith(
            topStudentsStatus: SectionStatus.error,
            topStudentsError: failure.message,
          )),
          (students) =>
          emit(state.copyWith(
            topStudentsStatus: SectionStatus.loaded,
            topStudents: students,
          )),
    );
  }
}