import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/data/admin_reports_repository.dart';
import 'package:rafiq_academy/features/admin/domain/admin_reports.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_halaqa_roster_entity.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_payment_record.dart';
import 'package:rafiq_academy/features/admin/domain/entities/teacher_management_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/admin_report_pdf.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_event.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_state.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_reports_page.dart';

final _range = ReportRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

const _roster = [
  AdminHalaqaRosterEntity(
    id: 'h1',
    name: 'حلقة الفجر',
    teacherId: 't1',
    supervisorId: 's1',
    status: 'active',
    students: [
      AdminRosterStudentEntity(uid: 'st1', name: 'أحمد', isActive: true),
      AdminRosterStudentEntity(uid: 'st2', name: 'بلال', isActive: false),
    ],
  ),
  AdminHalaqaRosterEntity(
    id: 'h2',
    name: 'حلقة العصر',
    teacherId: 't2',
    supervisorId: 's1',
    status: 'active',
    students: [AdminRosterStudentEntity(uid: 'st3', name: 'خالد', isActive: true)],
  ),
];

AttendanceRow _att(String s, String h, String status, int day) => AttendanceRow(
  studentId: s,
  halaqaId: h,
  status: status,
  date: DateTime(2026, 10, day),
);

AdminPaymentRecord _pay(
  String id,
  double amount,
  String status, {
  double? confirmed,
  String? review,
  int day = 5,
}) => AdminPaymentRecord(
  id: id,
  studentId: 'st1',
  studentName: 'أحمد',
  parentId: 'p1',
  parentName: 'أبو أحمد',
  amount: amount,
  status: status,
  reviewStatus: review,
  dueDate: DateTime(2026, 10, day),
  periodKey: '2026-10',
  method: 'vodafone_cash',
  amountPaidConfirmed: confirmed,
);

const _teachers = [
  TeacherManagementEntity(
    uid: 't1',
    name: 'الأستاذ يوسف',
    halaqatIds: ['h1'],
    performanceRating: 4.5,
    weeklyQuota: 6,
    isActive: true,
  ),
  TeacherManagementEntity(
    uid: 't2',
    name: 'الأستاذ عمر',
    halaqatIds: [],
    weeklyQuota: 0,
    isActive: false,
    staffStatus: 'deactivated',
  ),
];

