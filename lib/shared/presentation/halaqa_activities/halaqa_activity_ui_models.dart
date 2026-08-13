/// Presentation-only models for Halaqa lightweight activities (UI batch).
/// Not domain entities — no Firestore wiring in this batch.
library;

enum ActivityResponseTypeUi { text, image, audio }

enum ActivityListLoadState { loading, loaded, error }

enum StudentActivityReplyState { notReplied, replied }

class HalaqaActivityUi {
  final String id;
  final String halaqaId;
  final String prompt;
  final DateTime createdAt;
  final DateTime? deadline;
  final Set<ActivityResponseTypeUi> allowedResponseTypes;
  final bool sharedToPosts;
  final String teacherName;
  final List<ActivityThreadMessageUi> thread;
  /// When thread is not loaded (history list), prefer this stored count.
  final int? listedResponseCount;
  final Set<String> respondentStudentIds;

  const HalaqaActivityUi({
    required this.id,
    required this.halaqaId,
    required this.prompt,
    required this.createdAt,
    required this.allowedResponseTypes,
    required this.teacherName,
    this.deadline,
    this.sharedToPosts = false,
    this.thread = const [],
    this.listedResponseCount,
    this.respondentStudentIds = const {},
  });

  int get responseCount {
    if (thread.isNotEmpty) {
      return thread
          .where((m) => !m.isTeacher)
          .map((m) => m.authorId)
          .toSet()
          .length;
    }
    return listedResponseCount ?? 0;
  }

  bool hasStudentResponded(String studentId) {
    if (thread.isNotEmpty) {
      return thread.any((m) => !m.isTeacher && m.authorId == studentId);
    }
    return respondentStudentIds.contains(studentId);
  }

  HalaqaActivityUi copyWith({
    String? prompt,
    DateTime? deadline,
    Set<ActivityResponseTypeUi>? allowedResponseTypes,
    bool? sharedToPosts,
    List<ActivityThreadMessageUi>? thread,
    int? listedResponseCount,
    Set<String>? respondentStudentIds,
  }) {
    return HalaqaActivityUi(
      id: id,
      halaqaId: halaqaId,
      prompt: prompt ?? this.prompt,
      createdAt: createdAt,
      deadline: deadline ?? this.deadline,
      allowedResponseTypes:
          allowedResponseTypes ?? this.allowedResponseTypes,
      sharedToPosts: sharedToPosts ?? this.sharedToPosts,
      teacherName: teacherName,
      thread: thread ?? this.thread,
      listedResponseCount: listedResponseCount ?? this.listedResponseCount,
      respondentStudentIds:
          respondentStudentIds ?? this.respondentStudentIds,
    );
  }
}

class ActivityThreadMessageUi {
  final String id;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final bool isTeacher;
  final String? text;
  /// Presentation placeholder — no real Storage URL required.
  final bool hasImage;
  final bool hasAudio;
  final String? imageLabel;
  final String? audioLabel;

  const ActivityThreadMessageUi({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.isTeacher,
    this.text,
    this.hasImage = false,
    this.hasAudio = false,
    this.imageLabel,
    this.audioLabel,
  });
}

extension ActivityResponseTypeUiLabel on ActivityResponseTypeUi {
  String get labelAr => switch (this) {
        ActivityResponseTypeUi.text => 'نص',
        ActivityResponseTypeUi.image => 'صورة',
        ActivityResponseTypeUi.audio => 'صوت',
      };
}
