import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_child_achievements_usecase.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_bloc.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_state.dart';
import 'package:rafiq_academy/features/parent/presentation/pages/parent_achievements_page.dart';
import 'package:rafiq_academy/features/parent/presentation/parent_child_access.dart';
import 'package:rafiq_academy/shared/domain/achievement_entity.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

class _FakeParentBloc extends Fake implements ParentBloc {
  _FakeParentBloc(this.state);

  @override
  final ParentState state;

  @override
  Stream<ParentState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {}
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

AchievementEntity _award(String id, String title, DateTime date) =>
    AchievementEntity(
      id: id,
      studentId: 's1',
      type: AchievementType.star,
      title: title,
      issuedBy: 'teacher1',
      date: date,
    );

void main() {
  late _FakeParentRepository repo;

  setUp(() {
    repo = _FakeParentRepository(
      (_) async => const Right(<AchievementEntity>[]),
    );
    if (sl.isRegistered<GetChildAchievementsUseCase>()) {
      sl.unregister<GetChildAchievementsUseCase>();
    }
    sl.registerLazySingleton(() => GetChildAchievementsUseCase(repo));
  });

  tearDown(() {
    if (sl.isRegistered<GetChildAchievementsUseCase>()) {
      sl.unregister<GetChildAchievementsUseCase>();
    }
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    List<String> children = const ['s1'],
    String? studentId,
  }) async {
    final bloc = _FakeParentBloc(
      ParentState(parentId: 'parent1', childrenIds: children),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ParentBloc>.value(
          value: bloc,
          child: ParentAchievementsPage(studentId: studentId),
        ),
      ),
    );
  }

  testWidgets('shows the loading skeleton until the callable answers', (
    tester,
  ) async {
    final pending = Completer<Either<Failure, List<AchievementEntity>>>();
    repo.respond = (_) => pending.future;
    await pumpPage(tester);
    await tester.pump();
    expect(repo.requested, ['s1']);
    expect(find.text('لا توجد إنجازات بعد'), findsNothing);
    expect(find.byType(AppErrorWidget), findsNothing);

    pending.complete(const Right(<AchievementEntity>[]));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد إنجازات بعد'), findsOneWidget);
  });

  testWidgets('renders callable results newest first', (tester) async {
    repo.respond = (_) async => Right([
      _award('old', 'نجمة قديمة', DateTime(2026, 9, 1)),
      _award('new', 'نجمة جديدة', DateTime(2026, 10, 5)),
    ]);
    await pumpPage(tester);
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d == 'نجمة جديدة' || d == 'نجمة قديمة')
        .toList();
    expect(titles.first, 'نجمة جديدة');
    expect(
      titles.indexOf('نجمة جديدة'),
      lessThan(titles.indexOf('نجمة قديمة')),
    );
    expect(find.text('لا توجد إنجازات بعد'), findsNothing);
  });

  testWidgets('empty callable result shows the empty state', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('لا توجد إنجازات بعد'), findsOneWidget);
  });

  testWidgets('callable failure shows its message and retry reloads', (
    tester,
  ) async {
    repo.respond = (_) async =>
        const Left(ServerFailure('هذا الطالب غير مرتبط بحسابك'));
    await pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('هذا الطالب غير مرتبط بحسابك'), findsOneWidget);

    repo.respond = (_) async =>
        Right([_award('a1', 'نجمة', DateTime(2026, 10, 1))]);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(repo.requested, ['s1', 's1']);
    expect(find.byType(AppErrorWidget), findsNothing);
    expect(find.text('نجمة'), findsWidgets);
  });

  testWidgets(
    'an unlinked child is denied locally without calling the server',
    (tester) async {
      await pumpPage(tester, children: const ['s1'], studentId: 's9');
      await tester.pumpAndSettle();
      expect(repo.requested, isEmpty);
      expect(find.text(ParentChildAccess.deniedMessage), findsOneWidget);
    },
  );

  testWidgets('switching child requests that child only', (tester) async {
    await pumpPage(tester, children: const ['s1', 's2']);
    await tester.pumpAndSettle();
    expect(repo.requested, ['s1']);

    await tester.tap(find.byTooltip('اختيار الابن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طالب').last);
    await tester.pumpAndSettle();
    expect(repo.requested, ['s1', 's2']);
  });

  testWidgets('no linked children: no request and the empty state', (
    tester,
  ) async {
    await pumpPage(tester, children: const []);
    await tester.pumpAndSettle();
    expect(repo.requested, isEmpty);
    expect(find.text('لا توجد إنجازات بعد'), findsOneWidget);
  });

  test('parent presentation never queries achievements directly', () {
    final dir = Directory('lib/features/parent');
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final src = file.readAsStringSync();
      expect(src, isNot(contains('GetAchievementsUseCase')), reason: file.path);
      expect(
        src,
        isNot(contains('FirestoreCollections.achievements')),
        reason: file.path,
      );
      expect(
        src,
        isNot(contains("collection('achievements')")),
        reason: file.path,
      );
    }
  });
}
