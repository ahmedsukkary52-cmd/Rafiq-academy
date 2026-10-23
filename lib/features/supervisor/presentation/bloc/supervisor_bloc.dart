import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/payment_review_amounts.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../parent/domain/parent_payment_proof.dart';
import '../../domain/entities/payment_review_params.dart';
import '../../domain/repositories/parent_repository.dart';
import '../../domain/usecases/admit_student_to_halaqa_usecase.dart';
import '../../domain/usecases/get_supervised_absence_requests_usecase.dart';
import '../../domain/usecases/get_supervised_halaqat_usecase.dart';
import '../../domain/usecases/get_supervisor_day_board_usecase.dart';
import '../../domain/usecases/issue_achievement_usecase.dart';
import '../../domain/usecases/payment_review_usecases.dart';
import '../../domain/usecases/register_new_student_usecase.dart';
import '../../domain/usecases/submit_supervisor_report_usecase.dart';
import '../../domain/usecases/transfer_student_between_halaqat_usecase.dart';
import 'supervisor_event.dart';
import 'supervisor_state.dart';

@singleton
class SupervisorBloc extends Bloc<SupervisorEvent, SupervisorState> {
  final GetSupervisedHalaqatUseCase getSupervisedHalaqat;
  final GetSupervisorDayBoardUseCase getSupervisorDayBoard;
  final GetSupervisedAbsenceRequestsUseCase getSupervisedAbsenceRequests;
  final IssueAchievementUseCase issueAchievement;
  final SubmitSupervisorReportUseCase submitSupervisorReport;
  final AdmitStudentToHalaqaUseCase admitStudentToHalaqa;
  final TransferStudentBetweenHalaqatUseCase transferStudentBetweenHalaqat;
  final GetSupervisedPaymentsUseCase getSupervisedPayments;
  final ReviewPaymentProofUseCase reviewPaymentProof;
  final RegisterNewStudentUseCase registerNewStudent;

  String? _supervisorId;
  final PaymentReviewRequestIds _reviewRequestIds = PaymentReviewRequestIds();

  /// Bumped on every session clear; in-flight results of an older session
  /// are dropped.
  int _session = 0;

  /// Set as soon as [close] starts: bloc's event sink closes before
  /// [isClosed] turns true, so [isClosed] alone cannot guard [add].
  bool _closing = false;

  @override
  Future<void> close() {
    _closing = true;
    return super.close();
  }

  SupervisorBloc({
    required this.getSupervisedHalaqat,
    required this.getSupervisorDayBoard,
    required this.getSupervisedAbsenceRequests,
    required this.issueAchievement,
    required this.submitSupervisorReport,
    required this.admitStudentToHalaqa,
    required this.transferStudentBetweenHalaqat,
    required this.getSupervisedPayments,
    required this.reviewPaymentProof,
    required this.registerNewStudent,
  }) : super(SupervisorState.initial()) {
    on<LoadSupervisedHalaqatEvent>(_onLoadHalaqat);
    on<LoadSupervisorDayBoardEvent>(_onLoadDayBoard);
    on<LoadSupervisedAbsenceRequestsEvent>(_onLoadAbsenceRequests);
    on<IssueAchievementEvent>(_onIssueAchievement, transformer: droppable());
    on<ResetIssueAchievementEvent>(_onResetIssueAchievement);
    on<SubmitSupervisorReportEvent>(_onSubmitReport);
    on<ResetSubmitReportEvent>(_onResetSubmitReport);
    on<AdmitStudentToHalaqaEvent>(_onAdmitStudent);
    on<ResetAdmitStudentEvent>(_onResetAdmitStudent);
    on<TransferStudentBetweenHalaqatEvent>(_onTransferStudent);
    on<ResetTransferStudentEvent>(_onResetTransferStudent);
    on<LoadSupervisedPaymentsEvent>(_onLoadPayments);
    on<ReviewPaymentProofEvent>(_onReviewPayment);
    on<ResetReviewPaymentEvent>(_onResetReviewPayment);
    on<RegisterNewStudentEvent>(_onRegisterStudent);
    on<ResetRegisterStudentEvent>(_onResetRegisterStudent);
    on<ClearSupervisorSessionEvent>(_onClearSession);
  }

