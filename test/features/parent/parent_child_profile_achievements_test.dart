import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_state.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_child_achievements_usecase.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_bloc.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_state.dart';
import 'package:rafiq_academy/features/parent/presentation/pages/parent_child_profile_page.dart';
import 'package:rafiq_academy/features/parent/presentation/parent_child_access.dart';
import 'package:rafiq_academy/features/parent/presentation/widgets/parent_loading_skeletons.dart';
import 'package:rafiq_academy/shared/domain/achievement_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/student_profile_entity.dart';
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart';
import 'package:rafiq_academy/shared/domain/recitation_records_reader.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_profile_summary_reader_impl.dart';
import 'package:rafiq_academy/shared/domain/student_profile_summary.dart';

const _emptyText = 'لا توجد نشاطات أو إنجازات ممنوحة بعد.';
const _failure = 'تعذر تحميل الإنجازات. حاول مرة أخرى.';
const _retry = 'إعادة المحاولة';

class _FakeParentBloc extends Fake implements ParentBloc {
  _FakeParentBloc(this.state);

  @override
  ParentState state;

  @override
  Stream<ParentState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {}
}

class _FakeChatBloc extends Fake implements ChatConversationsBloc {
  @override
  ChatConversationsState get state => ChatConversationsState.initial();

  @override
  Stream<ChatConversationsState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

class _FakeStudentRepository extends Fake implements StudentRepository {
  @override
  Future<Either<Failure, StudentProfileEntity>> getStudentProfile(
    String studentId,
  ) async => Right(
    StudentProfileEntity(
      uid: studentId,
      name: 'أحمد',
      currentPlanName: 'خطة',
      overallProgressPercent: 40,
      totalStars: 0,
      badges: const [],
    ),
  );

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  ) async => const Right(<RecitationRecordEntity>[]);
}

typedef _Responder =
    Future<Either<Failure, List<AchievementEntity>>> Function(String studentId);

class _FakeParentRepository extends Fake implements ParentRepository {
  _FakeParentRepository(this.respond);

  _Responder respond;
  final List<String> requested = [];

  @override
  Future<Either<Failure, List<AchievementEntity>>> getChildAchievements(
    String studentId,
  ) {
    requested.add(studentId);
    return respond(studentId);
  }
}

AchievementEntity _award(String id, String title) => AchievementEntity(
  id: id,
  studentId: 's2',
  type: AchievementType.star,
  title: title,
  issuedBy: 'teacher1',
  date: DateTime(2026, 10, 5),
);

void _replace<T extends Object>(T instance) {
  if (sl.isRegistered<T>()) sl.unregister<T>();
  sl.registerSingleton<T>(instance);
}

void _remove<T extends Object>() {
  if (sl.isRegistered<T>()) sl.unregister<T>();
}

