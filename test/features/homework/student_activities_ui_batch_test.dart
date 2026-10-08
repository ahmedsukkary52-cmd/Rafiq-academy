import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';

ActivityThreadMessageUi _msg(String authorId, {bool isTeacher = false}) =>
    ActivityThreadMessageUi(
      id: 'm_$authorId',
      authorId: authorId,
      authorName: authorId,
      createdAt: DateTime(2026, 8, 1, 10),
      isTeacher: isTeacher,
      text: 'رد',
    );

HalaqaActivityUi _activity({
  List<ActivityThreadMessageUi> thread = const [],
  Set<String> respondentStudentIds = const {},
}) => HalaqaActivityUi(
  id: 'a1',
  halaqaId: 'h1',
  prompt: 'p',
  createdAt: DateTime(2026, 8, 1),
  allowedResponseTypes: const {ActivityResponseTypeUi.text},
  teacherName: 't',
  thread: thread,
  respondentStudentIds: respondentStudentIds,
);

/// Student "replied / not replied" state on the activities list.
void main() {
  test('list view uses stored respondent ids when thread is not loaded', () {
    final a = _activity(respondentStudentIds: const {'s1'});
    expect(a.hasStudentResponded('s1'), isTrue);
    expect(a.hasStudentResponded('s2'), isFalse);
  });

  test('loaded thread wins over stored respondent ids', () {
    final a = _activity(
      respondentStudentIds: const {'s2'},
      thread: [_msg('s1')],
    );
    expect(a.hasStudentResponded('s1'), isTrue);
    expect(a.hasStudentResponded('s2'), isFalse);
    expect(a.responseCount, 1);
  });

  test('teacher messages never count as the student replying', () {
    final a = _activity(thread: [_msg('s1', isTeacher: true)]);
    expect(a.hasStudentResponded('s1'), isFalse);
  });
}
