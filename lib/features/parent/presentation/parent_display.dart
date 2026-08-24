import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/domain/student_at_risk_policy.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/attendance_policy.dart';
import '../../student/domain/entities/recitation_record_entity.dart';
import '../domain/entities/parent_entities.dart';
import '../domain/parent_household.dart';

String parentRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) {
    return 'منذ ${parentEasternDigits('${diff.inMinutes}')} د';
  }
  if (diff.inHours < 24) {
    return 'منذ ${parentEasternDigits('${diff.inHours}')} س';
  }
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 7) {
    return 'منذ ${parentEasternDigits('${diff.inDays}')} يوم';
  }
  return parentEasternDigits('${dt.day}/${dt.month}/${dt.year}');
}

String parentCleanNotificationBody(String body) {
  var text = body.replaceAll(RegExp(r'\d{4}-\d{2}-\d{2}T[0-9.:\-]+'), '');
  text = text.replaceAll(RegExp(r'[—\-:]+\s*$'), '');
  return text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

String parentEasternDigits(String input) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final code in input.runes) {
    final ch = String.fromCharCode(code);
    final i = western.indexOf(ch);
    buffer.write(i >= 0 ? eastern[i] : ch);
  }
  return buffer.toString();
}

String parentPercentLabel(double? value) {
  if (value == null) return '—';
  return '${parentEasternDigits('${value.round()}')}٪';
}

String parentAttendanceLabel(String? status) {
  return switch ((status ?? '').trim()) {
    AttendancePolicy.statusPresent => 'حاضر',
    AttendancePolicy.statusAbsent => 'غائب',
    AttendancePolicy.statusLate => 'متأخر',
    AttendancePolicy.statusExcused => 'معذور',
    _ => 'غير مسجّل',
  };
}

String parentPaymentLabel(PaymentStatus? status) {
  return switch (status) {
    PaymentStatus.paid => 'مدفوع',
    PaymentStatus.due => 'مستحق',
    PaymentStatus.overdue => 'متأخر',
    null => '',
  };
}

String parentTeacherCaption(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('أ.') ||
      trimmed.startsWith('ا.') ||
      trimmed.startsWith('الأستاذ') ||
      trimmed.startsWith('الأستاذة')) {
    return trimmed;
  }
  return 'أ. $trimmed';
}

String parentChildStatusBanner(ParentChildSnapshot child) {
  return switch (child.riskSignal) {
    RiskSignal.repeatedAbsence => 'يحتاج متابعة — غياب متكرر خلال آخر 14 يوماً',
    RiskSignal.noRecentEvaluation => 'لا يوجد تقييم معتمد حديث',
    RiskSignal.lowPerformance => 'يحتاج متابعة في الأداء',
    null =>
      child.latestReviewedGrade == null
          ? 'المتابعة جيدة'
          : 'آخر تقييم: ${child.latestReviewedGrade!.label}',
  };
}

Color parentGradeColor(RecitationGrade? grade) {
  return switch (grade) {
    RecitationGrade.excellent => AppColors.success,
    RecitationGrade.veryGood => AppColors.primary,
    RecitationGrade.good => AppColors.secondary,
    RecitationGrade.needsRetry => AppColors.warning,
    null => AppColors.textHint,
  };
}

List<String> parentLinkedChildNames({
  required String staffUid,
  required String role,
  required List<ParentChildSnapshot> children,
}) {
  final id = staffUid.trim();
  if (id.isEmpty) return const [];
  final names = <String>[];
  for (final child in children) {
    final linkedId = switch (role) {
      AppRoles.teacher => (child.teacherId ?? '').trim(),
      AppRoles.supervisor => (child.supervisorId ?? '').trim(),
      _ => '',
    };
    if (linkedId != id) continue;
    final name = child.displayName;
    if (name.isNotEmpty && !names.contains(name)) names.add(name);
  }
  return names;
}

const _arabicMonths = [
  '',
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String parentMoneyLabel(double amount) {
  return '${parentEasternDigits('${amount.round()}')} جنيه';
}

String parentPaymentPeriodLabel(DateTime date) {
  final month = date.month.clamp(1, 12);
  return '${_arabicMonths[month]} ${parentEasternDigits('${date.year}')}';
}

String parentPaymentsChildrenCaption({
  required List<PaymentEntity> payments,
  required String Function(String studentId) nameFor,
}) {
  if (payments.isEmpty) return '';
  final names = <String>[];
  final amounts = <double>{};
  for (final payment in payments) {
    amounts.add(payment.amount);
    final name = nameFor(payment.studentId).trim();
    if (name.isNotEmpty && !names.contains(name)) names.add(name);
  }
  if (names.isEmpty) return '';
  final namesPart = names.join(' + ');
  if (amounts.length == 1) {
    return 'أبناء: $namesPart — ${parentMoneyLabel(amounts.first)} / طالب';
  }
  return 'أبناء: $namesPart';
}

String parentStaffRelationCaption({
  required String role,
  required String staffUid,
  required List<ParentChildSnapshot> children,
}) {
  if (role == AppRoles.admin) return 'إدارة الأكاديمية';
  final names = parentLinkedChildNames(
    staffUid: staffUid,
    role: role,
    children: children,
  );
  final roleWord = role == AppRoles.supervisor ? 'مشرف' : 'معلم';
  if (names.isEmpty) return '$roleWord أبنائك';
  if (names.length == 1) return '$roleWord ${names.single}';
  return '$roleWord ${names.join(' · ')}';
}
