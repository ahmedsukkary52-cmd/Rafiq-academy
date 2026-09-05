import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/parent_household.dart';
import '../../domain/parent_wallet.dart';
import '../../domain/repositories/parent_repositories.dart';
import '../../domain/usecases/get_absence_requests_usecase.dart';
import '../../domain/usecases/get_children_ids_usecase.dart';
import '../../domain/usecases/get_halaqat_for_student_usecase.dart';
import '../../domain/usecases/get_parent_household_usecase.dart';
import '../../domain/usecases/get_payments_usecase.dart';
import '../../domain/usecases/get_wallet_usecase.dart';
import '../../domain/usecases/get_weekly_report_usecase.dart';
import '../../domain/usecases/initiate_payment_usecase.dart';
import '../../domain/usecases/pay_payment_from_wallet_usecase.dart';
import '../../domain/usecases/submit_absence_request_usecase.dart';
import '../../domain/usecases/submit_payment_proof_usecase.dart';
import 'parent_event.dart';
import 'parent_state.dart';

/// @singleton لنفس سبب StudentBloc: نافذة ولي الأمر متوقع تتبني بتابات
/// (تقرير، مدفوعات، استئذان)، فالـ Bloc لازم يفضل واحد طول ما هو
/// جوه النافذة.
@singleton
class ParentBloc extends Bloc<ParentEvent, ParentState> {
  final GetChildrenIdsUseCase getChildrenIds;
  final GetWeeklyReportUseCase getWeeklyReport;
  final GetPaymentsUseCase getPayments;
  final GetAbsenceRequestsUseCase getAbsenceRequests;
  final GetHalaqatForStudentUseCase getHalaqatForStudent;
  final SubmitAbsenceRequestUseCase submitAbsenceRequest;
  final InitiatePaymentUseCase initiatePayment;
  final GetParentHouseholdUseCase getHousehold;
  final GetWalletUseCase getWallet;
  final PayPaymentFromWalletUseCase payFromWallet;
  final SubmitPaymentProofUseCase submitPaymentProof;

  ParentBloc({
    required this.getChildrenIds,
    required this.getWeeklyReport,
    required this.getPayments,
    required this.getAbsenceRequests,
    required this.getHalaqatForStudent,
    required this.submitAbsenceRequest,
    required this.initiatePayment,
    required this.getHousehold,
    required this.getWallet,
    required this.payFromWallet,
    required this.submitPaymentProof,
  }) : super(ParentState.initial()) {
    on<LoadChildrenEvent>(_onLoadChildren);
    on<SelectChildEvent>(_onSelectChild);
    on<LoadWeeklyReportEvent>(_onLoadWeeklyReport);
    on<LoadPaymentsEvent>(_onLoadPayments);
    on<LoadAbsenceRequestsEvent>(_onLoadAbsenceRequests);
    on<LoadStudentHalaqatEvent>(_onLoadStudentHalaqat);
    on<SubmitAbsenceRequestEvent>(_onSubmitAbsenceRequest);
    on<ResetAbsenceSubmissionEvent>(_onResetAbsenceSubmission);
    on<InitiatePaymentEvent>(_onInitiatePayment);
    on<ResetPaymentInitiationEvent>(_onResetPaymentInitiation);
    on<LoadWalletEvent>(_onLoadWallet);
    on<PayPaymentFromWalletEvent>(_onPayFromWallet);
    on<ResetWalletPayEvent>(_onResetWalletPay);
    on<SubmitPaymentProofEvent>(_onSubmitPaymentProof);
    on<ResetPaymentProofEvent>(_onResetPaymentProof);
    on<ClearParentSessionEvent>(_onClearSession);
  }

  void _onClearSession(
    ClearParentSessionEvent event,
    Emitter<ParentState> emit,
  ) {
    emit(ParentState.initial());
  }

  // ══════════════════════════════════════════════════════════════════════
  // الأبناء
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadChildren(
    LoadChildrenEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(
        parentId: event.parentId,
        childrenStatus: SectionStatus.loading,
        childrenError: null,
      ),
    );

    final result = await getChildrenIds(ParentIdParams(event.parentId));

