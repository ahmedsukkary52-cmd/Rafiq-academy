import 'package:equatable/equatable.dart';

enum HomeworkTaskKind { reading, listening, review, recitation, quiz, other }

class HomeworkAttachmentEntity extends Equatable {
  final String id;
  final String name;
  final String url;
  final String sizeLabel;

  const HomeworkAttachmentEntity({
    required this.id,
    required this.name,
    required this.url,
    required this.sizeLabel,
  });

  @override
  List<Object?> get props => [id, name, url, sizeLabel];
}

class TeacherVoiceNoteEntity extends Equatable {
  final String teacherName;
  final String audioUrl;
  final Duration duration;

  const TeacherVoiceNoteEntity({
    required this.teacherName,
    required this.audioUrl,
    required this.duration,
  });

  @override
  List<Object?> get props => [teacherName, audioUrl, duration];
}

class HomeworkTaskEntity extends Equatable {
  final String id;
  final String title;
  final int points;
  final bool isCompleted;
  final HomeworkTaskKind kind;
  final String? recitationRecordId;

  const HomeworkTaskEntity({
    required this.id,
    required this.title,
    required this.points,
    required this.isCompleted,
    required this.kind,
    this.recitationRecordId,
  });

  HomeworkTaskEntity copyWith({bool? isCompleted, String? recitationRecordId}) {
    return HomeworkTaskEntity(
      id: id,
      title: title,
      points: points,
      isCompleted: isCompleted ?? this.isCompleted,
      kind: kind,
      recitationRecordId: recitationRecordId ?? this.recitationRecordId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    points,
    isCompleted,
    kind,
    recitationRecordId,
  ];
}

class HomeworkEntity extends Equatable {
  final String id;
  final String studentId;
  final String assignedBy;
  final String halaqaId;
  final String title;
  final DateTime dueAt;
  final String newMemorizationRange;
  final String reviewRange;
  final List<HomeworkTaskEntity> tasks;
  final TeacherVoiceNoteEntity? teacherVoiceNote;
  final List<HomeworkAttachmentEntity> attachments;
  final bool isSubmitted;
  final DateTime? completedAt;

  const HomeworkEntity({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.tasks,
    this.studentId = '',
    this.assignedBy = '',
    this.halaqaId = '',
    this.newMemorizationRange = '',
    this.reviewRange = '',
    this.teacherVoiceNote,
    this.attachments = const [],
    this.isSubmitted = false,
    this.completedAt,
  });

  int get completedCount => tasks.where((t) => t.isCompleted).length;

  int get totalCount => tasks.length;

  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  bool get allCompleted =>
      tasks.isNotEmpty && tasks.every((t) => t.isCompleted);

  int get earnedPoints =>
      tasks.where((t) => t.isCompleted).fold(0, (s, t) => s + t.points);

  HomeworkEntity copyWith({
    List<HomeworkTaskEntity>? tasks,
    bool? isSubmitted,
    DateTime? completedAt,
  }) {
    return HomeworkEntity(
      id: id,
      studentId: studentId,
      assignedBy: assignedBy,
      halaqaId: halaqaId,
      title: title,
      dueAt: dueAt,
      newMemorizationRange: newMemorizationRange,
      reviewRange: reviewRange,
      tasks: tasks ?? this.tasks,
      teacherVoiceNote: teacherVoiceNote,
      attachments: attachments,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    studentId,
    assignedBy,
    halaqaId,
    title,
    dueAt,
    newMemorizationRange,
    reviewRange,
    tasks,
    teacherVoiceNote,
    attachments,
    isSubmitted,
    completedAt,
  ];
}
