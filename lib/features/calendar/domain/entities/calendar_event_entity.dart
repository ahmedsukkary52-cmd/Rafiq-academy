import 'package:equatable/equatable.dart';

/// نوع الحدث - بيحدد لون النقطة على التقويم في الـ UI
enum CalendarEventType {
  session, // حصة  - أزرق
  exam, // اختبار - أصفر
  holiday, // إجازة  - أحمر
  occasion, // مناسبة - أخضر
}

extension CalendarEventTypeLabel on CalendarEventType {
  String get label => switch (this) {
    CalendarEventType.session => 'حصة',
    CalendarEventType.exam => 'اختبار',
    CalendarEventType.holiday => 'إجازة',
    CalendarEventType.occasion => 'مناسبة',
  };
}

class CalendarEventEntity extends Equatable {
  final String id;
  final String title;
  final CalendarEventType type;
  final DateTime date;
  final String? description;

  /// الحلقة اللي الحدث خاص بيها (null = كل الحلقات)
  final String? halaqaId;
  final String? halaqaName; // denormalized للعرض

  final String createdBy;

  const CalendarEventEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.description,
    this.halaqaId,
    this.halaqaName,
    required this.createdBy,
  });

  /// اليوم فقط بدون وقت (للمقارنة مع أيام التقويم)
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    date,
    description,
    halaqaId,
    halaqaName,
    createdBy,
  ];
}
