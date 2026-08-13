import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/presentation/halaqa_activities/halaqa_activities_mock_store.dart';
import 'package:rafiq_academy/shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';

/// Student presentation contracts from the approved UI batch (no DI).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const halaqaId = 'student_ui_batch_halaqa';

  setUp(() {
    final store = HalaqaActivitiesMockStore.instance;
    store.clearActivities(halaqaId);
    store.addActivity(
      halaqaId: halaqaId,
      prompt: 'اكتب جملة عن أهمية الحضور',
      allowedResponseTypes: {ActivityResponseTypeUi.text},
      teacherName: 'أ. اختبار',
    );
  });

  test('student list models expose reply state from respondent ids', () {
    final store = HalaqaActivitiesMockStore.instance;
    final activities = store.activitiesFor(halaqaId);
    expect(activities, isNotEmpty);
    expect(activities.first.prompt, contains('الحضور'));
    expect(
      store.replyStateForStudent(
        activity: activities.first,
        studentId: 's1',
      ),
      StudentActivityReplyState.notReplied,
    );
  });

  test('hasStudentResponded prefers thread when loaded', () {
    final a = HalaqaActivityUi(
      id: 'a1',
      halaqaId: halaqaId,
      prompt: 'p',
      createdAt: DateTime(2026, 8, 1),
      allowedResponseTypes: const {ActivityResponseTypeUi.text},
      teacherName: 't',
      respondentStudentIds: const {},
      thread: [
        ActivityThreadMessageUi(
          id: 'm1',
          authorId: 's1',
          authorName: 'أحمد',
          createdAt: DateTime(2026, 8, 1, 10),
          isTeacher: false,
          text: 'رد',
        ),
      ],
    );
    expect(a.hasStudentResponded('s1'), isTrue);
    expect(a.responseCount, 1);
  });
}
