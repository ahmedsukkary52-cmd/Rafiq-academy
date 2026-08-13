import 'halaqa_activity_ui_models.dart';

/// In-memory mock store for UI-first Tasks batch.
/// Shared by Teacher + Student presentation so create/reply feels connected.
class HalaqaActivitiesMockStore {
  HalaqaActivitiesMockStore._();

  static final HalaqaActivitiesMockStore instance =
      HalaqaActivitiesMockStore._();

  final Map<String, List<HalaqaActivityUi>> _byHalaqa = {};
  final Map<String, ActivityListLoadState> _loadState = {};
  final Map<String, String?> _loadError = {};

  List<HalaqaActivityUi> activitiesFor(String halaqaId) {
    _ensureSeeded(halaqaId);
    final list = List<HalaqaActivityUi>.from(_byHalaqa[halaqaId] ?? const []);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  ActivityListLoadState loadStateFor(String halaqaId) {
    _ensureSeeded(halaqaId);
    return _loadState[halaqaId] ?? ActivityListLoadState.loaded;
  }

  String? loadErrorFor(String halaqaId) => _loadError[halaqaId];

  HalaqaActivityUi? byId(String halaqaId, String activityId) {
    _ensureSeeded(halaqaId);
    for (final a in _byHalaqa[halaqaId] ?? const []) {
      if (a.id == activityId) return a;
    }
    return null;
  }

  /// Simulates a reload. [forceError] is for UI QA of error state.
  Future<void> reload(
    String halaqaId, {
    bool forceError = false,
  }) async {
    _loadState[halaqaId] = ActivityListLoadState.loading;
    _loadError[halaqaId] = null;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (forceError) {
      _loadState[halaqaId] = ActivityListLoadState.error;
      _loadError[halaqaId] = 'تعذر تحميل المهام. حاول مرة أخرى.';
      return;
    }
    _ensureSeeded(halaqaId);
    _loadState[halaqaId] = ActivityListLoadState.loaded;
  }

  void clearActivities(String halaqaId) {
    _byHalaqa[halaqaId] = [];
    _loadState[halaqaId] = ActivityListLoadState.loaded;
    _loadError[halaqaId] = null;
  }

  HalaqaActivityUi addActivity({
    required String halaqaId,
    required String prompt,
    required Set<ActivityResponseTypeUi> allowedResponseTypes,
    required String teacherName,
    DateTime? deadline,
    bool sharedToPosts = false,
  }) {
    _ensureSeeded(halaqaId);
    final activity = HalaqaActivityUi(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      halaqaId: halaqaId,
      prompt: prompt.trim(),
      createdAt: DateTime.now(),
      deadline: deadline,
      allowedResponseTypes: Set.of(allowedResponseTypes),
      sharedToPosts: sharedToPosts,
      teacherName: teacherName,
      thread: const [],
    );
    _byHalaqa[halaqaId] = [activity, ...?_byHalaqa[halaqaId]];
    _loadState[halaqaId] = ActivityListLoadState.loaded;
    return activity;
  }

  HalaqaActivityUi? appendStudentReply({
    required String halaqaId,
    required String activityId,
    required String studentId,
    required String studentName,
    String? text,
    bool hasImage = false,
    bool hasAudio = false,
    String? imageLabel,
    String? audioLabel,
  }) {
    final list = _byHalaqa[halaqaId];
    if (list == null) return null;
    final index = list.indexWhere((a) => a.id == activityId);
    if (index < 0) return null;

    final msg = ActivityThreadMessageUi(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      authorId: studentId,
      authorName: studentName,
      createdAt: DateTime.now(),
      isTeacher: false,
      text: text?.trim().isEmpty ?? true ? null : text!.trim(),
      hasImage: hasImage,
      hasAudio: hasAudio,
      imageLabel: imageLabel,
      audioLabel: audioLabel,
    );
    final updated = list[index].copyWith(
      thread: [...list[index].thread, msg],
    );
    final next = List<HalaqaActivityUi>.from(list);
    next[index] = updated;
    _byHalaqa[halaqaId] = next;
    return updated;
  }

  StudentActivityReplyState replyStateForStudent({
    required HalaqaActivityUi activity,
    required String studentId,
  }) {
    final replied = activity.thread.any(
      (m) => !m.isTeacher && m.authorId == studentId,
    );
    return replied
        ? StudentActivityReplyState.replied
        : StudentActivityReplyState.notReplied;
  }

  void _ensureSeeded(String halaqaId) {
    if (_byHalaqa.containsKey(halaqaId)) return;
    final now = DateTime.now();
    _byHalaqa[halaqaId] = [
      HalaqaActivityUi(
        id: 'seed_act_1_$halaqaId',
        halaqaId: halaqaId,
        prompt: 'ارسم مخططاً بسيطاً يوضح ترتيب سور جزء عمّ التي حفظتها هذا الأسبوع',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        deadline: now.add(const Duration(days: 2)),
        allowedResponseTypes: {
          ActivityResponseTypeUi.image,
          ActivityResponseTypeUi.text,
        },
        sharedToPosts: true,
        teacherName: 'أ. محمد العلي',
        thread: [
          ActivityThreadMessageUi(
            id: 'seed_msg_1',
            authorId: 'stu_ahmad',
            authorName: 'أحمد محمد',
            createdAt: now.subtract(const Duration(hours: 20)),
            isTeacher: false,
            text: 'رسمت الجدول في الدفتر وأرفقت الصورة.',
            hasImage: true,
            imageLabel: 'مخطط_جزء_عم.jpg',
          ),
          ActivityThreadMessageUi(
            id: 'seed_msg_2',
            authorId: 'stu_sara',
            authorName: 'سارة خالد',
            createdAt: now.subtract(const Duration(hours: 18)),
            isTeacher: false,
            text: 'هل يكفي مخطط ورقي أم تريد ملفاً رقمياً؟',
          ),
        ],
      ),
      HalaqaActivityUi(
        id: 'seed_act_2_$halaqaId',
        halaqaId: halaqaId,
        prompt: 'سجّل صوتياً آية من اختيارك مع ذكر سبب اختيارك في رسالة قصيرة',
        createdAt: now.subtract(const Duration(days: 3)),
        deadline: null,
        allowedResponseTypes: {
          ActivityResponseTypeUi.audio,
          ActivityResponseTypeUi.text,
        },
        sharedToPosts: false,
        teacherName: 'أ. محمد العلي',
        thread: [
          ActivityThreadMessageUi(
            id: 'seed_msg_3',
            authorId: 'stu_omar',
            authorName: 'عمر سالم',
            createdAt: now.subtract(const Duration(days: 2, hours: 4)),
            isTeacher: false,
            text: 'اخترت آية الكرسي لأنها تثبّتني.',
            hasAudio: true,
            audioLabel: 'تسجيل · ٠:٤٢',
          ),
        ],
      ),
    ];
    _loadState[halaqaId] = ActivityListLoadState.loaded;
  }
}
