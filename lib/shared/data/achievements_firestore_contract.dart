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
  static const String halaqaIdsField = 'halaqaIds';
  static const String halaqaNameField = 'halaqaName';
  static const String halaqaNamesField = 'halaqaNames';
  static const String studentNameField = 'studentName';
  static const String studentImageUrlField = 'studentImageUrl';
  static const String descriptionField = 'description';
  static const String imageUrlField = 'imageUrl';
  static const String imageStoragePathField = 'imageStoragePath';
  static const String recipientStudentIdsField = 'recipientStudentIds';
  static const String recipientCountField = 'recipientCount';

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
  ///
  /// [title] is the award name (dual-written to title/note). [description] is
  /// the reason and is stored separately. [note] is used as the name when
  /// [title] is empty (legacy callers).
  static Map<String, Object?> teacherGrantFields({
    required String studentId,
    required String studentName,
    String? studentImageUrl,
    required String type,
    String? title,
    String? note,
    String? description,
    required String grantedBy,
    required String halaqaId,
    String? halaqaName,
    List<String> halaqaIds = const [],
    List<String> halaqaNames = const [],
    List<String> recipientStudentIds = const [],
    int? recipientCount,
    String? imageUrl,
    String? imageStoragePath,
  }) {
    final timestamp = FieldValue.serverTimestamp();
    final name = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : note?.trim();
    final ids = recipientStudentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty && studentId.trim().isNotEmpty) {
      ids.add(studentId.trim());
    }
    final count = recipientCount ?? ids.length;
    final reason = description?.trim();
    final scopedHalaqaIds = uniqueNonEmpty(
      halaqaIds.isEmpty ? [halaqaId] : halaqaIds,
    );
    final primaryHalaqaId = () {
      final preferred = halaqaId.trim();
      if (preferred.isNotEmpty && scopedHalaqaIds.contains(preferred)) {
        return preferred;
      }
      return scopedHalaqaIds.isNotEmpty ? scopedHalaqaIds.first : preferred;
    }();
    final scopedNames = halaqaNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (scopedNames.isEmpty) {
      final legacyName = halaqaName?.trim() ?? '';
      if (legacyName.isNotEmpty) scopedNames.add(legacyName);
    }
    final primaryHalaqaName = () {
      final preferred = halaqaName?.trim() ?? '';
      if (preferred.isNotEmpty) return preferred;
      return scopedNames.isEmpty ? null : scopedNames.first;
    }();

    return {
      studentIdField: studentId,
      studentNameField: studentName,
      if (studentImageUrl != null) studentImageUrlField: studentImageUrl,
      typeField: type,
      halaqaIdField: primaryHalaqaId,
      halaqaIdsField: scopedHalaqaIds,
      if (primaryHalaqaName != null && primaryHalaqaName.isNotEmpty)
        halaqaNameField: primaryHalaqaName,
      if (scopedNames.isNotEmpty) halaqaNamesField: scopedNames,
      recipientStudentIdsField: ids,
      recipientCountField: count,
      if (reason != null && reason.isNotEmpty) descriptionField: reason,
      if (imageUrl != null && imageUrl.isNotEmpty) imageUrlField: imageUrl,
      if (imageStoragePath != null && imageStoragePath.isNotEmpty)
        imageStoragePathField: imageStoragePath,
      ...titleFields(title: name, note: name),
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

  static String resolveDescription(Map<String, dynamic> data) {
    final description = (data[descriptionField] as String?)?.trim();
    if (description != null && description.isNotEmpty) return description;
    return '';
  }

  static List<String> resolveRecipientStudentIds(Map<String, dynamic> data) {
    final raw = data[recipientStudentIdsField];
    if (raw is List) {
      return raw
          .map((id) => id.toString().trim())
          .where((id) => id.isNotEmpty)
          .toList();
    }
    final legacy = (data[studentIdField] as String?)?.trim() ?? '';
    return legacy.isEmpty ? const [] : [legacy];
  }

  static int resolveRecipientCount(Map<String, dynamic> data) {
    final raw = data[recipientCountField];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return resolveRecipientStudentIds(data).length;
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

  static List<String> uniqueNonEmpty(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      out.add(trimmed);
    }
    return out;
  }

  /// Additive `halaqaIds`, falling back to `[halaqaId]` for legacy docs.
  static List<String> resolveHalaqaIds(Map<String, dynamic> data) {
    final raw = data[halaqaIdsField];
    if (raw is List) {
      final ids = uniqueNonEmpty(raw.map((id) => id.toString()));
      if (ids.isNotEmpty) return ids;
    }
    final legacy = (data[halaqaIdField] as String?)?.trim() ?? '';
    return legacy.isEmpty ? const [] : [legacy];
  }

  /// Additive `halaqaNames`, falling back to `[halaqaName]` for legacy docs.
  static List<String> resolveHalaqaNames(Map<String, dynamic> data) {
    final raw = data[halaqaNamesField];
    if (raw is List) {
      final names = raw
          .map((name) => name.toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names;
    }
    final legacy = (data[halaqaNameField] as String?)?.trim() ?? '';
    return legacy.isEmpty ? const [] : [legacy];
  }
}