  void _onClearSession(
    ClearSupervisorSessionEvent event,
    Emitter<SupervisorState> emit,
  ) {
    _session++;
    _supervisorId = null;
    _reviewRequestIds.clear();
    emit(SupervisorState.initial());
  }

  Future<void> _onLoadHalaqat(
    LoadSupervisedHalaqatEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    _supervisorId = event.supervisorId;
    emit(
      state.copyWith(halaqatStatus: SectionStatus.loading, halaqatError: null),
    );

    final result = await getSupervisedHalaqat(
      SupervisorIdParams(event.supervisorId),
    );

    await result.fold(
      (failure) async => emit(
        state.copyWith(
          halaqatStatus: SectionStatus.error,
          halaqatError: failure.message,
        ),
      ),
      (halaqat) async {
        emit(
          state.copyWith(halaqatStatus: SectionStatus.loaded, halaqat: halaqat),
        );
        await _deriveDayBoard(emit);
        add(
          LoadSupervisedAbsenceRequestsEvent(
            supervisorId: event.supervisorId,
            date: DateTime.now(),
          ),
        );
      },
    );
  }

  Future<void> _onLoadDayBoard(
    LoadSupervisorDayBoardEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    await _deriveDayBoard(emit);
    final supervisorId = _supervisorId;
    if (supervisorId != null) {
      add(
        LoadSupervisedAbsenceRequestsEvent(
          supervisorId: supervisorId,
          date: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _deriveDayBoard(Emitter<SupervisorState> emit) async {
    emit(
      state.copyWith(
        dayBoardStatus: SectionStatus.loading,
        dayBoardError: null,
      ),
    );

    final result = await getSupervisorDayBoard(
      SupervisorDayBoardParams(halaqat: state.halaqat),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          dayBoardStatus: SectionStatus.error,
          dayBoardError: failure.message,
        ),
      ),
      (board) => emit(
        state.copyWith(dayBoardStatus: SectionStatus.loaded, dayBoard: board),
      ),
    );
  }

  Future<void> _onLoadAbsenceRequests(
    LoadSupervisedAbsenceRequestsEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        absenceRequestsStatus: SectionStatus.loading,
        absenceRequestsError: null,
      ),
    );

    final result = await getSupervisedAbsenceRequests(
      SupervisedAbsenceRequestsParams(
        supervisorId: event.supervisorId,
        date: event.date,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          absenceRequestsStatus: SectionStatus.error,
          absenceRequestsError: failure.message,
        ),
      ),
      (requests) => emit(
        state.copyWith(
          absenceRequestsStatus: SectionStatus.loaded,
          absenceRequests: requests,
        ),
      ),
    );
  }

  Future<void> _onIssueAchievement(
    IssueAchievementEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        issueAchievementStatus: SubmissionStatus.submitting,
        issueAchievementError: null,
      ),
    );

    final result = await issueAchievement(event.data);

    result.fold(
      (failure) => emit(
        state.copyWith(
          issueAchievementStatus: SubmissionStatus.error,
          issueAchievementError: failure.message,
        ),
      ),
      (_) => emit(
        state.copyWith(issueAchievementStatus: SubmissionStatus.success),
      ),
    );
  }

  void _onResetIssueAchievement(
    ResetIssueAchievementEvent event,
    Emitter<SupervisorState> emit,
  ) {
    emit(
      state.copyWith(
        issueAchievementStatus: SubmissionStatus.idle,
        issueAchievementError: null,
      ),
    );
  }

  Future<void> _onSubmitReport(
    SubmitSupervisorReportEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        submitReportStatus: SubmissionStatus.submitting,
        submitReportError: null,
      ),
    );

    final result = await submitSupervisorReport(event.report);

    result.fold(
      (failure) => emit(
        state.copyWith(
          submitReportStatus: SubmissionStatus.error,
          submitReportError: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(submitReportStatus: SubmissionStatus.success)),
    );
  }

  void _onResetSubmitReport(
    ResetSubmitReportEvent event,
    Emitter<SupervisorState> emit,
  ) {
    emit(
      state.copyWith(
        submitReportStatus: SubmissionStatus.idle,
        submitReportError: null,
      ),
    );
  }

  Future<void> _onAdmitStudent(
    AdmitStudentToHalaqaEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        admitStudentStatus: SubmissionStatus.submitting,
        admitStudentError: null,
      ),
    );

    final result = await admitStudentToHalaqa(
      AdmitStudentParams(
        supervisorId: event.supervisorId,
        halaqaId: event.halaqaId,
        studentId: event.studentId,
      ),
    );

    await result.fold(
      (failure) async => emit(
        state.copyWith(
          admitStudentStatus: SubmissionStatus.error,
          admitStudentError: failure.message,
        ),
      ),
      (_) async {
        emit(state.copyWith(admitStudentStatus: SubmissionStatus.success));
        add(LoadSupervisedHalaqatEvent(event.supervisorId));
      },
    );
  }

  void _onResetAdmitStudent(
    ResetAdmitStudentEvent event,
    Emitter<SupervisorState> emit,
  ) {
    emit(
      state.copyWith(
        admitStudentStatus: SubmissionStatus.idle,
        admitStudentError: null,
      ),
    );
  }

  Future<void> _onTransferStudent(
    TransferStudentBetweenHalaqatEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        transferStudentStatus: SubmissionStatus.submitting,
        transferStudentError: null,
      ),
    );

    final result = await transferStudentBetweenHalaqat(
      TransferStudentParams(
        supervisorId: event.supervisorId,
        studentId: event.studentId,
        sourceHalaqaId: event.sourceHalaqaId,
        targetHalaqaId: event.targetHalaqaId,
      ),
    );

    await result.fold(
      (failure) async => emit(
        state.copyWith(
          transferStudentStatus: SubmissionStatus.error,
          transferStudentError: failure.message,
        ),
      ),
      (_) async {
        emit(state.copyWith(transferStudentStatus: SubmissionStatus.success));
        add(LoadSupervisedHalaqatEvent(event.supervisorId));
      },
    );
  }

  void _onResetTransferStudent(
    ResetTransferStudentEvent event,
    Emitter<SupervisorState> emit,
  ) {
    emit(
      state.copyWith(
        transferStudentStatus: SubmissionStatus.idle,
        transferStudentError: null,
      ),
    );
  }

  Future<void> _onLoadPayments(
    LoadSupervisedPaymentsEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        paymentsStatus: SectionStatus.loading,
        paymentsError: null,
      ),
    );
    final result = await getSupervisedPayments(
      SupervisedPaymentsParams(
        supervisorId: event.supervisorId,
        studentIds: event.studentIds,
      ),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          paymentsStatus: SectionStatus.error,
          paymentsError: failure.message,
        ),
      ),
      (payments) {
        // A loaded payment now showing another proof cycle (or no longer
        // pending) invalidates its unresolved decision.
        final loaded = {for (final p in payments) p.id: p};
        _reviewRequestIds.retainWhere((c) {
          final p = loaded[c.paymentId];
          if (p == null) return true;
          return p.status != PaymentStatus.paid &&
              p.reviewStatus?.trim() ==
                  ParentPaymentProofContract.pendingReview &&
              c.targetsProof(
                fileName: p.proofFileName,
                proofCycleId: p.proofCycleId,
              );
        });
        emit(
          state.copyWith(
            paymentsStatus: SectionStatus.loaded,
            payments: payments,
            paymentsError: null,
            reviewPaymentUnresolved: _reviewRequestIds.openCommands,
          ),
        );
      },
    );
  }

  Future<void> _onReviewPayment(
    ReviewPaymentProofEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    // Droppable semantics (screens block and explain a second review); the
    // check and the `submitting` emit both run before the first await.
    if (state.reviewPaymentStatus == SubmissionStatus.submitting) return;
    final session = _session;
    final command = event.command;
    final paymentId = command.paymentId;
    emit(
      state.copyWith(
        reviewPaymentStatus: SubmissionStatus.submitting,
        reviewPaymentId: paymentId,
        reviewPaymentError: null,
        reviewPaymentMessage: null,
      ),
    );

    // A result that arrives after the session was cleared (or the bloc
    // closed) belongs to nobody on screen now.
    bool stale() => session != _session || _closing || isClosed;

    final Either<Failure, PaymentReviewResult> result;
    try {
      result = await reviewPaymentProof(
        PaymentReviewParams(
          supervisorId: event.supervisorId,
          command: command,
          requestId: _reviewRequestIds.idFor(command),
          snapshot: event.snapshot,
        ),
      );
    } catch (error, stackTrace) {
      // Outcome unknown: keep the command (same requestId on retry), release
      // the busy state, and report the error instead of swallowing it.
      if (!stale()) {
        emit(
          state.copyWith(
            reviewPaymentStatus: SubmissionStatus.error,
            reviewPaymentError: 'تعذر التأكد من حفظ المراجعة — أعد المحاولة',
            reviewPaymentUnresolved: _reviewRequestIds.openCommands,
          ),
        );
      }
      addError(error, stackTrace);
      return;
    }
    if (stale()) return;

    void reloadPayments() {
      if (_closing || isClosed) return;
      final studentIds = {
        for (final h in state.halaqat) ...h.studentIds,
      }.toList();
      add(
        LoadSupervisedPaymentsEvent(
          supervisorId: event.supervisorId,
          studentIds: studentIds,
        ),
      );
    }

    result.fold(
      (failure) {
        final kind = paymentReviewFailureKind(failure);
        if (kind != PaymentReviewFailureKind.unresolved) {
          _reviewRequestIds.settle(paymentId);
        }
        emit(
          state.copyWith(
            reviewPaymentStatus: SubmissionStatus.error,
            reviewPaymentError: kind == PaymentReviewFailureKind.noLongerPending
                ? kPaymentNoLongerPendingNotice
                : failure.message,
            reviewPaymentUnresolved: _reviewRequestIds.openCommands,
          ),
        );
        // Never re-sent automatically; the reload shows the current proof.
        if (kind == PaymentReviewFailureKind.proofChanged ||
            kind == PaymentReviewFailureKind.noLongerPending) {
          reloadPayments();
        }
      },
      (reviewed) {
        _reviewRequestIds.settle(paymentId);
        emit(
          state.copyWith(
            reviewPaymentStatus: SubmissionStatus.success,
            reviewPaymentMessage: reviewed.replayed
                ? kPaymentReviewReplayedMessage
                : 'تم حفظ نتيجة المراجعة',
            reviewPaymentUnresolved: _reviewRequestIds.openCommands,
          ),
        );
        reloadPayments();
      },
    );
  }

  void _onResetReviewPayment(
    ResetReviewPaymentEvent event,
    Emitter<SupervisorState> emit,
  ) {
    // Never releases an in-flight review's busy state.
    if (state.reviewPaymentStatus == SubmissionStatus.submitting) return;
    emit(
      state.copyWith(
        reviewPaymentStatus: SubmissionStatus.idle,
        reviewPaymentError: null,
        reviewPaymentId: null,
        reviewPaymentMessage: null,
      ),
    );
  }

  Future<void> _onRegisterStudent(
    RegisterNewStudentEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        registerStudentStatus: SubmissionStatus.submitting,
        registerStudentError: null,
      ),
    );

    final result = await registerNewStudent(
      RegisterStudentParams(
        halaqaId: event.halaqaId,
        studentId: event.studentId,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          registerStudentStatus: SubmissionStatus.error,
          registerStudentError: failure.message,
        ),
      ),
      (_) =>
          emit(state.copyWith(registerStudentStatus: SubmissionStatus.success)),
    );
  }

  void _onResetRegisterStudent(
    ResetRegisterStudentEvent event,
    Emitter<SupervisorState> emit,
  ) {
    emit(
      state.copyWith(
        registerStudentStatus: SubmissionStatus.idle,
        registerStudentError: null,
      ),
    );
  }
}
