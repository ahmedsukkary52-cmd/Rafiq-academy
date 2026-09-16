import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/domain/student_search_contract.dart';
import '../../domain/entities/student_search_entry.dart';

/// Read-only mapper for `studentSearch/{studentId}`.
///
/// There is no `toFirestore`: the projection is Cloud-Functions-owned and
/// Rules deny every client write (C13 / WA-14).
class StudentSearchEntryModel extends StudentSearchEntry {
  const StudentSearchEntryModel({
    required super.studentId,
    required super.fullName,
    required super.fullNameNormalized,
    required super.halaqaId,
    required super.halaqaName,
    required super.halaqaIds,
  });

  factory StudentSearchEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final halaqaId =
        (data[StudentSearchContract.halaqaIdField] as String?)?.trim() ?? '';

    return StudentSearchEntryModel(
      // The document id is the identity; the field is a mirror of it.
      studentId: doc.id,
      fullName:
          (data[StudentSearchContract.fullNameField] as String?)?.trim() ?? '',
      fullNameNormalized:
          (data[StudentSearchContract.fullNameNormalizedField] as String?)
              ?.trim() ??
          '',
      halaqaId: halaqaId.isEmpty ? null : halaqaId,
      halaqaName:
          (data[StudentSearchContract.halaqaNameField] as String?)?.trim() ??
          '',
      halaqaIds: _stringList(data[StudentSearchContract.halaqaIdsField]),
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
