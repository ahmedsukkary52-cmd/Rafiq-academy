import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/halaqa_entity.dart';
import 'halaqa_schedule_model.dart';

class HalaqaModel extends HalaqaEntity {
  const HalaqaModel({
    required super.id,
    required super.name,
    required super.teacherId,
    required super.supervisorId,
    required super.studentIds,
    required super.schedule,
    required super.meetingLink,
    required super.status,
  });

  factory HalaqaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final scheduleList = (data['schedule'] as List<dynamic>? ?? [])
        .map((e) => HalaqaScheduleModel.fromMap(e as Map<String, dynamic>))
        .toList();

    return HalaqaModel(
      id: doc.id,
      name: data['name'] ?? '',
      teacherId: data['teacherId'] ?? '',
      supervisorId: data['supervisorId'] ?? '',
      studentIds: List<String>.from(data['studentIds'] ?? []),
      schedule: scheduleList,
      meetingLink: data['meetingLink'] ?? '',
      status: data['status'] ?? 'active',
    );
  }
}
