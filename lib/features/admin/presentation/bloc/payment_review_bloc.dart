import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/payment_review_amounts.dart';
import '../../domain/entities/admin_operations_entities.dart';
import '../../domain/usecases/admin_operations_usecases.dart';

part 'payment_review_event.dart';
part 'payment_review_state.dart';

/// P0-03 — pending payment proofs for Admin (all) / Supervisor (scoped).
/// Decisions go through the authoritative `reviewPaymentProof` callable only.
@injectable
class PaymentReviewBloc extends Bloc<PaymentReviewEvent, PaymentReviewState> {
  final ListPendingPaymentProofsUseCase listPending;
  final ReviewPaymentProofUseCase reviewProof;
  final PaymentReviewRequestIds _requestIds = PaymentReviewRequestIds();

  PaymentReviewBloc({required this.listPending, required this.reviewProof})
    : super(const PaymentReviewState()) {
    on<LoadPendingProofsEvent>(_onLoad, transformer: restartable());
    on<SubmitPaymentReviewEvent>(_onSubmit, transformer: droppable());
    on<ClearPaymentReviewMessageEvent>(_onClear);
  }

  Future<void> _onLoad(
    LoadPendingProofsEvent event,
    Emitter<PaymentReviewState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SectionStatus.loading,
        reviewerUid: event.reviewerUid,
        isAdmin: event.isAdmin,
      ),
    );
    final result = await listPending(
      PendingPaymentProofsParams(
        reviewerUid: event.reviewerUid,
        isAdmin: event.isAdmin,
      ),
    );
    result.fold(
      (f) =>
          emit(state.copyWith(status: SectionStatus.error, error: f.message)),
      (items) {
        // An unresolved decision survives only while its proof is pending.
        final pendingProofs = {for (final item in items) item.paymentId: item};
        _requestIds.retainWhere((c) {
          final item = pendingProofs[c.paymentId];
          return item != null &&
              c.targetsProof(
                fileName: item.proofFileName,
                proofCycleId: item.proofCycleId,
              );
        });
        emit(
          state.copyWith(
            status: SectionStatus.loaded,
            items: items,
            unresolved: _requestIds.openCommands,
          ),
        );
      },
    );
  }

  /// Set as soon as [close] starts: bloc's event sink closes before
  /// [isClosed] turns true, so [isClosed] alone cannot guard [add].
  bool _closing = false;

  @override
  Future<void> close() {
    _closing = true;
    return super.close();
  }

  void _reload() {
    // The page may have closed while the review was in flight.
    if (_closing || isClosed) return;
    add(
      LoadPendingProofsEvent(
        reviewerUid: state.reviewerUid,
        isAdmin: state.isAdmin,
      ),
    );
  }

  Future<void> _onSubmit(
    SubmitPaymentReviewEvent event,
    Emitter<PaymentReviewState> emit,
  ) async {
    final item = event.item;
    final paymentId = item.paymentId;
    final partial = event.decision == PaymentReviewDecision.partial;
    final command = PaymentReviewCommand(
      paymentId: paymentId,
      decision: event.decision.wire,
      notes: event.notes,
      amountMode: partial ? event.amountMode : null,
      amountMinorUnits: partial ? event.amountMinorUnits : null,
      expectedProofFileName: item.proofFileName ?? '',
      expectedProofCycleId: item.proofCycleId,
    );
    emit(
      state.copyWith(
        submissionStatus: SubmissionStatus.submitting,
        activePaymentId: paymentId,
        clearMessage: true,
      ),
    );
    final result = await reviewProof(
      ReviewPaymentProofParams(
        command: command,
        requestId: _requestIds.idFor(command),
        snapshot: item.amountSnapshot,
      ),
    );
    result.fold(
      (f) {
        final kind = paymentReviewFailureKind(f);
        if (kind != PaymentReviewFailureKind.unresolved) {
          _requestIds.settle(paymentId);
        }
        emit(
          state.copyWith(
            submissionStatus: SubmissionStatus.error,
            message: kind == PaymentReviewFailureKind.noLongerPending
                ? kPaymentNoLongerPendingNotice
                : f.message,
            unresolved: _requestIds.openCommands,
          ),
        );
        // Never re-sent automatically; the reload shows the current proof.
        if (kind == PaymentReviewFailureKind.proofChanged ||
            kind == PaymentReviewFailureKind.noLongerPending) {
          _reload();
        }
      },
      (reviewed) {
        _requestIds.settle(paymentId);
        if (reviewed.replayed) {
          // A stored earlier result: the row may already show a newer proof.
          emit(
            state.copyWith(
              submissionStatus: SubmissionStatus.success,
              message: kPaymentReviewReplayedMessage,
              unresolved: _requestIds.openCommands,
            ),
          );
          _reload();
          return;
        }
        // Only the reviewed cycle leaves the list, never a newer proof.
        emit(
          state.copyWith(
            submissionStatus: SubmissionStatus.success,
            message: 'تم تسجيل قرار المراجعة: ${event.decision.label}',
            items: state.items
                .where(
                  (i) =>
                      i.paymentId != paymentId ||
                      !command.targetsProof(
                        fileName: i.proofFileName,
                        proofCycleId: i.proofCycleId,
                      ),
                )
                .toList(),
            unresolved: _requestIds.openCommands,
          ),
        );
      },
    );
  }

  void _onClear(
    ClearPaymentReviewMessageEvent event,
    Emitter<PaymentReviewState> emit,
  ) {
    emit(
      state.copyWith(
        submissionStatus: SubmissionStatus.idle,
        clearMessage: true,
      ),
    );
  }
}
