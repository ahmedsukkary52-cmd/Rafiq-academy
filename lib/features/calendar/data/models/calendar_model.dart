import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/calendar_event_entity.dart';

class CalendarEventModel extends CalendarEventEntity {
  const CalendarEventModel({
    required super.id,
    required super.title,
    required super.type,
    required super.date,
    super.description,
    super.halaqaId,
    super.halaqaName,
    required super.createdBy,
  });

  factory CalendarEventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarEventModel(
      id: doc.id,
      title: data['title'] ?? '',
      type: _typeFromString(data['type'] ?? ''),
      date: (data['date'] as Timestamp).toDate(),
      description: data['description'] as String?,
      halaqaId: data['halaqaId'] as String?,
      halaqaName: data['halaqaName'] as String?,
      createdBy: data['createdBy'] ?? '',
    );
  }

  /// [creatorUid] is the signed-in Firebase user; firestore.rules reject any
  /// other value, so the entity's own [createdBy] is never written.
  Map<String, dynamic> toCreateData({required String creatorUid}) => {
    'title': title,
    'type': _typeToString(type),
    'date': Timestamp.fromDate(date),
    if (description != null) 'description': description,
    if (halaqaId != null) 'halaqaId': halaqaId,
    if (halaqaName != null) 'halaqaName': halaqaName,
    'createdBy': creatorUid,
    'createdAt': FieldValue.serverTimestamp(),
  };

  static CalendarEventType _typeFromString(String v) => switch (v) {
    'session' => CalendarEventType.session,
    'exam' => CalendarEventType.exam,
    'holiday' => CalendarEventType.holiday,
    'occasion' => CalendarEventType.occasion,
    _ => CalendarEventType.session,
  };

  static String _typeToString(CalendarEventType t) => switch (t) {
    CalendarEventType.session => 'session',
    CalendarEventType.exam => 'exam',
    CalendarEventType.holiday => 'holiday',
    CalendarEventType.occasion => 'occasion',
  };
}
