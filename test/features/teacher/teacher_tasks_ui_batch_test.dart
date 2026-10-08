import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';

ActivityThreadMessageUi _msg(String authorId, {bool isTeacher = false}) =>
    ActivityThreadMessageUi(
      id: 'm_$authorId',
      authorId: authorId,
      authorName: authorId,
      createdAt: DateTime(2026, 8, 1, 10),
      isTeacher: isTeacher,
      text: 'x',
    );

HalaqaActivityUi _activity({
  List<ActivityThreadMessageUi> thread = const [],
  int? listedResponseCount,
}) => HalaqaActivityUi(
  id: '1',
  halaqaId: 'h1',
  prompt: 'p',
  createdAt: DateTime(2026, 8, 1),
  allowedResponseTypes: const {ActivityResponseTypeUi.text},
  teacherName: 't',
  thread: thread,
  listedResponseCount: listedResponseCount,
);

/// Teacher activity list response counts.
void main() {
  test('listedResponseCount used when thread is not loaded', () {
    expect(_activity(listedResponseCount: 3).responseCount, 3);
    expect(_activity().responseCount, 0);
  });

  test('loaded thread counts distinct students, not messages or teacher', () {
    final a = _activity(
      listedResponseCount: 9,
      thread: [
        _msg('teacher', isTeacher: true),
        _msg('s1'),
        _msg('s1'),
        _msg('s2'),
      ],
    );
    expect(a.responseCount, 2);
  });

  test('teacher-only thread counts zero responses', () {
    final a = _activity(
      listedResponseCount: 4,
      thread: [_msg('teacher', isTeacher: true)],
    );
    expect(a.responseCount, 0);
  });
}
