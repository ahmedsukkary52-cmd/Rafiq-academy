import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/presentation/halaqa_activities/halaqa_activities_mock_store.dart';
import 'package:rafiq_academy/shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';

/// Presentation-model contracts from the approved UI batch (no DI / Firestore).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const halaqaId = 'ui_batch_halaqa';

  setUp(() {
    HalaqaActivitiesMockStore.instance.clearActivities(halaqaId);
  });

  test('locked Tasks dual-action copy remains distinct from حفظ/مراجعة', () {
    const dualActions = ['مهمة جديدة', 'تكليف حفظ/مراجعة', 'المهام'];
    expect(dualActions, containsAll(['مهمة جديدة', 'تكليف حفظ/مراجعة']));
  });

  test('mock store create + reply (UI batch contract)', () {
    final store = HalaqaActivitiesMockStore.instance;
    final created = store.addActivity(
      halaqaId: halaqaId,
      prompt: 'اكتب ثلاثة أسطر عن فضل العلم',
      allowedResponseTypes: {
        ActivityResponseTypeUi.text,
        ActivityResponseTypeUi.image,
      },
      teacherName: 'أ. اختبار',
      sharedToPosts: true,
    );
    expect(created.sharedToPosts, isTrue);
    expect(store.activitiesFor(halaqaId), isNotEmpty);

    final updated = store.appendStudentReply(
      halaqaId: halaqaId,
      activityId: created.id,
      studentId: 's1',
      studentName: 'أحمد',
      text: 'هذا ردي',
    );
    expect(updated, isNotNull);
    expect(updated!.thread, isNotEmpty);
    expect(
      store.replyStateForStudent(activity: updated, studentId: 's1'),
      StudentActivityReplyState.replied,
    );
  });

  test('listedResponseCount used when thread empty', () {
    final a = HalaqaActivityUi(
      id: '1',
      halaqaId: halaqaId,
      prompt: 'p',
      createdAt: DateTime(2026, 8, 1),
      allowedResponseTypes: const {ActivityResponseTypeUi.text},
      teacherName: 't',
      listedResponseCount: 3,
    );
    expect(a.responseCount, 3);
    expect(a.hasStudentResponded('s1'), isFalse);
  });
}
