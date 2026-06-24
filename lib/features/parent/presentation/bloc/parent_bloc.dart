import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/repositories/parent_repositories.dart';
import '../../domain/usecases/get_children_ids_usecase.dart';
import '../../domain/usecases/get_payments_usecase.dart';
import '../../domain/usecases/get_weekly_report_usecase.dart';
import '../../domain/usecases/initiate_payment_usecase.dart';
import '../../domain/usecases/submit_absence_request_usecase.dart';
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
  final SubmitAbsenceRequestUseCase submitAbsenceRequest;
  final InitiatePaymentUseCase initiatePayment;

  ParentBloc({
    required this.getChildrenIds,
    required this.getWeeklyReport,
    required this.getPayments,
    required this.submitAbsenceRequest,
    required this.initiatePayment,
  }) : super(ParentState.initial()) {
    on<LoadChildrenEvent>(_onLoadChildren);
    on<SelectChildEvent>(_onSelectChild);
    on<LoadWeeklyReportEvent>(_onLoadWeeklyReport);
    on<LoadPaymentsEvent>(_onLoadPayments);
    on<SubmitAbsenceRequestEvent>(_onSubmitAbsenceRequest);
    on<ResetAbsenceSubmissionEvent>(_onResetAbsenceSubmission);
    on<InitiatePaymentEvent>(_onInitiatePayment);
    on<ResetPaymentInitiationEvent>(_onResetPaymentInitiation);
  }

  // ══════════════════════════════════════════════════════════════════════
  // الأبناء
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadChildren(LoadChildrenEvent event,
      Emitter<ParentState> emit,) async {
    emit(state.copyWith(
      childrenStatus: SectionStatus.loading,
      childrenError: null,
    ));

    final result = await getChildrenIds(ParentIdParams(event.parentId));

    result.fold(
          (failure) =>
          emit(state.copyWith(
            childrenStatus: SectionStatus.error,
            childrenError: failure.message,
          )),
          (children) {
        emit(state.copyWith(
          childrenStatus: SectionStatus.loaded,
          childrenIds: children,
          // أول ابن في القائمة يتحدد تلقائياً كـ "محدد حالياً" لو مفيش
          // اختيار سابق، عشان الشاشة متفضلش فاضية لحد ما المستخدم يختار.
          selectedChildId: state.selectedChildId ??
              (children.isEmpty ? null : children.first),
        ));
      },
    );
  }

  void _onSelectChild(SelectChildEvent event, Emitter<ParentState> emit) {
    emit(state.copyWith(selectedChildId: event.studentId));

    add(LoadWeeklyReportEvent(
      studentId: event.studentId,
      weekStart: _startOfCurrentWeek(),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════
  // التقرير الأسبوعي
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadWeeklyReport(LoadWeeklyReportEvent event,
      Emitter<ParentState> emit,) async {
    emit(state.copyWith(
      reportStatus: SectionStatus.loading,
      reportError: null,
    ));

    final result = await getWeeklyReport(
      WeeklyReportParams(
          studentId: event.studentId, weekStart: event.weekStart),
    );

    result.fold(
          (failure) =>
          emit(state.copyWith(
            reportStatus: SectionStatus.error,
            reportError: failure.message,
          )),
          (report) =>
          emit(state.copyWith(
            reportStatus: SectionStatus.loaded,
            weeklyReport: report,
          )),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // المدفوعات
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadPayments(LoadPaymentsEvent event,
      Emitter<ParentState> emit,) async {
    emit(state.copyWith(
      paymentsStatus: SectionStatus.loading,
      paymentsError: null,
    ));

    final result = await getPayments(ParentIdParams(event.parentId));

    result.fold(
          (failure) =>
          emit(state.copyWith(
            paymentsStatus: SectionStatus.error,
            paymentsError: failure.message,
          )),
          (payments) =>
          emit(state.copyWith(
            paymentsStatus: SectionStatus.loaded,
            payments: payments,
          )),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // تقديم طلب استئذان
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onSubmitAbsenceRequest(SubmitAbsenceRequestEvent event,
      Emitter<ParentState> emit,) async {
    emit(state.copyWith(
      absenceSubmissionStatus: SubmissionStatus.submitting,
      absenceSubmissionError: null,
    ));

    final result = await submitAbsenceRequest(event.request);

    result.fold(
          (failure) =>
          emit(state.copyWith(
            absenceSubmissionStatus: SubmissionStatus.error,
            absenceSubmissionError: failure.message,
          )),
          (_) =>
          emit(state.copyWith(
            absenceSubmissionStatus: SubmissionStatus.success,
          )),
    );
  }

  void _onResetAbsenceSubmission(ResetAbsenceSubmissionEvent event,
      Emitter<ParentState> emit,) {
    emit(state.copyWith(
      absenceSubmissionStatus: SubmissionStatus.idle,
      absenceSubmissionError: null,
    ));
  }

  // ══════════════════════════════════════════════════════════════════════
  // بدء عملية دفع (Paymob عن طريق Cloud Function)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onInitiatePayment(InitiatePaymentEvent event,
      Emitter<ParentState> emit,) async {
    emit(state.copyWith(
      paymentInitiationStatus: SubmissionStatus.submitting,
      paymentInitiationError: null,
    ));

    final result = await initiatePayment(PaymentIdParams(event.paymentId));

    result.fold(
          (failure) =>
          emit(state.copyWith(
            paymentInitiationStatus: SubmissionStatus.error,
            paymentInitiationError: failure.message,
          )),
      // الـ UI هيستخدم paymentInitiation.checkoutUrl عشان يفتح صفحة
      // الدفع (WebView مثلاً) لما نبني الشاشات.
          (initiation) =>
          emit(state.copyWith(
            paymentInitiationStatus: SubmissionStatus.success,
            paymentInitiation: initiation,
          )),
    );
  }

  void _onResetPaymentInitiation(ResetPaymentInitiationEvent event,
      Emitter<ParentState> emit,) {
    emit(state.copyWith(
      paymentInitiationStatus: SubmissionStatus.idle,
      paymentInitiation: null,
      paymentInitiationError: null,
    ));
  }

  /// بداية الأسبوع الحالي (السبت، حسب بداية الأسبوع الدراسي في مصر).
  /// لو حبينا نغيّرها لاحقاً (الاثنين مثلاً) هنا المكان الوحيد اللي نعدّله.
  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    // DateTime.weekday: 1=Monday ... 7=Sunday. السبت = 6.
    final daysSinceSaturday = (now.weekday - DateTime.saturday + 7) % 7;
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: daysSinceSaturday));
  }
}