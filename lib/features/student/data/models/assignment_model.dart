import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/assignment_entity.dart';

class AssignmentModel extends AssignmentEntity {
  const AssignmentModel({
    required super.id,
    required super.studentId,
    required super.assignedBy,
    super.halaqaId,
    required super.newMemorizationRange,
    required super.reviewRange,
    required super.dueDate,
    super.title,
    super.tasks,
    super.teacherVoiceNote,
    super.attachments,
    super.isSubmitted,
    super.completedAt,
  });

  factory AssignmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final tasksRaw = data['tasks'] as List<dynamic>?;
    final attachmentsRaw = data['attachments'] as List<dynamic>?;
    final voiceRaw = data['teacherVoiceNote'] as Map<String, dynamic>?;

    return AssignmentModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      assignedBy: data['assignedBy'] ?? '',
      halaqaId: data['halaqaId'] ?? '',
      newMemorizationRange: data['newMemorizationRange'] ?? '',
      reviewRange: data['reviewRange'] ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: data['title'] as String? ?? '',
      tasks: tasksRaw
          ?.whereType<Map>()
          .map((e) =>
          AssignmentTaskEntity.fromMap(
            Map<String, dynamic>.from(e),
          ))
          .toList() ??
          const [],
      teacherVoiceNote: voiceRaw != null
          ? AssignmentVoiceNoteEntity.fromMap(voiceRaw)
          : null,
      attachments: attachmentsRaw
          ?.whereType<Map>()
          .map((e) =>
          AssignmentAttachmentEntity.fromMap(
            Map<String, dynamic>.from(e),
          ))
          .toList() ??
          const [],
      isSubmitted: data['isSubmitted'] as bool? ??
          (data['status'] == 'completed'),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'assignedBy': assignedBy,
    if (halaqaId.isNotEmpty) 'halaqaId': halaqaId,
    'newMemorizationRange': newMemorizationRange,
    'reviewRange': reviewRange,
    'dueDate': Timestamp.fromDate(dueDate),
    'title': title,
    'tasks': tasks.map((t) => t.toMap()).toList(),
    if (teacherVoiceNote != null)
      'teacherVoiceNote': teacherVoiceNote!.toMap(),
    'attachments': attachments.map((a) => a.toMap()).toList(),
    'isSubmitted': isSubmitted,
    if (completedAt != null)
      'completedAt': Timestamp.fromDate(completedAt!),
  };

  /// حقول واجباتي الافتراضية لنفس مستند التكليف (seed على الـ document الحقيقي).
  static Map<String, dynamic> defaultHomeworkFields({
    required String newMemorizationRange,
    required String reviewRange,
    String? teacherName,
  }) {
    final rangeLabel =
    newMemorizationRange.isNotEmpty ? newMemorizationRange : 'الورد اليومي';
    return {
      'title': rangeLabel,
      'isSubmitted': false,
      'tasks': [
        {
          'id': 't1',
          'title': 'قراءة: $rangeLabel',
          'points': 20,
          'isCompleted': false,
          'kind': 'reading',
        },
        {
          'id': 't2',
          'title': 'الاستماع للتلاوة كاملة',
          'points': 15,
          'isCompleted': false,
          'kind': 'listening',
        },
        {
          'id': 't3',
          'title': reviewRange.isNotEmpty
              ? 'تسميع: $reviewRange'
              : 'تسميع الآيات للمعلم',
          'points': 30,
          'isCompleted': false,
          'kind': 'recitation',
        },
        {
          'id': 't4',
          'title': 'حل اختبار الفهم القصير',
          'points': 25,
          'isCompleted': false,
          'kind': 'quiz',
        },
      ],
      'teacherVoiceNote': {
        'teacherName': teacherName ?? 'المعلم',
        'audioUrl':
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        'durationSeconds': 45,
      },
      'attachments': [
        {
          'id': 'a1',
          'name': 'ورقة-تمارين-التجويد.pdf',
          'url':
          'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          'sizeLabel': '٢٤٠ كيلوبايت',
        },
      ],
    };
  }
}
