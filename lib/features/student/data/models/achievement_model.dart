import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/achievement_entity.dart';

class AchievementModel extends AchievementEntity {
  const AchievementModel({
    required super.id,
    required super.studentId,
    required super.type,
    required super.title,
    required super.issuedBy,
    required super.date,
  });

  factory AchievementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Tolerate teacher Awards docs in the same collection
    // (grantedBy / grantedAt / note) without changing that write path.
    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : (data['note'] as String?)?.trim().isNotEmpty == true
            ? data['note'] as String
            : (data['type'] as String?) ?? '';
    final issuedBy = (data['issuedBy'] as String?)?.trim().isNotEmpty == true
        ? data['issuedBy'] as String
        : (data['grantedBy'] as String?) ?? '';
    final rawDate = data['date'] ?? data['grantedAt'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);

    return AchievementModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      type: _typeFromString(data['type'] ?? ''),
      title: title,
      issuedBy: issuedBy,
      date: date,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'type': _typeToString(type),
    'title': title,
    'issuedBy': issuedBy,
    'date': Timestamp.fromDate(date),
  };

  static AchievementType _typeFromString(String value) => switch (value) {
    'star' => AchievementType.star,
    'badge' => AchievementType.badge,
    'certificate' => AchievementType.certificate,
    _ => AchievementType.star,
  };

  static String _typeToString(AchievementType type) => switch (type) {
    AchievementType.star => 'star',
    AchievementType.badge => 'badge',
    AchievementType.certificate => 'certificate',
  };
}
