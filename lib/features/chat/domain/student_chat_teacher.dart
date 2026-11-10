/// The teacher the signed-in student's chat gate should open.
class StudentChatTeacher {
  final String? teacherUid;

  /// Whether the student has a halaqa; picks the message shown when
  /// [teacherUid] could not be resolved.
  final bool hasHalaqa;

  const StudentChatTeacher({this.teacherUid, required this.hasHalaqa});
}

abstract interface class StudentChatTeacherResolver {
  Future<StudentChatTeacher> resolveTeacher();
}
