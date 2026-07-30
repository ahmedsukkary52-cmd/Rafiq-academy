import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared `achievements` collection contract (H7 / A-H7).
///
/// Teacher grants historically wrote `grantedBy` / `grantedAt` / `note`.
/// Supervisor issues wrote `issuedBy` / `date` / `title`.
/// New writes dual-write both actor/time (and title/note) aliases so readers
/// and halaqa stats/list queries stay coherent without a data migration.
class AchievementsFirestoreContract {
  const AchievementsFirestoreContract._();

  static const String collectionHint = 'achievements';

  static const String studentIdField = 'studentId';
  static const String typeField = 'type';
  static const String titleField = 'title';
  static const String noteField = 'note';
  static const String issuedByField = 'issuedBy';
  static const String grantedByField = 'grantedBy';
  static const String dateField = 'date';
  static const String grantedAtField = 'grantedAt';
  static const String halaqaIdField = 'halaqaId';
  static const String studentNameField = 'studentName';
  static const String studentImageUrlField = 'studentImageUrl';

  /// Actor + time aliases written on every new achievement doc.
  static Map<String, Object?> actorAndTimeFields({
    required String actorId,
    required Object timestamp,
  }) {
    return {
      grantedByField: actorId,
      issuedByField: actorId,
      grantedAtField: timestamp,
      dateField: timestamp,
    };
  }

  /// Title aliases: prefer explicit [title], else [note].
  static Map<String, Object?> titleFields({String? title, String? note}) {
    final t = title?.trim();
    final n = note?.trim();
    final resolved = (t != null && t.isNotEmpty)
        ? t
        : (n != null && n.isNotEmpty ? n : null);
    if (resolved == null) return const {};
    return {
      titleField: resolved,
      noteField: resolved,
    };
  }

  /// Teacher grant payload (keeps teacher-specific denormalized fields).
  static Map<String, Object?> teacherGrantFields({
    required String studentId,
    required String studentName,
    String? studentImageUrl,
    required String type,
    String? note,
    required String grantedBy,
    required String halaqaId,
  }) {
    final timestamp = FieldValue.serverTimestamp();
    return {
      studentIdField: studentId,
      studentNameField: studentName,
      if (studentImageUrl != null) studentImageUrlField: studentImageUrl,
      typeField: type,
      halaqaIdField: halaqaId,
      ...titleFields(note: note),
      ...actorAndTimeFields(actorId: grantedBy, timestamp: timestamp),
    };
  }

  /// Supervisor issue payload (adds halaqa + teacher-compatible aliases).
  static Map<String, Object?> supervisorIssueFields({
    required String studentId,
    required String type,
    required String title,
    required String issuedBy,
    required String halaqaId,
    DateTime? at,
  }) {
    final timestamp = Timestamp.fromDate(at ?? DateTime.now());
    return {
      studentIdField: studentId,
      typeField: type,
      halaqaIdField: halaqaId,
      ...titleFields(title: title),
      ...actorAndTimeFields(actorId: issuedBy, timestamp: timestamp),
    };
  }

  static String resolveTitle(Map<String, dynamic> data, {String fallback = ''}) {
    final title = (data[titleField] as String?)?.trim();
    if (title != null && title.isNotEmpty) return title;
    final note = (data[noteField] as String?)?.trim();
    if (note != null && note.isNotEmpty) return note;
    final type = (data[typeField] as String?)?.trim();
    if (type != null && type.isNotEmpty) return type;
    return fallback;
  }

  static String resolveActor(Map<String, dynamic> data) {
    final issuedBy = (data[issuedByField] as String?)?.trim();
    if (issuedBy != null && issuedBy.isNotEmpty) return issuedBy;
    return (data[grantedByField] as String?)?.trim() ?? '';
  }

  static DateTime resolveDate(Map<String, dynamic> data) {
    final raw = data[dateField] ?? data[grantedAtField];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
