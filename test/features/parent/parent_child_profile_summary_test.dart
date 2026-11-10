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
import 'package:rafiq_academy/shared/domain/achievement_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_records_reader.dart';
import 'package:rafiq_academy/shared/domain/student_profile_summary.dart';

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

class _SummaryReader implements StudentProfileSummaryReader {
  _SummaryReader(this.result);

  Either<Failure, StudentProfileSummary> result;
  final requested = <String>[];

  @override
  Future<Either<Failure, StudentProfileSummary>> getStudentProfileSummary(
    String studentId,
  ) async {
    requested.add(studentId);
    return result;
  }
}

class _RecordsReader implements RecitationRecordsReader {
  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  ) async => const Right(<RecitationRecordEntity>[]);
}

class _ParentRepository extends Fake implements ParentRepository {
  @override
  Future<Either<Failure, List<AchievementEntity>>> getChildAchievements(
    String studentId,
  ) async => const Right(<AchievementEntity>[]);
}

const _summary = StudentProfileSummary(
  name: ' سارة ',
  halaqaName: 'حلقة النور',
  level: 3,
  overallProgressPercent: 55,
  totalVersesMemorized: 120,
);

void _replace<T extends Object>(T instance) {
  if (sl.isRegistered<T>()) sl.unregister<T>();
  sl.registerSingleton<T>(instance);
}

void _remove<T extends Object>() {
  if (sl.isRegistered<T>()) sl.unregister<T>();
}

void main() {
  late _SummaryReader summaries;
  late _FakeParentBloc bloc;

  setUp(() {
    summaries = _SummaryReader(const Right(_summary));
    _replace<StudentProfileSummaryReader>(summaries);
    _replace<RecitationRecordsReader>(_RecordsReader());
    _replace<GetChildAchievementsUseCase>(
      GetChildAchievementsUseCase(_ParentRepository()),
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

  Future<void> pumpProfile(WidgetTester tester, {String studentId = 's2'}) {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ParentBloc>.value(
          value: bloc,
          child: ParentChildProfilePage(studentId: studentId),
        ),
      ),
    );
  }

  testWidgets('shows the trimmed name, halaqa and level from the summary', (
    tester,
  ) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    expect(summaries.requested, ['s2']);
    expect(find.text('سارة'), findsWidgets);
    expect(find.text('حلقة النور - المستوى ٣'), findsOneWidget);
  });

  testWidgets('a profile failure shows the error with retry', (tester) async {
    summaries.result = const Left(ServerFailure('تعذر تحميل الملف'));
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل الملف'), findsOneWidget);
    expect(find.text('سارة'), findsNothing);
  });

  testWidgets('a child not linked to the parent is denied without a read', (
    tester,
  ) async {
    bloc.state = const ParentState(parentId: 'parent1', childrenIds: ['s1']);
    await pumpProfile(tester, studentId: 's2');
    await tester.pumpAndSettle();

    expect(summaries.requested, isEmpty);
    expect(find.text(ParentChildAccess.deniedMessage), findsOneWidget);
  });
}
