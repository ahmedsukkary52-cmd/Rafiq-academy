import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/domain/admin_rewards_view.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_halaqa_roster_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_event.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_state.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_misc_pages.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/awards/domain/award_submission_id.dart';
import 'package:rafiq_academy/features/awards/domain/unresolved_award_store.dart';

class _Store implements UnresolvedAwardStore {
  final records = <String, String>{};
  @override
  Future<String?> read(String key) async => records[key];
  @override
  Future<void> write(String key, String record) async => records[key] = record;
  @override
  Future<void> remove(String key) async => records.remove(key);
}

class _AdminStub extends Cubit<AdminState> implements AdminBloc {
  _AdminStub(super.initialState);

  @override
  void add(AdminEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthStub extends Cubit<AuthState> implements AuthBloc {
  _AuthStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AdminRosterStudentEntity _s(String uid, String name) =>
    AdminRosterStudentEntity(uid: uid, name: name, isActive: true);

final _roster = [
  AdminHalaqaRosterEntity(
    id: 'h1',
    name: 'حلقة الفجر',
    teacherId: 't1',
    supervisorId: '',
    status: 'active',
    students: [_s('s1', 'أحمد علي'), _s('s2', 'إبراهيم')],
  ),
  AdminHalaqaRosterEntity(
    id: 'h2',
    name: 'حلقة العصر',
    teacherId: 't2',
    supervisorId: '',
    status: 'active',
    students: [_s('s2', 'إبراهيم')],
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required Future<List<AdminRewardHistoryEntry>> Function() history,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: _AuthStub(
            AuthAuthenticated(
              UserEntity(
                uid: 'admin1',
                name: 'مدير',
                role: 'admin',
                isActive: true,
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ),
        BlocProvider<AdminBloc>.value(
          value: _AdminStub(
            AdminState(
              rosterStatus: SectionStatus.loaded,
              studentRoster: _roster,
            ),
          ),
        ),
      ],
      child: MaterialApp(home: AdminRewardsPage(historyLoader: history)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    AwardSubmissionId.clearUnresolvedRegistry();
    await sl.reset();
    sl.registerLazySingleton<UnresolvedAwardStore>(_Store.new);
  });
  tearDown(() {
    AwardSubmissionId.clearUnresolvedRegistry();
    return sl.reset();
  });

  test('student options merge halaqat and search ignores alef variants', () {
    final options = rewardStudentOptions(_roster);
    expect(options, hasLength(2));
    final ibrahim = options.firstWhere((o) => o.uid == 's2');
    expect(ibrahim.halaqaContext, 'حلقة الفجر، حلقة العصر');
    expect(
      filterRewardStudents(options, 'ابراهيم').map((o) => o.uid),
      ['s2'],
    );
    expect(filterRewardStudents(options, '').length, 2);
  });

  test('history entries read the stored award fields', () {
    final single = AdminRewardHistoryEntry.fromMap('a1', {
      'title': 'نجم الحلقة',
      'type': 'performance_stars',
      'studentName': 'أحمد',
      'halaqaName': 'حلقة الفجر',
      'recipientStudentIds': ['s1'],
      'description': 'حفظ ممتاز',
    }, date: DateTime(2026, 10, 3));
    expect(single.typeLabel, 'نجوم الأداء');
    expect(single.recipientLabel, 'أحمد');
    final group = AdminRewardHistoryEntry.fromMap('a2', {
      'note': 'تميز جماعي',
      'type': 'achievement',
      'recipientCount': 7,
    }, date: null);
    expect(group.title, 'تميز جماعي');
    expect(group.recipientLabel, '7 طالب');
  });

  testWidgets('search narrows the picker, shows halaqa context, and the '
      'preview names the recipient and halaqa', (tester) async {
    await _pump(tester, history: () async => const []);
    expect(find.byKey(const Key('reward-history-empty')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reward-student-search')),
      'احمد',
    );
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('إبراهيم'), findsNothing);
    expect(find.text('حلقة الفجر'), findsWidgets);
    await tester.tap(find.text('أحمد علي').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'عنوان الجائزة'),
      'نجم الأسبوع',
    );
    await tester.pump();
    final preview = find.byKey(const Key('reward-preview'));
    expect(preview, findsOneWidget);
    expect(
      find.descendant(
        of: preview,
        matching: find.text('المستلم: أحمد علي · الحلقة: حلقة الفجر'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('نجمة · نجم الأسبوع')),
      findsOneWidget,
    );
    expect(find.text('السبب (اختياري)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reward-student-search')),
      'غير موجود',
    );
    await tester.pump();
    expect(find.byKey(const Key('reward-student-no-match')), findsOneWidget);
  });

  testWidgets('history lists recent awards; a failure offers retry', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      history: () async {
        calls++;
        if (calls == 1) throw 'تعذر تحميل سجل الجوائز';
        return [
          AdminRewardHistoryEntry(
            id: 'a1',
            title: 'نجم الحلقة',
            typeLabel: 'نجوم الأداء',
            studentName: 'أحمد علي',
            halaqaName: 'حلقة الفجر',
            recipientCount: 1,
            reason: 'حفظ ممتاز',
            date: DateTime(2026, 10, 3),
          ),
        ];
      },
    );
    expect(find.byKey(const Key('reward-history-error')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reward-history-error')),
        matching: find.text('إعادة المحاولة'),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byKey(const Key('reward-history-a1')), findsOneWidget);
    expect(find.text('نجم الحلقة'), findsOneWidget);
    expect(find.text('السبب: حفظ ممتاز'), findsOneWidget);
  });
}
