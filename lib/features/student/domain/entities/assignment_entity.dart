import 'package:equatable/equatable.dart';

/// تكليف الطالب من collection `assignments`.
///
/// الحقول الأساسية (درس اليوم في Home):
/// [newMemorizationRange], [reviewRange], [dueDate]
///
/// حقول واجباتي (نفس الـ document):
/// [title], [tasks], [teacherVoiceNote], [attachments]
class AssignmentEntity extends Equatable {
  final String id;
  final String studentId;
  final String assignedBy;
  final String halaqaId;
  final String newMemorizationRange;
  final String reviewRange;
  final DateTime dueDate;

  /// عنوان الواجب المعروض في واجباتي (وHome لو موجود)
  final String title;

  final List<AssignmentTaskEntity> tasks;
  final AssignmentVoiceNoteEntity? teacherVoiceNote;
  final List<AssignmentAttachmentEntity> attachments;

  /// هل تم تسليم/إنهاء الواجب؟ يمنع تعديل المهام وتكرار النقاط.
  final bool isSubmitted;
  final DateTime? completedAt;

  const AssignmentEntity({
    required this.id,
    required this.studentId,
    required this.assignedBy,
    this.halaqaId = '',
    required this.newMemorizationRange,
    required this.reviewRange,
    required this.dueDate,
    this.title = '',
    this.tasks = const [],
    this.teacherVoiceNote,
    this.attachments = const [],
    this.isSubmitted = false,
    this.completedAt,
  });

  /// نص العرض الموحّد لكارت درس اليوم وصفحة الواجبات
  String get displayTitle =>
      title.isNotEmpty ? title : newMemorizationRange;

  @override
  List<Object?> get props => [
    id,
    studentId,
    assignedBy,
    halaqaId,
    newMemorizationRange,
    reviewRange,
    dueDate,
    title,
    tasks,
    teacherVoiceNote,
    attachments,
    isSubmitted,
    completedAt,
  ];
}

class AssignmentTaskEntity extends Equatable {
  final String id;
  final String title;
  final int points;
  final bool isCompleted;
  final String kind;
  final String? recitationRecordId;

  const AssignmentTaskEntity({
    required this.id,
    required this.title,
    required this.points,
    required this.isCompleted,
    required this.kind,
    this.recitationRecordId,
  });

  Map<String, dynamic> toMap() =>
      {
        'id': id,
        'title': title,
        'points': points,
        'isCompleted': isCompleted,
        'kind': kind,
        if (recitationRecordId != null)
          'recitationRecordId': recitationRecordId,
      };

  factory AssignmentTaskEntity.fromMap(Map<String, dynamic> map) {
    return AssignmentTaskEntity(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
      isCompleted: map['isCompleted'] as bool? ?? false,
      kind: map['kind'] as String? ?? 'other',
      recitationRecordId: map['recitationRecordId'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, points, isCompleted, kind, recitationRecordId];
}

class AssignmentVoiceNoteEntity extends Equatable {
  final String teacherName;
  final String audioUrl;
  final int durationSeconds;

  const AssignmentVoiceNoteEntity({
    required this.teacherName,
    required this.audioUrl,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() =>
      {
        'teacherName': teacherName,
        'audioUrl': audioUrl,
        'durationSeconds': durationSeconds,
      };

  factory AssignmentVoiceNoteEntity.fromMap(Map<String, dynamic> map) {
    return AssignmentVoiceNoteEntity(
      teacherName: map['teacherName'] as String? ?? '',
      audioUrl: map['audioUrl'] as String? ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [teacherName, audioUrl, durationSeconds];
}

class AssignmentAttachmentEntity extends Equatable {
  final String id;
  final String name;
  final String url;
  final String sizeLabel;

  const AssignmentAttachmentEntity({
    required this.id,
    required this.name,
    required this.url,
    required this.sizeLabel,
  });

  Map<String, dynamic> toMap() =>
      {
        'id': id,
        'name': name,
        'url': url,
        'sizeLabel': sizeLabel,
      };

  factory AssignmentAttachmentEntity.fromMap(Map<String, dynamic> map) {
    return AssignmentAttachmentEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      url: map['url'] as String? ?? '',
      sizeLabel: map['sizeLabel'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, url, sizeLabel];
}
