import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/academy_session_entity.dart';
import '../../domain/session_contract.dart';

/// Firestore serialization for `sessions/{sessionId}` (WA-8).
class AcademySessionModel extends AcademySessionEntity {
  const AcademySessionModel({
    required super.id,
    required super.halaqaId,
    required super.slotId,
    required super.date,
    required super.startAt,
    required super.endAt,
    required super.status,
    required super.teacherId,
    super.supervisorId,
    super.createdAt,
    super.updatedAt,
    required super.createdBy,
  });

  factory AcademySessionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AcademySessionModel.fromMap(doc.id, data);
  }

  factory AcademySessionModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime requireTs(String key) {
      final raw = data[key];
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      throw ArgumentError('sessions/$id missing $key');
    }

    DateTime? optionalTs(String key) {
      final raw = data[key];
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    final status = (data[SessionContract.statusField] as String?)?.trim() ?? '';
    final supervisor =
        (data[SessionContract.supervisorIdField] as String?)?.trim();

    return AcademySessionModel(
      id: id,
      halaqaId: (data[SessionContract.halaqaIdField] as String?)?.trim() ?? '',
      slotId: (data[SessionContract.slotIdField] as String?)?.trim() ?? '',
      date: (data[SessionContract.dateField] as String?)?.trim() ?? '',
      startAt: requireTs(SessionContract.startAtField),
      endAt: requireTs(SessionContract.endAtField),
      status: status.isEmpty ? SessionContract.statusScheduled : status,
      teacherId:
          (data[SessionContract.teacherIdField] as String?)?.trim() ?? '',
      supervisorId: (supervisor == null || supervisor.isEmpty)
          ? null
          : supervisor,
      createdAt: optionalTs(SessionContract.createdAtField),
      updatedAt: optionalTs(SessionContract.updatedAtField),
      createdBy:
          (data[SessionContract.createdByField] as String?)?.trim() ?? '',
    );
  }

  /// Client-side map for tests / local fixtures (no server timestamps).
  Map<String, dynamic> toMap() => {
    SessionContract.halaqaIdField: halaqaId,
    SessionContract.slotIdField: slotId,
    SessionContract.dateField: date,
    SessionContract.startAtField: Timestamp.fromDate(startAt),
    SessionContract.endAtField: Timestamp.fromDate(endAt),
    SessionContract.statusField: status,
    SessionContract.teacherIdField: teacherId,
    if (supervisorId != null && supervisorId!.isNotEmpty)
      SessionContract.supervisorIdField: supervisorId,
    SessionContract.createdByField: createdBy,
    if (createdAt != null)
      SessionContract.createdAtField: Timestamp.fromDate(createdAt!),
    if (updatedAt != null)
      SessionContract.updatedAtField: Timestamp.fromDate(updatedAt!),
  };
}
