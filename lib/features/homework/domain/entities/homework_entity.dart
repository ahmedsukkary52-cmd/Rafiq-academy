import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

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

  /// Recitation is optional/deferred until Storage uploads are enabled (D8).
  bool get isDeferredRecitation =>
      kind == HomeworkTaskKind.recitation &&
      !AppCapabilities.audioUploadsEnabled;

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

  /// Tasks that must be done before «إنهاء الواجب» (D8).
  /// When [AppCapabilities.audioUploadsEnabled] is true, recitation is included.
  List<HomeworkTaskEntity> get requiredTasks => tasks
      .where(
        (t) =>
            AppCapabilities.audioUploadsEnabled ||
            t.kind != HomeworkTaskKind.recitation,
      )
      .toList();

  int get completedCount => requiredTasks.where((t) => t.isCompleted).length;

  int get totalCount => requiredTasks.length;

  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  /// True when every **required** task is complete (not deferred recitation).
  bool get allCompleted =>
      requiredTasks.isNotEmpty && requiredTasks.every((t) => t.isCompleted);

  int get earnedPoints =>
      requiredTasks.where((t) => t.isCompleted).fold(0, (s, t) => s + t.points);

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
