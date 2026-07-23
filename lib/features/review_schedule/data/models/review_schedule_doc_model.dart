import 'package:cloud_firestore/cloud_firestore.dart';

/// Raw `reviewSchedules` document fields (schema unchanged).
class ReviewScheduleDocModel {
  final String id;
  final String studentId;
  final DateTime date;
  final String surahFrom;
  final int ayahFrom;
  final String surahTo;
  final int ayahTo;
  final bool isDone;

  const ReviewScheduleDocModel({
    required this.id,
    required this.studentId,
    required this.date,
    required this.surahFrom,
    required this.ayahFrom,
    required this.surahTo,
    required this.ayahTo,
    required this.isDone,
  });

  factory ReviewScheduleDocModel.fromMap(String id, Map<String, dynamic> data) {
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : (rawDate as DateTime);

    return ReviewScheduleDocModel(
      id: id,
      studentId: (data['studentId'] as String?) ?? '',
      date: date,
      surahFrom: (data['surahFrom'] as String?) ?? '',
      ayahFrom: (data['ayahFrom'] as int?) ?? 0,
      surahTo: (data['surahTo'] as String?) ?? '',
      ayahTo: (data['ayahTo'] as int?) ?? 0,
      isDone: data['status'] == 'done',
    );
  }
}
