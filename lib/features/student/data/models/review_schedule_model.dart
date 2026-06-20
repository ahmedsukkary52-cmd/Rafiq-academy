import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/review_schedule_entity.dart';

class ReviewScheduleModel extends ReviewScheduleEntity {
  const ReviewScheduleModel({
    required super.id,
    required super.studentId,
    required super.date,
    required super.surahFrom,
    required super.ayahFrom,
    required super.surahTo,
    required super.ayahTo,
    required super.status,
  });

  factory ReviewScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewScheduleModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      surahFrom: data['surahFrom'] ?? '',
      ayahFrom: (data['ayahFrom'] ?? 0) as int,
      surahTo: data['surahTo'] ?? '',
      ayahTo: (data['ayahTo'] ?? 0) as int,
      status: data['status'] == 'done'
          ? ReviewStatus.done
          : ReviewStatus.pending,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'date': Timestamp.fromDate(date),
    'surahFrom': surahFrom,
    'ayahFrom': ayahFrom,
    'surahTo': surahTo,
    'ayahTo': ayahTo,
    'status': status == ReviewStatus.done ? 'done' : 'pending',
  };
}