void main() {
  late _FakeParentRepository parentRepo;
  late _FakeParentBloc bloc;

  setUp(() {
    parentRepo = _FakeParentRepository(
      (_) async => const Right(<AchievementEntity>[]),
    );
    final studentRepo = _FakeStudentRepository();
    _replace<StudentProfileSummaryReader>(
      StudentProfileSummaryReaderImpl(studentRepo),
    );
    _replace<RecitationRecordsReader>(studentRepo);
    _replace<GetChildAchievementsUseCase>(
      GetChildAchievementsUseCase(parentRepo),
    );
    _replace<ChatConversationsBloc>(_FakeChatBloc());
    bloc = _FakeParentBloc(
      const ParentState(parentId: 'parent1', childrenIds: ['s1', 's2']),
    );
  });

  tearDown(() {
    _remove<StudentProfileSummaryReader>();
    _remove<RecitationRecordsReader>();
    _remove<GetChildAchievementsUseCase>();
    _remove<ChatConversationsBloc>();
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    String studentId = 's2',
  }) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ParentBloc>.value(
          value: bloc,
          child: ParentChildProfilePage(studentId: studentId),
        ),
      ),
    );
  }

  testWidgets('initial load shows the profile skeleton, then achievements', (
    tester,
  ) async {
    final pending = Completer<Either<Failure, List<AchievementEntity>>>();
    parentRepo.respond = (_) => pending.future;
    await pumpProfile(tester);
    await tester.pump();
    expect(find.byType(ParentChildProfileSkeleton), findsOneWidget);

    pending.complete(Right([_award('a1', 'نجمة الحفظ')]));
    await tester.pumpAndSettle();
    expect(find.byType(ParentChildProfileSkeleton), findsNothing);
    expect(find.text('نجمة الحفظ'), findsOneWidget);
  });

  testWidgets('successful results render in the activities section', (
    tester,
  ) async {
    parentRepo.respond = (_) async =>
        Right([_award('a1', 'نجمة الحفظ'), _award('a2', 'طالب الأسبوع')]);
    await pumpProfile(tester);
    await tester.pumpAndSettle();
    expect(find.text('نجمة الحفظ'), findsOneWidget);
    expect(find.text('طالب الأسبوع'), findsOneWidget);
    expect(find.text(_emptyText), findsNothing);
    expect(find.text(_retry), findsNothing);
  });

  testWidgets('a genuinely empty result keeps the empty message, no error', (
    tester,
  ) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();
    expect(find.text(_emptyText), findsOneWidget);
    expect(find.text(_failure), findsNothing);
    expect(find.text(_retry), findsNothing);
  });

  testWidgets(
    'a failed request shows an error with retry, not the empty state',
    (tester) async {
      parentRepo.respond = (_) async => const Left(ServerFailure(_failure));
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('أحمد'),
        findsWidgets,
        reason: 'the profile still renders',
      );
      expect(find.text(_failure), findsOneWidget);
      expect(find.text(_retry), findsOneWidget);
      expect(find.text(_emptyText), findsNothing);
    },
  );

  testWidgets('retry shows section loading, then the successful results', (
    tester,
  ) async {
    parentRepo.respond = (_) async => const Left(ServerFailure(_failure));
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    final pending = Completer<Either<Failure, List<AchievementEntity>>>();
    parentRepo.respond = (_) => pending.future;
    await tester.tap(find.text(_retry));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(_failure), findsNothing);
    expect(find.text(_emptyText), findsNothing);
    expect(find.byType(ParentChildProfileSkeleton), findsNothing);

    pending.complete(Right([_award('a1', 'نجمة الحفظ')]));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('نجمة الحفظ'), findsOneWidget);
    expect(find.text(_failure), findsNothing);
    expect(find.text(_retry), findsNothing);
  });

  testWidgets('retry re-requests the child this profile is open for', (
    tester,
  ) async {
    parentRepo.respond = (_) async => const Left(ServerFailure(_failure));
    await pumpProfile(tester, studentId: 's2');
    await tester.pumpAndSettle();
    expect(parentRepo.requested, ['s2']);

    parentRepo.respond = (_) async => const Right(<AchievementEntity>[]);
    await tester.tap(find.text(_retry));
    await tester.pumpAndSettle();
    expect(parentRepo.requested, ['s2', 's2']);
    expect(find.text(_emptyText), findsOneWidget);
  });

  testWidgets('unwired progress, verses and level are not shown as real data', (
    tester,
  ) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('parent-child-progress-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('٤٠'), findsNothing);
    expect(find.text('آية محفوظة'), findsNothing);
    expect(find.text('آية'), findsNothing);
    expect(find.textContaining('المستوى'), findsNothing);
  });

  testWidgets(
    'retry for a child no longer linked is denied without a request',
    (tester) async {
      parentRepo.respond = (_) async => const Left(ServerFailure(_failure));
      await pumpProfile(tester, studentId: 's2');
      await tester.pumpAndSettle();

      bloc.state = const ParentState(parentId: 'parent1', childrenIds: ['s1']);
      await tester.tap(find.text(_retry));
      await tester.pumpAndSettle();
      expect(parentRepo.requested, ['s2']);
      expect(find.text(ParentChildAccess.deniedMessage), findsOneWidget);
      expect(find.text(_emptyText), findsNothing);
    },
  );
}
