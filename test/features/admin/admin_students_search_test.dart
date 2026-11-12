import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_halaqa_roster_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_event.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_state.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_students_tab.dart';
import 'package:rafiq_academy/features/student_search/domain/entities/student_search_entry.dart';

class _FakeAdminBloc extends Fake implements AdminBloc {
  _FakeAdminBloc(this.state);

  @override
  AdminState state;

  @override
  Stream<AdminState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(AdminEvent event) {}

  @override
  Future<void> close() async {}
}

const _roster = [
  AdminHalaqaRosterEntity(
    id: 'h1',
    name: 'حلقة النور',
    teacherId: 't1',
    supervisorId: 's1',
    status: 'active',
    students: [
      AdminRosterStudentEntity(uid: 'u1', name: 'أحمد علي', isActive: true),
      AdminRosterStudentEntity(uid: 'u2', name: 'يوسف حسن', isActive: true),
    ],
  ),
];

Future<List<String>> _pump(
  WidgetTester tester, {
  List<StudentSearchEntry> results = const [],
}) async {
  final queries = <String>[];
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AdminBloc>.value(
        value: _FakeAdminBloc(
          const AdminState(
            rosterStatus: SectionStatus.loaded,
            studentRoster: _roster,
          ),
        ),
        child: AdminStudentsTab(
          search: (q) async {
            queries.add(q);
            return results;
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return queries;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('admin-students-search')),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets('hamza variants match the roster (normalized, not exact)', (
    tester,
  ) async {
    await _pump(tester);
    await _type(tester, 'احمد');
    await tester.tap(find.text('حلقة النور'));
    await tester.pump();
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('يوسف حسن'), findsNothing);
  });

  testWidgets('server prefix search adds students the roster lacks', (
    tester,
  ) async {
    final queries = await _pump(
      tester,
      results: const [
        StudentSearchEntry(
          studentId: 'u1',
          fullName: 'أحمد علي',
          fullNameNormalized: 'احمد علي',
          halaqaId: 'h1',
          halaqaName: 'حلقة النور',
          halaqaIds: ['h1'],
        ),
        StudentSearchEntry(
          studentId: 'u9',
          fullName: 'أحمد سامي',
          fullNameNormalized: 'احمد سامي',
          halaqaId: null,
          halaqaName: '',
          halaqaIds: [],
        ),
      ],
    );
    await _type(tester, 'إحمد');
    expect(queries, ['إحمد']);
    expect(find.text('نتائج أخرى في الأكاديمية'), findsOneWidget);
    expect(find.byKey(const Key('directory-u9')), findsOneWidget);
    expect(find.byKey(const Key('directory-u1')), findsNothing);
    expect(find.text('غير مسجّل في حلقة'), findsOneWidget);
  });

  testWidgets('one-letter queries never hit the server', (tester) async {
    final queries = await _pump(tester);
    await _type(tester, 'أ');
    expect(queries, isEmpty);
  });
}
