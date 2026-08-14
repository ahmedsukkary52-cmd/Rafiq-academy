import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/usecases/awards_usecases.dart';
import 'awards_event.dart';
import 'awards_state.dart';

/// @injectable لأنه مرتبط بحلقة معيّنة
@injectable
class AwardsBloc extends Bloc<AwardsEvent, AwardsState> {
  final GetAwardsStatsUseCase getAwardsStats;
  final GetGrantedAwardsUseCase getGrantedAwards;
  final GrantAwardUseCase grantAward;
  final GenerateCertificatePdfUseCase generateCertificatePdf;

  AwardsBloc({
    required this.getAwardsStats,
    required this.getGrantedAwards,
    required this.grantAward,
    required this.generateCertificatePdf,
  }) : super(AwardsState.initial()) {
    on<LoadAwardsDashboardEvent>(_onLoadDashboard);
    on<GrantAwardEvent>(_onGrantAward);
    on<ResetGrantAwardEvent>(_onResetGrantAward);
    on<GenerateCertificateEvent>(_onGenerateCertificate);
    on<ResetCertificateEvent>(_onResetCertificate);
  }

  Future<void> _onLoadDashboard(
    LoadAwardsDashboardEvent event,
    Emitter<AwardsState> emit,
  ) async {
    emit(
      state.copyWith(
        dashboardHalaqaId: event.halaqaId,
        statsStatus: SectionStatus.loading,
        awardsStatus: SectionStatus.loading,
      ),
    );

    // الإحصائيات والسجل بالتوازي
    await Future.wait([
      _loadStats(event.halaqaId, emit),
      _loadGrantedAwards(event.halaqaId, emit),
    ]);
  }

  Future<void> _loadStats(String halaqaId, Emitter<AwardsState> emit) async {
    final result = await getAwardsStats(HalaqaIdParams(halaqaId));
    result.fold(
      (failure) => emit(
        state.copyWith(
          statsStatus: SectionStatus.error,
          statsError: failure.message,
        ),
      ),
      (stats) =>
          emit(state.copyWith(statsStatus: SectionStatus.loaded, stats: stats)),
    );
  }

  Future<void> _loadGrantedAwards(
    String halaqaId,
    Emitter<AwardsState> emit,
  ) async {
    final result = await getGrantedAwards(HalaqaIdParams(halaqaId));
    result.fold(
      (failure) => emit(
        state.copyWith(
          awardsStatus: SectionStatus.error,
          awardsError: failure.message,
        ),
      ),
      (awards) => emit(
        state.copyWith(
          awardsStatus: SectionStatus.loaded,
          grantedAwards: awards,
        ),
      ),
    );
  }

  Future<void> _onGrantAward(
    GrantAwardEvent event,
    Emitter<AwardsState> emit,
  ) async {
    emit(
      state.copyWith(
        grantStatus: SubmissionStatus.submitting,
        grantError: null,
      ),
    );

    final result = await grantAward(event.award);

    result.fold(
      (failure) => emit(
        state.copyWith(
          grantStatus: SubmissionStatus.error,
          grantError: failure.message,
        ),
      ),
      (_) async {
        emit(state.copyWith(grantStatus: SubmissionStatus.success));
        final scope = state.dashboardHalaqaId ?? event.award.halaqaId;
        await Future.wait([
          _loadStats(scope, emit),
          _loadGrantedAwards(scope, emit),
        ]);
      },
    );
  }

  void _onResetGrantAward(
    ResetGrantAwardEvent event,
    Emitter<AwardsState> emit,
  ) {
    emit(state.copyWith(grantStatus: SubmissionStatus.idle, grantError: null));
  }

  Future<void> _onGenerateCertificate(
    GenerateCertificateEvent event,
    Emitter<AwardsState> emit,
  ) async {
    emit(
      state.copyWith(
        certificateStatus: SubmissionStatus.submitting,
        certificateBytes: null,
        certificateError: null,
      ),
    );

    final result = await generateCertificatePdf(event.data);

    result.fold(
      (failure) => emit(
        state.copyWith(
          certificateStatus: SubmissionStatus.error,
          certificateError: failure.message,
        ),
      ),
      (bytes) => emit(
        state.copyWith(
          certificateStatus: SubmissionStatus.success,
          certificateBytes: bytes,
          // الـ UI هيلاحظ إن certificateBytes != null ويفتح
          // Printing.layoutPdf() أو Printing.sharePdf() تلقائياً
        ),
      ),
    );
  }

  void _onResetCertificate(
    ResetCertificateEvent event,
    Emitter<AwardsState> emit,
  ) {
    emit(
      state.copyWith(
        certificateStatus: SubmissionStatus.idle,
        certificateBytes: null,
        certificateError: null,
      ),
    );
  }
}
