import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/assistant/data/cover_duty_repository.dart';
import 'package:rafiq_academy/features/assistant/presentation/assistant_home_page.dart';

class _FakeDuty implements CoverDutyRepository {
  _FakeDuty(this.halaqat);

  final List<DutyHalaqa> halaqat;
  final requests = <({bool assistant, String uid})>[];
  final saved = <({String halaqaId, DateTime day, Map<String, String> marks})>[];
  String? refuse;

  @override
  Future<List<DutyHalaqa>> myHalaqat(String uid, {required bool assistant}) async {
    requests.add((assistant: assistant, uid: uid));
    return halaqat;
  }

  @override
  Future<List<DutyStudent>> roster(DutyHalaqa halaqa) async => const [
    DutyStudent(uid: 's1', name: 'يوسف محمد'),
    DutyStudent(uid: 's2', name: 'مريم محمد'),
  ];

  @override
  Future<void> recordAttendance({
    required String halaqaId,
    required DateTime day,
    required Map<String, String> marks,
  }) async {
    if (refuse != null) throw ServerException(refuse!);
    saved.add((halaqaId: halaqaId, day: day, marks: marks));
  }
}

const _assigned = DutyHalaqa(
  id: 'h2',
  name: 'حلقة العصر',
  teacherName: 'خالد حسن',
  studentIds: ['s7'],
  isCover: false,
  isAssigned: true,
);
const _covered = DutyHalaqa(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherName: 'أحمد علي',
  studentIds: ['s1', 's2'],
  isCover: true,
  isAssigned: true,
);

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('assigned halaqat are read-only; only an active cover can record', (tester) async {
    final repo = _FakeDuty([_covered, _assigned]);
    await tester.pumpWidget(_app(AssistantHomePage(repository: repo, uid: 'a1', name: 'خالد سعيد')));
    await tester.pumpAndSettle();

    expect(repo.requests.single, (assistant: true, uid: 'a1'));
    expect(find.text('تغطية مؤقتة نشطة'), findsOneWidget);
    expect(find.text('مساعد'), findsOneWidget);
    expect(find.textContaining('المعلم الأساسي: أحمد علي'), findsOneWidget);
    expect(find.byKey(const Key('duty-attendance-حلقة الفجر')), findsOneWidget);
    expect(find.byKey(const Key('duty-attendance-حلقة العصر')), findsNothing);
    expect(find.byKey(const Key('duty-readonly-حلقة العصر')), findsOneWidget);
    expect(find.byKey(const Key('assistant-logout')), findsOneWidget);
  });

  testWidgets('cover attendance is submitted to the server for today', (tester) async {
    final repo = _FakeDuty([_covered]);
    await tester.pumpWidget(_app(AssistantHomePage(repository: repo, uid: 'a1', name: 'خالد سعيد')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('duty-attendance-حلقة الفجر')));
    await tester.pumpAndSettle();
    expect(find.textContaining('يبقى أحمد علي معلم الحلقة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mark-مريم محمد-absent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cover-attendance-save')));
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.halaqaId, 'h1');
    expect(repo.saved.single.marks, {'s1': 'present', 's2': 'absent'});
    expect(find.byKey(const Key('cover-attendance-save')), findsNothing);
  });

  testWidgets('a server refusal (e.g. the cover ended) is shown', (tester) async {
    final repo = _FakeDuty([_covered])..refuse = 'انتهت التغطية المؤقتة';
    await tester.pumpWidget(_app(AssistantHomePage(repository: repo, uid: 'a1', name: 'خالد سعيد')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('duty-attendance-حلقة الفجر')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cover-attendance-save')));
    await tester.pumpAndSettle();
    expect(find.text('انتهت التغطية المؤقتة'), findsOneWidget);
    expect(find.byKey(const Key('cover-attendance-save')), findsOneWidget);
  });

  testWidgets('a covering teacher sees only cover halaqat', (tester) async {
    final repo = _FakeDuty([_covered]);
    await tester.pumpWidget(
      _app(AssistantHomePage(repository: repo, assistant: false, uid: 't2', name: 'خالد حسن')),
    );
    await tester.pumpAndSettle();
    expect(repo.requests.single, (assistant: false, uid: 't2'));
    expect(find.text('التغطية المؤقتة'), findsOneWidget);
    expect(find.byKey(const Key('assistant-logout')), findsNothing);
    expect(find.byKey(const Key('duty-attendance-حلقة الفجر')), findsOneWidget);
  });

  testWidgets('no assignment shows an honest empty state', (tester) async {
    await tester.pumpWidget(_app(AssistantHomePage(repository: _FakeDuty(const []), uid: 'a1', name: 'خالد')));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد حلقات معيّنة لك حالياً.'), findsOneWidget);
  });
}
