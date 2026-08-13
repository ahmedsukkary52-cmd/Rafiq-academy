import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/halaqa_activity/domain/entities/halaqa_activity_entity.dart';
import 'package:rafiq_academy/features/halaqa_activity/domain/repositories/halaqa_activity_repository.dart';
import 'package:rafiq_academy/features/halaqa_activity/domain/usecases/halaqa_activity_usecases.dart';
import 'package:rafiq_academy/features/halaqa_activity/presentation/halaqa_activity_ui_mapper.dart';
import 'package:rafiq_academy/features/notifications/domain/services/in_app_academy_signal_composer.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/domain/academy_event_observation.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';
import 'package:rafiq_academy/shared/domain/assignment_kind.dart';
import 'package:rafiq_academy/shared/domain/assignment_policy.dart';
import 'package:rafiq_academy/shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';

class _FakeHalaqaActivityRepository implements HalaqaActivityRepository {
  Either<Failure, AcademyEventPublication> publishResult =
      const Right(AcademyEventPublication.none());
  Either<Failure, List<HalaqaActivityEntity>> listResult =
      const Right(<HalaqaActivityEntity>[]);
  Either<Failure, HalaqaActivityEntity>? getResult;
  Either<Failure, HalaqaActivityResponseEntity>? submitResult;

  PublishHalaqaActivityParams? lastPublish;
  SubmitHalaqaActivityResponseParams? lastSubmit;
  String? lastListHalaqaId;
  String? lastGetHalaqaId;
  String? lastGetActivityId;

  final List<HalaqaActivityEntity> store = [];
  final Map<String, List<HalaqaActivityResponseEntity>> threads = {};

  @override
  Future<Either<Failure, AcademyEventPublication>> publishActivity({
    required String halaqaId,
    required String teacherId,
    required String teacherName,
    required String prompt,
    required Set<HalaqaActivityResponseType> allowedResponseTypes,
    DateTime? deadline,
    bool alsoShareAsPost = false,
  }) async {
    lastPublish = PublishHalaqaActivityParams(
      halaqaId: halaqaId,
      teacherId: teacherId,
      teacherName: teacherName,
      prompt: prompt,
      allowedResponseTypes: allowedResponseTypes,
      deadline: deadline,
      alsoShareAsPost: alsoShareAsPost,
    );
    if (publishResult.isLeft()) return publishResult;

    final entity = HalaqaActivityEntity(
      id: 'act_${store.length + 1}',
      halaqaId: halaqaId,
      teacherId: teacherId,
      teacherName: teacherName,
      prompt: prompt,
      createdAt: DateTime(2026, 8, 13, 12 - store.length),
      allowedResponseTypes: allowedResponseTypes,
      deadline: deadline,
      alsoShareAsPost: alsoShareAsPost,
    );
    store.insert(0, entity);
    return publishResult;
  }

