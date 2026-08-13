import 'package:equatable/equatable.dart';

import '../../../../shared/domain/assignment_kind.dart';

enum HalaqaActivityResponseType { text, image, audio }

extension HalaqaActivityResponseTypeWire on HalaqaActivityResponseType {
  String get wireValue => name;

  static HalaqaActivityResponseType? tryParse(Object? raw) {
    final value = raw is String ? raw.trim() : '';
    return switch (value) {
      'text' => HalaqaActivityResponseType.text,
      'image' => HalaqaActivityResponseType.image,
      'audio' => HalaqaActivityResponseType.audio,
      _ => null,
    };
  }
}

/// Lightweight Halaqa activity stored as one `assignments` doc with
/// [AssignmentKind.halaqaActivity].
class HalaqaActivityEntity extends Equatable {
  final String id;
  final String halaqaId;
  final String teacherId;
  final String teacherName;
  final String prompt;
  final DateTime createdAt;
  final DateTime? deadline;
  final Set<HalaqaActivityResponseType> allowedResponseTypes;
  final bool alsoShareAsPost;
  final String? postId;
  final int responseCount;
  /// Student uids that have at least one thread response (list cards).
  final Set<String> respondentStudentIds;
  final List<HalaqaActivityResponseEntity> thread;

  const HalaqaActivityEntity({
    required this.id,
    required this.halaqaId,
    required this.teacherId,
    required this.teacherName,
    required this.prompt,
    required this.createdAt,
    required this.allowedResponseTypes,
    this.deadline,
    this.alsoShareAsPost = false,
    this.postId,
    this.responseCount = 0,
    this.respondentStudentIds = const {},
    this.thread = const [],
  });

  bool hasStudentResponded(String studentId) =>
      respondentStudentIds.contains(studentId);

  AssignmentKind get kind => AssignmentKind.halaqaActivity;

  HalaqaActivityEntity copyWith({
    int? responseCount,
    Set<String>? respondentStudentIds,
    List<HalaqaActivityResponseEntity>? thread,
    String? postId,
    bool? alsoShareAsPost,
  }) {
    return HalaqaActivityEntity(
      id: id,
      halaqaId: halaqaId,
      teacherId: teacherId,
      teacherName: teacherName,
      prompt: prompt,
      createdAt: createdAt,
      deadline: deadline,
      allowedResponseTypes: allowedResponseTypes,
      alsoShareAsPost: alsoShareAsPost ?? this.alsoShareAsPost,
      postId: postId ?? this.postId,
      responseCount: responseCount ?? this.responseCount,
      respondentStudentIds:
          respondentStudentIds ?? this.respondentStudentIds,
      thread: thread ?? this.thread,
    );
  }

  @override
  List<Object?> get props => [
    id,
    halaqaId,
    teacherId,
    teacherName,
    prompt,
    createdAt,
    deadline,
    allowedResponseTypes,
    alsoShareAsPost,
    postId,
    responseCount,
    respondentStudentIds,
    thread,
  ];
}

class HalaqaActivityResponseEntity extends Equatable {
  final String id;
  final String activityId;
  final String studentId;
  final String studentName;
  final DateTime createdAt;
  final String? text;
  final String? imageUrl;
  final String? audioUrl;
  final String? imageLabel;
  final String? audioLabel;

  const HalaqaActivityResponseEntity({
    required this.id,
    required this.activityId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    this.text,
    this.imageUrl,
    this.audioUrl,
    this.imageLabel,
    this.audioLabel,
  });

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;
  bool get hasAudio => (audioUrl ?? '').trim().isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    activityId,
    studentId,
    studentName,
    createdAt,
    text,
    imageUrl,
    audioUrl,
    imageLabel,
    audioLabel,
  ];
}
