import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/data/academy_import_repository.dart';
import 'package:rafiq_academy/features/admin/domain/academy_import.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_academy_import_page.dart';

const _header =
    'type,ref,name,teacher_ref,supervisor_ref,parent_ref,halaqa_ref,schedule,meeting_link\n';

class _FakeImport extends Fake implements AcademyImportRepository {
  final calls = <String>[];
  final failOnce = <String>{};
  final importIds = <String>{};

  @override
  Future<ImportRowOutcome> importRow(String importId, ImportRow row) async {
    calls.add(row.ref);
    importIds.add(importId);
    if (failOnce.remove(row.ref)) {
      return ImportRowOutcome(row: row, status: ImportRowStatus.failed, message: 'انقطع الاتصال', retryable: true);
    }
    final account = row.kind != ImportRowKind.halaqa;
    return ImportRowOutcome(
      row: row,
      status: ImportRowStatus.created,
      message: 'تم',
      username: account ? 'u_${row.ref.toLowerCase()}' : null,
      temporaryPassword: account ? 'Pw${row.ref}x9' : null,
    );
  }
}

void main() {
  group('validation', () {
    test('the documented template is valid and ordered by dependency', () {
      final plan = validateAcademyImport(academyImportTemplate);
      expect(plan.issues, isEmpty);
      expect(plan.rows.map((r) => r.ref), ['T-001', 'V-001', 'A-001', 'P-001', 'H-001', 'S-001']);
      final halaqa = plan.rows.firstWhere((r) => r.kind == ImportRowKind.halaqa);
      expect(halaqa.schedule.map((s) => '${s.day} ${s.startTime}-${s.endTime}'), [
        'الأحد 16:00-17:00',
        'الثلاثاء 16:00-17:00',
      ]);
      expect(halaqa.toPayload()['teacherRef'], 'T-001');
      expect(halaqa.toPayload()['supervisorRef'], 'V-001');
      expect(halaqa.toPayload()['assistantRef'], 'A-001');
      expect(plan.rows.firstWhere((r) => r.ref == 'A-001').kind, ImportRowKind.assistant);
      expect(plan.rows.last.toPayload(), {'kind': 'student', 'ref': 'S-001', 'name': 'يوسف محمد', 'parentRef': 'P-001', 'halaqaRef': 'H-001'});
    });

    test('assistant_ref must point at an assistant row and is optional', () {
      const header =
          'type,ref,name,teacher_ref,supervisor_ref,assistant_ref,parent_ref,halaqa_ref,schedule,meeting_link\n';
      final plan = validateAcademyImport(
        '$header'
        'معلم,T-001,أحمد,,,,,,,\n'
        'مساعد,A-001,خالد,,,,,,,\n'
        'حلقة,H-001,حلقة الفجر,T-001,,A-001,,,الأحد 16:00-17:00,\n'
        'حلقة,H-002,حلقة العصر,T-001,,T-001,,,الأحد 17:00-18:00,\n' // not an assistant
        'حلقة,H-003,حلقة المغرب,T-001,,,,,الأحد 18:00-19:00,\n',
      );
      expect(plan.issues.where((i) => i.isError).map((i) => i.line), [5]);
      expect(plan.issues.firstWhere((i) => i.line == 5).message, contains('ليس مساعد مدرس'));
      expect(plan.rows.map((r) => r.ref), ['T-001', 'A-001', 'H-001', 'H-003']);
      expect(plan.rows.last.toPayload().containsKey('assistantRef'), isFalse);
    });

    test('detects duplicates, missing values, bad relationships and conflicting refs', () {
      final plan = validateAcademyImport(
        '$_header'
        'معلم,T1,أحمد,,,,,,\n'
        'مشرف,T1,سعاد,,,,,,\n' // conflicting ref
        'ولي أمر,P1,,,,,,,\n' // missing name
        'ولي أمر,P2,خالد,,,,,,\n'
        'حلقة,H1,حلقة الفجر,T1,,,,الأحد 16:00-17:00,\n'
        'حلقة,H2,حَلقة-الفجر,T1,,,,الاثنين 16:00-17:00,\n' // duplicate halaqa name
        'حلقة,H3,حلقة العصر,P2,,,,الأحد 17:00-18:00,\n' // teacher_ref is a parent
        'حلقة,H4,حلقة المغرب,T1,,,,,\n' // no schedule
        'طالب,ST1,يوسف,,,,H1,,\n' // no parent
        'طالب,ST2,عمر,,,P1,H1,,\n' // parent row invalid
        'طالب,ST3,زيد,,,P2,H2,,\n' // halaqa rejected
        'طالب,ST4,بكر,,,P9,,,\n' // unknown ref: warning only
        'معلم,T2,أحمد,,,,,,\n' // same name: warning
        'مدير,X1,سامي,,,,,,\n', // unknown type
      );
      expect(plan.hasErrors, isTrue);
      String at(int line) => plan.issues.where((i) => i.line == line).map((i) => i.message).join(' | ');
      expect(at(3), contains('مكرر'));
      expect(at(4), contains('الاسم'));
      expect(at(7), contains('مكرر'));
      expect(at(8), contains('ليس معلم'));
      expect(at(9), contains('بلا موعد'));
      expect(at(10), contains('بلا ولي أمر'));
      expect(at(11), contains('سطر غير صالح'));
      expect(at(12), contains('يعتمد على سجل به خطأ'));
      expect(plan.issues.firstWhere((i) => i.line == 13).isError, isFalse);
      expect(plan.issues.firstWhere((i) => i.line == 14).isError, isFalse);
      expect(at(15), contains('غير معروف'));
      expect(plan.rows.map((r) => r.ref), ['T1', 'P2', 'T2', 'H1', 'ST4']);
    });

    test('schedule and CSV edge cases', () {
      expect(() => parseSchedule('الأحد 17:00-16:00'), throwsFormatException);
      expect(() => parseSchedule('Funday 10:00-11:00'), throwsFormatException);
      expect(parseSchedule('الاحد 9:05-10:00 | الجمعه 18:00-19:30').map((s) => s.day), ['الأحد', 'الجمعة']);
      expect(parseCsv('\uFEFFa,"b, ""c"""\r\n\r\nd,e\n'), [
        ['a', 'b, "c"'],
        ['d', 'e'],
      ]);
      expect(validateAcademyImport('name,ref\nx,y').issues.single.message, contains('type'));
      expect(importRunId('abc'), matches(RegExp(r'^imp_[0-9a-f]{32}$')));
      expect(importRunId('abc'), importRunId('abc'));
      expect(importRunId('abc'), isNot(importRunId('abd')));
    });
  });

  group('import page', () {
    Future<void> pump(WidgetTester tester, _FakeImport repo, String csv) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAcademyImportPage(
            repository: repo,
            pickFile: () async => (name: 'roster.csv', content: csv),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('import-pick')));
      await tester.pumpAndSettle();
    }

    testWidgets('errors block the import before anything is created', (tester) async {
      final repo = _FakeImport();
      await pump(tester, repo, '$_header' 'طالب,ST1,يوسف,,,,,,\n');
      expect(find.byKey(const Key('import-blocked')), findsOneWidget);
      expect(find.textContaining('بلا ولي أمر'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import-start')));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
    });

    testWidgets('runs in order, shows credentials once, and retries only what failed', (tester) async {
      final repo = _FakeImport()..failOnce.add('H-001');
      await pump(tester, repo, academyImportTemplate);
      expect(find.text('معلم: 1'), findsOneWidget);
      expect(find.text('مساعد مدرس: 1'), findsOneWidget);
      expect(find.text('حلقة: 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('import-start')));
      await tester.pumpAndSettle();
      expect(repo.calls, ['T-001', 'V-001', 'A-001', 'P-001', 'H-001', 'S-001']);
      expect(find.textContaining('فشل: 1'), findsOneWidget);
      expect(find.byKey(const Key('import-failed-H-001')), findsOneWidget);
      expect(find.textContaining('يمكن إعادة المحاولة'), findsOneWidget);
      expect(find.textContaining('كلمة المرور المؤقتة: PwT-001x9'), findsOneWidget);
      expect(find.textContaining('حلقة الفجر · حلقة'), findsNothing);

      await tester.tap(find.byKey(const Key('import-start')));
      await tester.pumpAndSettle();
      expect(repo.calls.skip(6), ['H-001'], reason: 'only the failed row is re-sent');
      expect(find.textContaining('فشل: 0'), findsOneWidget);
      expect(repo.importIds, hasLength(1));
    });
  });
}