  @override
  Future<Either<Failure, List<HalaqaActivityEntity>>> listActivitiesForHalaqa(
    String halaqaId,
  ) async {
    lastListHalaqaId = halaqaId;
    if (listResult.isLeft()) return listResult;
    final items = store.where((e) => e.halaqaId == halaqaId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Right(items);
  }

  @override
  Future<Either<Failure, HalaqaActivityEntity>> getActivity({
    required String halaqaId,
    required String activityId,
    bool includeThread = true,
  }) async {
    lastGetHalaqaId = halaqaId;
    lastGetActivityId = activityId;
    if (getResult != null) return getResult!;
    HalaqaActivityEntity? found;
    for (final e in store) {
      if (e.id == activityId && e.halaqaId == halaqaId) {
        found = e;
        break;
      }
    }
    if (found == null) {
      return const Left(ServerFailure('تعذر العثور على هذه المهمة'));
    }
    if (!includeThread) return Right(found);
    final thread = threads[activityId] ?? const [];
    return Right(
      found.copyWith(
        thread: thread,
        responseCount: thread.map((e) => e.studentId).toSet().length,
        respondentStudentIds: thread.map((e) => e.studentId).toSet(),
      ),
    );
  }

  @override
  Future<Either<Failure, HalaqaActivityResponseEntity>> submitResponse({
    required String activityId,
    required String halaqaId,
    required String studentId,
    required String studentName,
    String? text,
    File? imageFile,
    File? audioFile,
  }) async {
    lastSubmit = SubmitHalaqaActivityResponseParams(
      activityId: activityId,
      halaqaId: halaqaId,
      studentId: studentId,
      studentName: studentName,
      text: text,
      imageFile: imageFile,
      audioFile: audioFile,
    );
    if (submitResult != null) return submitResult!;

    final response = HalaqaActivityResponseEntity(
      id: 'r_${(threads[activityId]?.length ?? 0) + 1}',
      activityId: activityId,
      studentId: studentId,
      studentName: studentName,
      createdAt: DateTime.now(),
      text: text,
      imageUrl: imageFile == null ? null : 'https://example.com/img.jpg',
      audioUrl: audioFile == null ? null : 'https://example.com/a.m4a',
      imageLabel: imageFile?.uri.pathSegments.last,
      audioLabel: audioFile?.uri.pathSegments.last,
    );
    threads.putIfAbsent(activityId, () => []).add(response);
    return Right(response);
  }
}

void main() {
  group('AssignmentKind separation', () {
    test('missing kind defaults to lessonHomework', () {
      expect(AssignmentKind.parse(null), AssignmentKind.lessonHomework);
      expect(AssignmentKind.parse(''), AssignmentKind.lessonHomework);
      expect(AssignmentKind.parse('unknown'), AssignmentKind.lessonHomework);
      expect(
        AssignmentKind.parse(AssignmentKind.wireHalaqaActivity),
        AssignmentKind.halaqaActivity,
      );
    });

    test('AssignmentPolicy filters kinds for latest homework readers', () {
      expect(
        AssignmentPolicy.isLessonHomeworkData({
          AssignmentPolicy.kindField: AssignmentKind.wireLessonHomework,
        }),
        isTrue,
      );
      expect(
        AssignmentPolicy.isLessonHomeworkData({
          AssignmentPolicy.kindField: AssignmentKind.wireHalaqaActivity,
        }),
        isFalse,
      );
      expect(
        AssignmentPolicy.isHalaqaActivityData({
          AssignmentPolicy.kindField: AssignmentKind.wireHalaqaActivity,
        }),
        isTrue,
      );
      expect(AssignmentPolicy.isLessonHomeworkData({}), isTrue);
      expect(AssignmentPolicy.isHalaqaActivityData({}), isFalse);
      expect(AssignmentPolicy.latestScanLimit, greaterThan(AssignmentPolicy.latestLimit));
    });
  });

  group('PublishHalaqaActivityUseCase', () {
    test('rejects empty prompt and empty response types', () async {
      final repo = _FakeHalaqaActivityRepository();
      final useCase = PublishHalaqaActivityUseCase(repo);

      final emptyPrompt = await useCase(
        const PublishHalaqaActivityParams(
          halaqaId: 'h1',
          teacherId: 't1',
          teacherName: 'معلم',
          prompt: '   ',
          allowedResponseTypes: {HalaqaActivityResponseType.text},
        ),
      );
      expect(emptyPrompt.isLeft(), isTrue);

      final emptyTypes = await useCase(
        const PublishHalaqaActivityParams(
          halaqaId: 'h1',
          teacherId: 't1',
          teacherName: 'معلم',
          prompt: 'اكتب فقرة',
          allowedResponseTypes: {},
        ),
      );
      expect(emptyTypes.isLeft(), isTrue);
      expect(repo.lastPublish, isNull);
    });

    test('publishes whole-halaqa activity with optional deadline and types',
        () async {
      final repo = _FakeHalaqaActivityRepository();
      final useCase = PublishHalaqaActivityUseCase(repo);
      final deadline = DateTime(2026, 8, 20);

      final result = await useCase(
        PublishHalaqaActivityParams(
          halaqaId: 'h1',
          teacherId: 't1',
          teacherName: 'أ. أحمد',
          prompt: 'اكتب فقرة عن الصبر',
          allowedResponseTypes: {
            HalaqaActivityResponseType.text,
            HalaqaActivityResponseType.image,
          },
          deadline: deadline,
          alsoShareAsPost: true,
        ),
      );

      expect(result.isRight(), isTrue);
      expect(repo.lastPublish!.alsoShareAsPost, isTrue);
      expect(repo.lastPublish!.deadline, deadline);
      expect(repo.store.single.halaqaId, 'h1');
      expect(repo.store.single.kind, AssignmentKind.halaqaActivity);
    });

    test('surfaces empty-halaqa / publish guard from repository', () async {
      final repo = _FakeHalaqaActivityRepository()
        ..publishResult = const Left(
          ServerFailure('لا يوجد طلاب في هذه الحلقة لنشر المهمة'),
        );
      final useCase = PublishHalaqaActivityUseCase(repo);

      final result = await useCase(
        const PublishHalaqaActivityParams(
          halaqaId: 'empty',
          teacherId: 't1',
          teacherName: 'معلم',
          prompt: 'مهمة',
          allowedResponseTypes: {HalaqaActivityResponseType.text},
        ),
      );

      expect(
        result,
        const Left(ServerFailure('لا يوجد طلاب في هذه الحلقة لنشر المهمة')),
      );
    });
  });

  group('List / history ordering', () {
    test('lists newest first and halaqa-scoped only', () async {
      final repo = _FakeHalaqaActivityRepository();
      final publish = PublishHalaqaActivityUseCase(repo);
      await publish(
        const PublishHalaqaActivityParams(
          halaqaId: 'h1',
          teacherId: 't1',
          teacherName: 'معلم',
          prompt: 'أقدم',
          allowedResponseTypes: {HalaqaActivityResponseType.text},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      // Force newer createdAt via direct store insert for deterministic order.
      repo.store.insert(
        0,
        HalaqaActivityEntity(
          id: 'newer',
          halaqaId: 'h1',
          teacherId: 't1',
          teacherName: 'معلم',
          prompt: 'أحدث',
          createdAt: DateTime(2026, 8, 14),
          allowedResponseTypes: const {HalaqaActivityResponseType.text},
        ),
      );
      repo.store.add(
        HalaqaActivityEntity(
          id: 'other',
          halaqaId: 'h2',
          teacherId: 't1',
          teacherName: 'معلم',
          prompt: 'حلقة أخرى',
          createdAt: DateTime(2026, 8, 15),
          allowedResponseTypes: const {HalaqaActivityResponseType.text},
        ),
      );

      final listed = await ListHalaqaActivitiesUseCase(repo)(
        const HalaqaActivityHalaqaParams('h1'),
      );
      final items = listed.getOrElse((_) => const []);
      expect(items.map((e) => e.halaqaId).toSet(), {'h1'});
      expect(items.first.prompt, 'أحدث');
      expect(items.any((e) => e.prompt == 'حلقة أخرى'), isFalse);
    });
  });

  group('Student load / auth / thread', () {
    test('getActivity rejects wrong halaqa scope via repository failure',
        () async {
      final repo = _FakeHalaqaActivityRepository()
        ..getResult = const Left(
          ServerFailure('هذه المهمة خارج نطاق الحلقة'),
        );
      final result = await GetHalaqaActivityUseCase(repo)(
        const GetHalaqaActivityParams(
          halaqaId: 'h2',
          activityId: 'act_1',
        ),
      );
      expect(
        result,
        const Left(ServerFailure('هذه المهمة خارج نطاق الحلقة')),
      );
    });

    test('submitResponse builds threaded replies for same activity', () async {
      final repo = _FakeHalaqaActivityRepository();
      await PublishHalaqaActivityUseCase(repo)(
        const PublishHalaqaActivityParams(
          halaqaId: 'h1',
          teacherId: 't1',
          teacherName: 'معلم',
          prompt: 'شارك رأيك',
          allowedResponseTypes: {
            HalaqaActivityResponseType.text,
            HalaqaActivityResponseType.image,
          },
        ),
      );
      final activityId = repo.store.single.id;
      final submit = SubmitHalaqaActivityResponseUseCase(repo);

      await submit(
        SubmitHalaqaActivityResponseParams(
          activityId: activityId,
          halaqaId: 'h1',
          studentId: 's1',
          studentName: 'أحمد',
          text: 'ردي الأول',
        ),
      );
      await submit(
        SubmitHalaqaActivityResponseParams(
          activityId: activityId,
          halaqaId: 'h1',
          studentId: 's2',
          studentName: 'سارة',
          text: 'ردي الثاني',
        ),
      );

      final detail = await GetHalaqaActivityUseCase(repo)(
        GetHalaqaActivityParams(halaqaId: 'h1', activityId: activityId),
      );
      final entity = detail.getOrElse((_) => throw StateError('missing'));
      expect(entity.thread, hasLength(2));
      expect(entity.thread.first.text, 'ردي الأول');
      expect(entity.hasStudentResponded('s1'), isTrue);
    });

    test('submit rejects empty payload', () async {
      final repo = _FakeHalaqaActivityRepository();
      final result = await SubmitHalaqaActivityResponseUseCase(repo)(
        const SubmitHalaqaActivityResponseParams(
          activityId: 'a1',
          halaqaId: 'h1',
          studentId: 's1',
          studentName: 'أحمد',
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(repo.lastSubmit, isNull);
    });

    test('student authorization failure surfaces from repository', () async {
      final repo = _FakeHalaqaActivityRepository()
        ..submitResult = const Left(
          ServerFailure('غير مسموح بالرد على مهمة خارج حلقتك'),
        );
      final result = await SubmitHalaqaActivityResponseUseCase(repo)(
        const SubmitHalaqaActivityResponseParams(
          activityId: 'a1',
          halaqaId: 'h1',
          studentId: 'outsider',
          studentName: 'غريب',
          text: 'محاولة',
        ),
      );
      expect(
        result,
        const Left(ServerFailure('غير مسموح بالرد على مهمة خارج حلقتك')),
      );
    });
  });

  group('Deadline optional + allowed types + media capability', () {
    test('deadline may be null without failing publish', () async {
      final repo = _FakeHalaqaActivityRepository();
      await PublishHalaqaActivityUseCase(repo)(
        const PublishHalaqaActivityParams(
          halaqaId: 'h1',
          teacherId: 't1',
          teacherName: 'معلم',
          prompt: 'بدون موعد',
          allowedResponseTypes: {HalaqaActivityResponseType.text},
        ),
      );
      expect(repo.store.single.deadline, isNull);
    });

    test('audio capability flag remains gated', () {
      expect(AppCapabilities.audioUploadsEnabled, isFalse);
    });

    test('mapper preserves allowed response types', () {
      final entity = HalaqaActivityEntity(
        id: 'a1',
        halaqaId: 'h1',
        teacherId: 't1',
        teacherName: 'معلم',
        prompt: 'أرسل صورة',
        createdAt: DateTime(2026, 8, 1),
        allowedResponseTypes: const {
          HalaqaActivityResponseType.image,
          HalaqaActivityResponseType.audio,
        },
        deadline: DateTime(2026, 8, 10),
      );
      final ui = HalaqaActivityUiMapper.toUi(entity);
      expect(
        ui.allowedResponseTypes,
        {
          ActivityResponseTypeUi.image,
          ActivityResponseTypeUi.audio,
        },
      );
      expect(ui.deadline, DateTime(2026, 8, 10));
    });
  });

  group('Activity notifications (HalaqaActivityPublished)', () {
    test('observation includes student + linked parents', () {
      const event = HalaqaActivityPublished(
        activityId: 'act1',
        studentId: 's1',
        halaqaId: 'h1',
        assignedBy: 't1',
        prompt: 'اكتب فقرة',
      );
      final specs = AcademyEventObservation.specsFor(event);
      expect(specs, hasLength(2));
      expect(specs.whereType<SubjectStudentObserver>().single.studentId, 's1');
      expect(specs.whereType<LinkedParentsObserver>().single.studentId, 's1');
    });

    test('composer uses distinct title from HomeworkAssigned', () {
      const activity = HalaqaActivityPublished(
        activityId: 'act1',
        studentId: 's1',
        halaqaId: 'h1',
        assignedBy: 't1',
        prompt: 'اكتب فقرة قصيرة عن الصبر في العبادة',
      );
      final homework = HomeworkAssigned(
        assignmentId: 'hw1',
        studentId: 's1',
        halaqaId: 'h1',
        assignedBy: 't1',
        dueDate: DateTime(2026, 8, 1),
        newMemorizationRange: 'البقرة 1-5',
        reviewRange: '',
      );

      final activitySignal = InAppAcademySignalComposer.compose(
        events: [activity],
        observerIdsByEventId: {
          activity.eventId: ['s1'],
        },
      ).single;
      final homeworkSignal = InAppAcademySignalComposer.compose(
        events: [homework],
        observerIdsByEventId: {
          homework.eventId: ['s1'],
        },
      ).single;

      expect(activitySignal.title, 'مهمة جديدة للحلقة');
      expect(homeworkSignal.title, 'تكليف جديد');
      expect(activitySignal.type, NotificationTypes.assignment);
      expect(activitySignal.body, contains('الصبر'));
    });
  });

  group('Regression: lesson homework kind remains distinct', () {
    test('halaqaActivity never satisfies isLessonHomeworkData', () {
      final activityDoc = {
        AssignmentPolicy.kindField: AssignmentKind.wireHalaqaActivity,
        AssignmentPolicy.studentIdField: '',
        'prompt': 'نشاط',
        'tasks': <Map<String, dynamic>>[],
      };
      final lessonDoc = {
        AssignmentPolicy.kindField: AssignmentKind.wireLessonHomework,
        AssignmentPolicy.studentIdField: 's1',
        'newMemorizationRange': 'البقرة 1-5',
      };
      expect(AssignmentPolicy.isLessonHomeworkData(activityDoc), isFalse);
      expect(AssignmentPolicy.isLessonHomeworkData(lessonDoc), isTrue);
      expect(AssignmentPolicy.isHalaqaActivityData(activityDoc), isTrue);
    });
  });
}