    final childrenFailure = result.fold<String?>((f) => f.message, (_) => null);
    if (childrenFailure != null) {
      emit(
        state.copyWith(
          childrenStatus: SectionStatus.error,
          childrenError: childrenFailure,
        ),
      );
      return;
    }

    final children = result.getOrElse((_) => const <String>[]);
    final selected =
        state.selectedChildId ?? (children.isEmpty ? null : children.first);

    emit(
      state.copyWith(
        childrenIds: children,
        selectedChildId: selected,
        childrenError: null,
      ),
    );

    final householdResult = await getHousehold(
      ParentHouseholdParams(parentId: event.parentId, childrenIds: children),
    );
    final paymentsResult = await getPayments(ParentIdParams(event.parentId));
    final walletResult = await getWallet(ParentIdParams(event.parentId));

    final household = householdResult.getOrElse((_) => const ParentHousehold());
    final payments = paymentsResult.getOrElse((_) => const <PaymentEntity>[]);
    final hydrated = ParentHouseholdAssembler.withPayments(
      children: household.children,
      payments: payments,
    );

    emit(
      state.copyWith(
        childrenStatus: householdResult.isLeft()
            ? SectionStatus.error
            : SectionStatus.loaded,
        childrenError: householdResult.fold((f) => f.message, (_) => null),
        childrenSnapshots: hydrated,
        staffContacts: household.staffContacts,
        paymentsStatus: paymentsResult.isLeft()
            ? SectionStatus.error
            : SectionStatus.loaded,
        payments: payments,
        paymentsError: paymentsResult.fold((f) => f.message, (_) => null),
        walletStatus: walletResult.isLeft()
            ? SectionStatus.error
            : SectionStatus.loaded,
        wallet: walletResult.getOrElse(
          (_) => ParentWalletEntity.empty(event.parentId),
        ),
        walletError: walletResult.fold((f) => f.message, (_) => null),
        familySummary: ParentHouseholdAssembler.summarize(
          children: hydrated,
          payments: payments,
        ),
        alerts: ParentHouseholdAssembler.alerts(
          children: hydrated,
          payments: payments,
        ),
      ),
    );

