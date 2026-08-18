import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/attendance_policy.dart';
import '../../student/domain/entities/recitation_record_entity.dart';
import '../domain/entities/parent_entities.dart';

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

Color parentGradeColor(RecitationGrade? grade) {
  return switch (grade) {
    RecitationGrade.excellent => AppColors.success,
    RecitationGrade.veryGood => AppColors.primary,
    RecitationGrade.good => AppColors.secondary,
    RecitationGrade.needsRetry => AppColors.warning,
    null => AppColors.textHint,
  };
}