void main() {
  group('ReportRange', () {
    test('presets and validation', () {
      final jan = ReportRange.preset(ReportRangePreset.lastMonth, DateTime(2027, 1, 15));
      expect((jan.fromKey, jan.toKey), ('2026-12-01', '2026-12-31'));
      final month = ReportRange.preset(ReportRangePreset.thisMonth, DateTime(2026, 10, 31, 22));
      expect((month.fromKey, month.toKey), ('2026-10-01', '2026-10-31'));
      final last30 = ReportRange.preset(ReportRangePreset.last30Days, DateTime(2026, 10, 31));
      expect(last30.days, 30);
      expect(ReportRange(DateTime(2026, 10, 2), DateTime(2026, 10, 1)).problem, isNotNull);
      expect(ReportRange(DateTime(2025, 1, 1), DateTime(2026, 6, 1)).problem, isNotNull);
      expect(_range.contains(DateTime(2026, 10, 31, 23, 59)), isTrue);
      expect(_range.contains(DateTime(2026, 11, 1)), isFalse);
    });
  });

  test('students report counts attendance per student within the range', () {
    final t = buildStudentsReport(
      range: _range,
      roster: _roster,
      attendance: [
        _att('st1', 'h1', 'present', 2),
        _att('st1', 'h1', 'late', 3),
        _att('st1', 'h1', 'absent', 4),
        _att('st1', 'h1', 'present', 40), // outside the range (Nov 9)
        _att('st3', 'h2', 'excused', 5),
      ],
    );
    final ahmad = t.rows.firstWhere((r) => r[0] == 'أحمد');
    expect(ahmad, ['أحمد', 'حلقة الفجر', 'نشط', '1', '1', '1', '0', '67%']);
    expect(t.rows.firstWhere((r) => r[0] == 'بلال')[2], 'موقوف');
    expect(t.rows.firstWhere((r) => r[0] == 'بلال').last, '—');
    expect(t.summary, contains(('سجلات الحضور في الفترة', '4')));
    expect(t.summary, contains(('نسبة الحضور الإجمالية', '50%')));

    final h2 = buildStudentsReport(
      range: _range,
      roster: _roster,
      attendance: const [],
      halaqaId: 'h2',
    );
    expect(h2.rows.map((r) => r[0]), ['خالد']);
    expect(h2.filters, ['الحلقة: حلقة العصر']);
  });

  test('teachers report separates completed, unrecorded, cancelled and upcoming', () {
    final t = buildTeachersReport(
      range: _range,
      teachers: _teachers,
      now: DateTime(2026, 10, 20),
      sessions: const [
        SessionRow(teacherId: 't1', status: 'completed', date: '2026-10-02'),
        SessionRow(teacherId: 't1', status: 'completed', date: '2026-10-09'),
        SessionRow(teacherId: 't1', status: 'scheduled', date: '2026-10-16'),
        SessionRow(teacherId: 't1', status: 'cancelled', date: '2026-10-17'),
        SessionRow(teacherId: 't1', status: 'scheduled', date: '2026-10-23'),
        SessionRow(teacherId: 't1', status: 'completed', date: '2026-09-30'),
      ],
    );
    final yusuf = t.rows.firstWhere((r) => r[0] == 'الأستاذ يوسف');
    expect(yusuf, ['الأستاذ يوسف', 'نشط', '1', '6', '4.5', '2', '1', '1', '1', '67%']);
    final omar = t.rows.firstWhere((r) => r[0] == 'الأستاذ عمر');
    expect(omar.sublist(1, 5), ['معطّل', '0', 'غير محدد', 'لم يُحدد']);
  });

  test('finance report totals partial confirmations in EGP and filters by status', () {
    final payments = [
      _pay('a', 300, 'paid'),
      _pay('b', 200, 'due', confirmed: 50, review: 'pending_review'),
      _pay('c', 150, 'overdue', day: 2),
      _pay('d', 999, 'paid', day: 1).copyWithDue(DateTime(2026, 9, 30)),
    ];
    final t = buildFinanceReport(range: _range, payments: payments);
    expect(t.rows, hasLength(3));
    expect(t.rows.first[3], '2026-10-02', reason: 'sorted by due date');
    expect(t.headers[4], 'المبلغ (جنيه)');
    expect(t.summary, contains(('إجمالي المستحق', '650 جنيه')));
    expect(t.summary, contains(('إجمالي المحصّل', '350 جنيه')));
    expect(t.summary, contains(('المتبقي', '300 جنيه')));
    expect(t.summary, contains(('منه متأخر', '150 جنيه')));
    expect(t.summary, contains(('إيصالات بانتظار المراجعة', '1')));

    final paid = buildFinanceReport(
      range: _range,
      payments: payments,
      filter: PaymentLedgerFilter.paid,
    );
    expect(paid.rows, hasLength(1));
    expect(paid.filters, ['الحالة: مدفوع']);
  });

  test('CSV has a BOM, the period, a truncation notice and escaped cells', () {
    final t = ReportTable(
      title: 'التقرير المالي',
      range: _range,
      headers: const ['الاسم', 'ملاحظة'],
      rows: const [
        ['أحمد', 'دفعة, جزئية'],
      ],
      summary: const [('الإجمالي', '10 جنيه')],
      truncated: true,
    );
    final csv = t.toCsv();
    expect(csv.startsWith('\uFEFFالتقرير المالي'), isTrue);
    expect(csv, contains('الفترة,من 2026-10-01 إلى 2026-10-31'));
    expect(csv, contains(ReportTable.truncatedNotice));
    expect(csv, contains('أحمد,"دفعة, جزئية"'));
    expect(csv, contains('الإجمالي,10 جنيه'));
    expect(t.fileStem, 'basma_finance_2026-10-01_2026-10-31');
  });

  group('bundled report font', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('Noto Naskh Arabic ships with the app and its OFL license', () async {
      for (final asset in [
        reportFontRegularAsset,
        reportFontBoldAsset,
        'assets/fonts/NotoNaskhArabic-OFL.txt',
      ]) {
        final data = await rootBundle.load(asset);
        expect(data.lengthInBytes, greaterThan(1000), reason: asset);
      }
      final license = await rootBundle.loadString(
        'assets/fonts/NotoNaskhArabic-OFL.txt',
      );
      expect(license, contains('SIL Open Font License, Version 1.1'));
    });

    test('PDF renders Arabic RTL content with the bundled font', () async {
      final fonts = await loadReportFonts(bundle: rootBundle);
      final table = buildFinanceReport(
        range: _range,
        payments: [_pay('a', 300, 'paid'), _pay('b', 200, 'due', confirmed: 50)],
      );
      final bytes = await buildReportPdf(
        table,
        fonts: fonts,
        generatedAt: DateTime(2026, 10, 31),
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(latin1.decode(bytes), contains('NotoNaskhArabic'));
    });

    test('every character a report can contain has a glyph in the PDF fonts', () async {
      final fonts = await loadReportFonts(bundle: rootBundle);
      final missing = <String>[];
      final fallback = pw.Font.helvetica().getFont(pw.Context(document: PdfDocument()));
      final base = fonts.base.getFont(pw.Context(document: PdfDocument()));
      const sample = 'أكاديمية رفيق - الفترة: من 2026-10-01 إلى 2026-10-31 '
          '(50%) 1 / 3 جنيه، الملخص: متأخر — ٠١٢٣';
      for (final rune in reportPdfText(sample).runes) {
        final ch = String.fromCharCode(rune);
        if (ch.trim().isEmpty) continue;
        if (!base.isRuneSupported(rune) && !fallback.isRuneSupported(rune)) {
          missing.add(ch);
        }
      }
      expect(missing, isEmpty);
      expect(reportPdfText('—'), '-');
    });

    test('a missing font asset fails the load instead of producing a PDF', () async {
      await expectLater(
        loadReportFonts(bundle: _EmptyBundle()),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('AdminReportsPage', () {
    late _Repo repo;
    late _AdminBlocStub bloc;
    final saved = <(String, Uint8List)>[];
    final shared = <String>[];
    var shareFails = false;

    setUp(() {
      shareFails = false;
      repo = _Repo();
      bloc = _AdminBlocStub(
        const AdminState(
          rosterStatus: SectionStatus.loaded,
          studentRoster: _roster,
          teachersStatus: SectionStatus.loaded,
          teachers: _teachers,
        ),
      );
      saved.clear();
      shared.clear();
    });

    Future<void> pump(WidgetTester tester, {ReportFontLoader? fonts}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AdminBloc>.value(
            value: bloc,
            child: AdminReportsPage(
              repository: repo,
              clock: () => DateTime(2026, 10, 20),
              fontLoader: fonts ?? () async => throw Exception('offline'),
              saveFile: (name, bytes) async {
                saved.add((name, bytes));
                return true;
              },
              sharePdf: (name, bytes) async {
                if (shareFails) throw Exception('share failed');
                shared.add(name);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('finance report: preview, filter, CSV file, PDF font failure', (
      tester,
    ) async {
      repo.payments_ = [_pay('a', 300, 'paid'), _pay('c', 150, 'overdue', day: 2)];
      await pump(tester);

      expect(find.byKey(const Key('report-range-label')), findsOneWidget);
      expect(find.text('من 2026-10-01 إلى 2026-10-20'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-type-finance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-payment-overdue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-generate')));
      await tester.pumpAndSettle();

      expect(repo.paymentCalls.single, (
        '2026-10-01',
        '2026-10-20',
        PaymentLedgerFilter.overdue,
      ));
      expect(find.byKey(const Key('report-preview')), findsOneWidget);
      expect(find.text('150 جنيه'), findsWidgets);

      await tester.tap(find.byKey(const Key('report-export-csv')));
      await tester.pumpAndSettle();
      expect(saved.single.$1, 'basma_finance_2026-10-01_2026-10-20.csv');
      expect(saved.single.$2.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final csv = utf8.decode(saved.single.$2);
      expect(csv, contains('الحالة: متأخر'));
      expect(find.text('تم حفظ ملف CSV'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-export-pdf')));
      await tester.pumpAndSettle();
      expect(shared, isEmpty);
      expect(find.text(reportFontUnavailableMessage), findsOneWidget);
    });

    testWidgets('PDF export with the bundled font shares the file; a share '
        'failure is reported, never shown as success', (tester) async {
      repo.payments_ = [_pay('a', 300, 'paid')];
      final fonts = await tester.runAsync(
        () => loadReportFonts(bundle: rootBundle),
      );
      await pump(tester, fonts: () async => fonts!);
      await tester.tap(find.byKey(const Key('report-type-finance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-generate')));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('report-export-pdf')));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      expect(shared, ['basma_finance_2026-10-01_2026-10-20.pdf']);
      expect(find.text(reportFontUnavailableMessage), findsNothing);
      expect(find.text('تعذر إنشاء ملف PDF'), findsNothing);

      shareFails = true;
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('report-export-pdf')));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      expect(shared, hasLength(1));
      expect(find.text('تعذر إنشاء ملف PDF'), findsOneWidget);
    });

    testWidgets('students report by halaqa; a load failure is shown, not hidden', (
      tester,
    ) async {
      repo.attendance_ = [_att('st3', 'h2', 'present', 3)];
      await pump(tester);

      await tester.tap(find.byKey(const Key('report-range-lastMonth')));
      await tester.pumpAndSettle();
      expect(find.text('من 2026-09-01 إلى 2026-09-30'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-halaqa')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حلقة العصر').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-generate')));
      await tester.pumpAndSettle();
      expect(repo.attendanceCalls.single, ('2026-09-01', 'h2'));
      expect(find.text('خالد'), findsOneWidget);
      expect(find.text('أحمد'), findsNothing);

      repo.error = const ServerException('تعذر تحميل بيانات التقرير. تحقق من الاتصال.');
      await tester.tap(find.byKey(const Key('report-type-teachers')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-preview')), findsNothing);
      await tester.tap(find.byKey(const Key('report-generate')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-error')), findsOneWidget);
      expect(find.byKey(const Key('report-export-csv')), findsNothing);
    });

    testWidgets('truncated data is flagged in the preview', (tester) async {
      repo
        ..sessions_ = const [
          SessionRow(teacherId: 't1', status: 'completed', date: '2026-10-02'),
        ]
        ..truncated = true;
      await pump(tester);
      await tester.tap(find.byKey(const Key('report-type-teachers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-generate')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-truncated')), findsOneWidget);
    });
  });
}

extension on AdminPaymentRecord {
  AdminPaymentRecord copyWithDue(DateTime due) => AdminPaymentRecord(
    id: id,
    studentId: studentId,
    studentName: studentName,
    parentId: parentId,
    parentName: parentName,
    amount: amount,
    status: status,
    dueDate: due,
  );
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Unable to load asset: $key');
}

class _AdminBlocStub extends Cubit<AdminState> implements AdminBloc {
  _AdminBlocStub(super.initialState);

  final events = <AdminEvent>[];

  @override
  void add(AdminEvent event) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo extends Fake implements AdminReportsRepository {
  List<AttendanceRow> attendance_ = const [];
  List<SessionRow> sessions_ = const [];
  List<AdminPaymentRecord> payments_ = const [];
  bool truncated = false;
  ServerException? error;
  final attendanceCalls = <(String, String?)>[];
  final paymentCalls = <(String, String, PaymentLedgerFilter)>[];

  @override
  Future<Capped<AttendanceRow>> attendance(ReportRange range, {String? halaqaId}) async {
    if (error != null) throw error!;
    attendanceCalls.add((range.fromKey, halaqaId));
    return (items: attendance_, truncated: truncated);
  }

  @override
  Future<Capped<SessionRow>> sessions(ReportRange range) async {
    if (error != null) throw error!;
    return (items: sessions_, truncated: truncated);
  }

  @override
  Future<Capped<AdminPaymentRecord>> payments(
    ReportRange range, {
    PaymentLedgerFilter filter = PaymentLedgerFilter.all,
  }) async {
    if (error != null) throw error!;
    paymentCalls.add((range.fromKey, range.toKey, filter));
    return (items: payments_, truncated: truncated);
  }
}
