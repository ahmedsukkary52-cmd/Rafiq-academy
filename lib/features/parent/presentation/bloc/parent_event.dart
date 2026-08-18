import 'package:equatable/equatable.dart';

import '../../domain/entities/parent_entities.dart';

abstract class ParentEvent extends Equatable {
  const ParentEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل معرّفات أبناء ولي الأمر
class LoadChildrenEvent extends ParentEvent {
  final String parentId;
  const LoadChildrenEvent(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

/// اختيار طفل معيّن من قائمة الأبناء (لو أكتر من ابن).
/// بيحمّل تلقائياً تقرير الأسبوع الحالي بتاعه.
class SelectChildEvent extends ParentEvent {
  final String studentId;
  const SelectChildEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

/// تحميل التقرير الأسبوعي لطالب معيّن في أسبوع معيّن
class LoadWeeklyReportEvent extends ParentEvent {
  final String studentId;
  final DateTime weekStart;
  const LoadWeeklyReportEvent({
    required this.studentId,
    required this.weekStart,
  });

  @override
  List<Object?> get props => [studentId, weekStart];
}

/// تحميل سجل المدفوعات والاشتراكات
class LoadPaymentsEvent extends ParentEvent {
  final String parentId;
  const LoadPaymentsEvent(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

/// تحميل طلبات الاستئذان الخاصة بولي الأمر (W7 Slice 1)
class LoadAbsenceRequestsEvent extends ParentEvent {
  final String parentId;
  const LoadAbsenceRequestsEvent(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

/// حلقات الطالب لنموذج الاستئذان — يتطلب parentId للتحقق من ملكية الابن
class LoadStudentHalaqatEvent extends ParentEvent {
  final String parentId;
  final String studentId;
  const LoadStudentHalaqatEvent({
    required this.parentId,
    required this.studentId,
  });

  @override
  List<Object?> get props => [parentId, studentId];
}

/// تقديم طلب استئذان عن حصة
class SubmitAbsenceRequestEvent extends ParentEvent {
  final AbsenceRequestEntity request;
  const SubmitAbsenceRequestEvent(this.request);

  @override
  List<Object?> get props => [request];
}

/// إرجاع حالة إرسال طلب الاستئذان لـ idle بعد ما الـ UI يعرض النتيجة
/// (مثلاً بعد ما يقفل الـ SnackBar)، عشان لو المستخدم فتح الفورم تاني
/// ميشوفش نتيجة المحاولة القديمة.
class ResetAbsenceSubmissionEvent extends ParentEvent {
  const ResetAbsenceSubmissionEvent();
}

/// بدء عملية دفع لمستحق معيّن
class InitiatePaymentEvent extends ParentEvent {
  final String paymentId;

  const InitiatePaymentEvent(this.paymentId);

  @override
  List<Object?> get props => [paymentId];
}

/// إعادة تصفير نتيجة بدء الدفع بعد ما الـ UI يفتح صفحة الدفع
class ResetPaymentInitiationEvent extends ParentEvent {
  const ResetPaymentInitiationEvent();
}

class LoadWalletEvent extends ParentEvent {
  final String parentId;
  const LoadWalletEvent(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

class PayPaymentFromWalletEvent extends ParentEvent {
  final String parentId;
  final String paymentId;

  const PayPaymentFromWalletEvent({
    required this.parentId,
    required this.paymentId,
  });

  @override
  List<Object?> get props => [parentId, paymentId];
}

class ResetWalletPayEvent extends ParentEvent {
  const ResetWalletPayEvent();
}

/// Clear projection on logout so the next identity cannot inherit state (H1).
class ClearParentSessionEvent extends ParentEvent {
  const ClearParentSessionEvent();
}
