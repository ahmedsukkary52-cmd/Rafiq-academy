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
    return AchievementModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      type: _typeFromString(data['type'] ?? ''),
      title: data['title'] ?? '',
      issuedBy: data['issuedBy'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
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
