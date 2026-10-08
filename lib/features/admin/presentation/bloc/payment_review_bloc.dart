import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
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
      (items) =>
          emit(state.copyWith(status: SectionStatus.loaded, items: items)),
    );
  }

  Future<void> _onSubmit(
    SubmitPaymentReviewEvent event,
    Emitter<PaymentReviewState> emit,
  ) async {
    final paymentId = event.item.paymentId;
    emit(
      state.copyWith(
        submissionStatus: SubmissionStatus.submitting,
        activePaymentId: paymentId,
        clearMessage: true,
      ),
    );
    final result = await reviewProof(
      ReviewPaymentProofParams(
        paymentId: paymentId,
        decision: event.decision,
        invoiceAmount: event.item.amount,
        notes: event.notes,
        amountPaidConfirmed: event.amountPaidConfirmed,
      ),
    );
    result.fold(
      (f) => emit(
        state.copyWith(
          submissionStatus: SubmissionStatus.error,
          message: f.message,
        ),
      ),
      // A reviewed proof leaves the pending list; a reload reflects any
      // concurrent review (the server is authoritative).
      (_) => emit(
        state.copyWith(
          submissionStatus: SubmissionStatus.success,
          message: 'تم تسجيل قرار المراجعة: ${event.decision.label}',
          items: state.items.where((i) => i.paymentId != paymentId).toList(),
        ),
      ),
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