    if (selected != null) {
      add(
        LoadWeeklyReportEvent(
          parentId: event.parentId,
          studentId: selected,
          weekStart: _startOfCurrentWeek(),
        ),
      );
    }
  }

  void _onSelectChild(SelectChildEvent event, Emitter<ParentState> emit) {
    emit(
      state.copyWith(
        selectedChildId: event.studentId,
        reportStatus: SectionStatus.initial,
        weeklyReport: null,
        reportError: null,
      ),
    );

    final parentId = state.parentId.trim();
    if (parentId.isEmpty) return;

    add(
      LoadWeeklyReportEvent(
        parentId: parentId,
        studentId: event.studentId,
        weekStart: _startOfCurrentWeek(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // التقرير الأسبوعي
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadWeeklyReport(
    LoadWeeklyReportEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(reportStatus: SectionStatus.loading, reportError: null),
    );

    final result = await getWeeklyReport(
      WeeklyReportParams(
        parentId: event.parentId,
        studentId: event.studentId,
        weekStart: event.weekStart,
      ),
    );

    // Ignore stale responses after the parent switched children.
    if (state.selectedChildId != null &&
        state.selectedChildId != event.studentId) {
      return;
    }

    result.fold(
      (failure) {
        if (state.selectedChildId != null &&
            state.selectedChildId != event.studentId) {
          return;
        }
        emit(
          state.copyWith(
            reportStatus: SectionStatus.error,
            reportError: failure.message,
          ),
        );
      },
      (report) {
        if (state.selectedChildId != null &&
            state.selectedChildId != event.studentId) {
          return;
        }
        emit(
          state.copyWith(
            reportStatus: SectionStatus.loaded,
            weeklyReport: report,
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // المدفوعات
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadPayments(
    LoadPaymentsEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(
        paymentsStatus: SectionStatus.loading,
        paymentsError: null,
      ),
    );

    final result = await getPayments(ParentIdParams(event.parentId));

    result.fold(
      (failure) => emit(
        state.copyWith(
          paymentsStatus: SectionStatus.error,
          paymentsError: failure.message,
        ),
      ),
      (payments) {
        final hydrated = ParentHouseholdAssembler.withPayments(
          children: state.childrenSnapshots,
          payments: payments,
        );
        emit(
          state.copyWith(
            paymentsStatus: SectionStatus.loaded,
            payments: payments,
            childrenSnapshots: hydrated,
            familySummary: ParentHouseholdAssembler.summarize(
              children: hydrated,
              payments: payments,
            ),
            alerts: ParentHouseholdAssembler.alerts(
              children: hydrated,
              payments: payments,
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // قائمة طلبات الاستئذان
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadAbsenceRequests(
    LoadAbsenceRequestsEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(
        absenceRequestsStatus: SectionStatus.loading,
        absenceRequestsError: null,
        absenceRequestsParentId: event.parentId,
      ),
    );

    final result = await getAbsenceRequests(ParentIdParams(event.parentId));

    if (state.absenceRequestsParentId != null &&
        state.absenceRequestsParentId != event.parentId) {
      return;
    }

    result.fold(
      (failure) {
        if (state.absenceRequestsParentId != null &&
            state.absenceRequestsParentId != event.parentId) {
          return;
        }
        emit(
          state.copyWith(
            absenceRequestsStatus: SectionStatus.error,
            absenceRequestsError: failure.message,
          ),
        );
      },
      (requests) {
        if (state.absenceRequestsParentId != null &&
            state.absenceRequestsParentId != event.parentId) {
          return;
        }
        emit(
          state.copyWith(
            absenceRequestsStatus: SectionStatus.loaded,
            absenceRequests: requests,
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // حلقات الطالب (نموذج الاستئذان)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadStudentHalaqat(
    LoadStudentHalaqatEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(
        studentHalaqatStatus: SectionStatus.loading,
        studentHalaqatError: null,
        studentHalaqat: const [],
        studentHalaqatStudentId: event.studentId,
      ),
    );

    final result = await getHalaqatForStudent(
      StudentHalaqatParams(
        parentId: event.parentId,
        studentId: event.studentId,
      ),
    );

    if (state.studentHalaqatStudentId != null &&
        state.studentHalaqatStudentId != event.studentId) {
      return;
    }

    result.fold(
      (failure) {
        if (state.studentHalaqatStudentId != null &&
            state.studentHalaqatStudentId != event.studentId) {
          return;
        }
        emit(
          state.copyWith(
            studentHalaqatStatus: SectionStatus.error,
            studentHalaqatError: failure.message,
          ),
        );
      },
      (halaqat) {
        if (state.studentHalaqatStudentId != null &&
            state.studentHalaqatStudentId != event.studentId) {
          return;
        }
        emit(
          state.copyWith(
            studentHalaqatStatus: SectionStatus.loaded,
            studentHalaqat: halaqat,
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // تقديم طلب استئذان
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onSubmitAbsenceRequest(
    SubmitAbsenceRequestEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(
        absenceSubmissionStatus: SubmissionStatus.submitting,
        absenceSubmissionError: null,
      ),
    );

    final result = await submitAbsenceRequest(event.request);

    result.fold(
      (failure) => emit(
        state.copyWith(
          absenceSubmissionStatus: SubmissionStatus.error,
          absenceSubmissionError: failure.message,
        ),
      ),
      (_) {
        emit(state.copyWith(absenceSubmissionStatus: SubmissionStatus.success));
        final parentId =
            state.absenceRequestsParentId ?? event.request.requestedBy.trim();
        if (parentId.isNotEmpty) {
          add(LoadAbsenceRequestsEvent(parentId));
        }
      },
    );
  }

  void _onResetAbsenceSubmission(
    ResetAbsenceSubmissionEvent event,
    Emitter<ParentState> emit,
  ) {
    emit(
      state.copyWith(
        absenceSubmissionStatus: SubmissionStatus.idle,
        absenceSubmissionError: null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // بدء عملية دفع (Paymob عن طريق Cloud Function)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onInitiatePayment(
    InitiatePaymentEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(
        paymentInitiationStatus: SubmissionStatus.submitting,
        paymentInitiationError: null,
      ),
    );

    final result = await initiatePayment(PaymentIdParams(event.paymentId));

    result.fold(
      (failure) => emit(
        state.copyWith(
          paymentInitiationStatus: SubmissionStatus.error,
          paymentInitiationError: failure.message,
        ),
      ),
      // الـ UI هيستخدم paymentInitiation.checkoutUrl عشان يفتح صفحة
      // الدفع (WebView مثلاً) لما نبني الشاشات.
      (initiation) => emit(
        state.copyWith(
          paymentInitiationStatus: SubmissionStatus.success,
          paymentInitiation: initiation,
        ),
      ),
    );
  }

  void _onResetPaymentInitiation(
    ResetPaymentInitiationEvent event,
    Emitter<ParentState> emit,
  ) {
    emit(
      state.copyWith(
        paymentInitiationStatus: SubmissionStatus.idle,
        paymentInitiation: null,
        paymentInitiationError: null,
      ),
    );
  }

  Future<void> _onLoadWallet(
    LoadWalletEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(walletStatus: SectionStatus.loading, walletError: null),
    );
    final result = await getWallet(ParentIdParams(event.parentId));
    result.fold(
      (failure) => emit(
        state.copyWith(
          walletStatus: SectionStatus.error,
          walletError: failure.message,
          wallet: ParentWalletEntity.empty(event.parentId),
        ),
      ),
      (wallet) => emit(
        state.copyWith(walletStatus: SectionStatus.loaded, wallet: wallet),
      ),
    );
  }

  Future<void> _onPayFromWallet(
    PayPaymentFromWalletEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(
        walletPayStatus: SubmissionStatus.submitting,
        walletPayError: null,
      ),
    );

    final result = await payFromWallet(
      PayPaymentFromWalletParams(
        parentId: event.parentId,
        paymentId: event.paymentId,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          walletPayStatus: SubmissionStatus.error,
          walletPayError: failure.message,
        ),
      ),
      (_) {
        emit(state.copyWith(walletPayStatus: SubmissionStatus.success));
        add(LoadPaymentsEvent(event.parentId));
        add(LoadWalletEvent(event.parentId));
      },
    );
  }

  void _onResetWalletPay(ResetWalletPayEvent event, Emitter<ParentState> emit) {
    emit(
      state.copyWith(
        walletPayStatus: SubmissionStatus.idle,
        walletPayError: null,
      ),
    );
  }

  Future<void> _onSubmitPaymentProof(
    SubmitPaymentProofEvent event,
    Emitter<ParentState> emit,
  ) async {
    emit(
      state.copyWith(
        paymentProofStatus: SubmissionStatus.submitting,
        paymentProofError: null,
        paymentProofPaymentId: event.paymentId,
      ),
    );

    final result = await submitPaymentProof(
      SubmitPaymentProofParams(
        parentId: event.parentId,
        paymentId: event.paymentId,
        localFilePath: event.localFilePath,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          paymentProofStatus: SubmissionStatus.error,
          paymentProofError: failure.message,
        ),
      ),
      (_) {
        emit(state.copyWith(paymentProofStatus: SubmissionStatus.success));
        add(LoadPaymentsEvent(event.parentId));
      },
    );
  }

  void _onResetPaymentProof(
    ResetPaymentProofEvent event,
    Emitter<ParentState> emit,
  ) {
    emit(
      state.copyWith(
        paymentProofStatus: SubmissionStatus.idle,
        paymentProofError: null,
        paymentProofPaymentId: null,
      ),
    );
  }

  /// بداية الأسبوع الحالي (السبت، حسب بداية الأسبوع الدراسي في مصر).
  /// لو حبينا نغيّرها لاحقاً (الاثنين مثلاً) هنا المكان الوحيد اللي نعدّله.
  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    // DateTime.weekday: 1=Monday ... 7=Sunday. السبت = 6.
    final daysSinceSaturday = (now.weekday - DateTime.saturday + 7) % 7;
    final today = AttendancePolicy.dayStart(now);
    return today.subtract(Duration(days: daysSinceSaturday));
  }
}
