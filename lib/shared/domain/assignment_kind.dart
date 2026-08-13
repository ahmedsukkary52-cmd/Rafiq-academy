/// Discriminator for documents in Firestore `assignments`.
///
/// Missing / unknown wire values are treated as [lessonHomework] so legacy
/// docs keep feeding «حفظ اليوم» without a migration.
enum AssignmentKind {
  lessonHomework,
  halaqaActivity;

  static const String wireLessonHomework = 'lessonHomework';
  static const String wireHalaqaActivity = 'halaqaActivity';

  String get wireValue => switch (this) {
        AssignmentKind.lessonHomework => wireLessonHomework,
        AssignmentKind.halaqaActivity => wireHalaqaActivity,
      };

  static AssignmentKind parse(Object? raw) {
    final value = raw is String ? raw.trim() : '';
    if (value == wireHalaqaActivity) return AssignmentKind.halaqaActivity;
    return AssignmentKind.lessonHomework;
  }

  static bool isLessonHomeworkWire(Object? raw) =>
      parse(raw) == AssignmentKind.lessonHomework;

  static bool isHalaqaActivityWire(Object? raw) =>
      parse(raw) == AssignmentKind.halaqaActivity;
}
