import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/complaints/data/complaints_repository.dart';
import 'package:rafiq_academy/features/complaints/domain/complaint.dart';
import 'package:rafiq_academy/features/complaints/presentation/complaint_widgets.dart';
import 'package:rafiq_academy/features/complaints/presentation/pages/complaint_details_page.dart';
import 'package:rafiq_academy/features/complaints/presentation/pages/complaints_list_page.dart';
import 'package:rafiq_academy/features/complaints/presentation/pages/submit_complaint_page.dart';

import '../../support/fake_callables.dart';

Complaint _complaint(String id, {ComplaintStatus status = ComplaintStatus.open}) =>
    Complaint(
      id: id,
      senderId: 'p1',
      senderRole: 'parent',
      senderName: 'ولي الأمر',
      subject: 'عنوان $id',
      message: 'تفاصيل $id',
      status: status,
      createdAt: DateTime(2026, 10, 30, 15, 5),
      studentName: 'أحمد',
    );

class _FakeRepo extends ComplaintsRepository {
  _FakeRepo() : super(firestore: UnusedFirestore(), functions: FakeFunctions());

  final fetches = <({String? senderId, ComplaintStatus? status, Object? cursor})>[];
  final responses = <({String? message, ComplaintStatus? status})>[];
  final submissions = <({String subject, String message, String? studentId})>[];
  List<List<Complaint>> pages = [];
  final complaint = StreamController<Complaint?>.broadcast();
  final history = StreamController<List<ComplaintHistoryEntry>>.broadcast();
  List<ComplaintContextOption> options = const [];

  @override
  Future<ComplaintPage> fetchPage({
    String? senderId,
    ComplaintStatus? status,
    Object? cursor,
    int limit = ComplaintsRepository.pageSize,
  }) async {
    fetches.add((senderId: senderId, status: status, cursor: cursor));
    final index = cursor as int? ?? 0;
    final items = index < pages.length ? pages[index] : const <Complaint>[];
    return ComplaintPage(
      items: items,
      cursor: index + 1 < pages.length ? index + 1 : null,
    );
  }

  @override
  Stream<Complaint?> watchComplaint(String id) => complaint.stream;

  @override
  Stream<List<ComplaintHistoryEntry>> watchHistory(String id) => history.stream;

  @override
  Future<ComplaintStatus> respond({
    required String complaintId,
    String? message,
    ComplaintStatus? status,
  }) async {
    responses.add((message: message, status: status));
    return status ?? ComplaintStatus.inProgress;
  }

  @override
  Future<String> submit({
    required String subject,
    required String message,
    String? studentId,
    String? halaqaId,
  }) async {
    submissions.add((subject: subject, message: message, studentId: studentId));
    return 'new1';
  }

  @override
  Future<List<ComplaintContextOption>> contextOptions({
    required String uid,
    required String role,
  }) async => options;
}

const _admin = ComplaintViewer(uid: 'a1', role: 'admin');
const _parent = ComplaintViewer(uid: 'p1', role: 'parent');

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('admin queue lists all complaints with sender, no severity', (
    tester,
  ) async {
    final repo = _FakeRepo()..pages = [[_complaint('c1'), _complaint('c2')]];
    await tester.pumpWidget(_app(ComplaintsListPage(viewer: _admin, repository: repo)));
    await tester.pumpAndSettle();

    expect(repo.fetches.single.senderId, isNull);
    expect(find.text('عنوان c1'), findsOneWidget);
    expect(find.textContaining('ولي الأمر · ولي أمر'), findsNWidgets(2));
    expect(find.textContaining('الطالب: أحمد'), findsNWidgets(2));
    for (final severity in ['عالية', 'منخفضة', 'عادية', 'الأولوية']) {
      expect(find.text(severity), findsNothing);
    }
    expect(find.byKey(const Key('complaints-new')), findsNothing);
  });

  testWidgets('admin status filter re-queries the server', (tester) async {
    final repo = _FakeRepo()..pages = [[_complaint('c1')]];
    await tester.pumpWidget(_app(ComplaintsListPage(viewer: _admin, repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ComplaintStatus.resolved.label).first);
    await tester.pumpAndSettle();
    expect(repo.fetches.last.status, ComplaintStatus.resolved);
    expect(repo.fetches.last.cursor, isNull);
  });

  testWidgets('pagination loads the next page on scroll', (tester) async {
    final repo = _FakeRepo()
      ..pages = [
        [for (var i = 0; i < 20; i++) _complaint('a$i')],
        [_complaint('b0')],
      ];
    await tester.pumpWidget(_app(ComplaintsListPage(viewer: _admin, repository: repo)));
    await tester.pumpAndSettle();
    expect(repo.fetches, hasLength(1));
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(repo.fetches, hasLength(2));
    expect(repo.fetches.last.cursor, 1);
  });

  testWidgets('complainant sees own history, empty state and new action', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(ComplaintsListPage(viewer: _parent, repository: repo)));
    await tester.pumpAndSettle();
    expect(repo.fetches.single.senderId, 'p1');
    expect(find.text('لم ترسل أي شكوى بعد'), findsOneWidget);
    expect(find.byKey(const Key('complaints-new')), findsOneWidget);
  });

  testWidgets('admin details: thread, reply and status change', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _app(ComplaintDetailsPage(complaintId: 'c1', viewer: _admin, repository: repo)),
    );
    repo.complaint.add(_complaint('c1'));
    await tester.pump();
    repo.history.add([
      ComplaintHistoryEntry(
        id: 'e1',
        authorId: 'a1',
        authorRole: 'admin',
        authorName: 'المدير',
        message: 'نتابع الأمر',
        statusFrom: ComplaintStatus.open,
        statusTo: ComplaintStatus.inProgress,
        createdAt: DateTime(2026, 10, 30, 16),
      ),
    ]);
    await tester.pump();

    expect(find.text('تفاصيل c1'), findsOneWidget);
    expect(find.text('نتابع الأمر'), findsOneWidget);
    expect(find.textContaining('«جديدة» إلى «قيد المعالجة»'), findsOneWidget);
    expect(find.textContaining('المرسل: ولي الأمر'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('complaint-reply-field')), 'تم الحل');
    await tester.tap(find.byKey(const Key('complaint-status-resolved')));
    await tester.pump();
    expect(repo.responses.single.status, ComplaintStatus.resolved);
    expect(repo.responses.single.message, 'تم الحل');
  });

  testWidgets('complainant details: reply only, no status controls', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _app(ComplaintDetailsPage(complaintId: 'c1', viewer: _parent, repository: repo)),
    );
    repo.complaint.add(_complaint('c1', status: ComplaintStatus.resolved));
    await tester.pump();
    expect(find.byKey(const Key('complaint-status-open')), findsNothing);
    expect(find.textContaining('المرسل:'), findsNothing);

    await tester.tap(find.byKey(const Key('complaint-reply-send')));
    await tester.pump();
    expect(repo.responses, isEmpty);

    await tester.enterText(find.byKey(const Key('complaint-reply-field')), 'ما زالت');
    await tester.tap(find.byKey(const Key('complaint-reply-send')));
    await tester.pump();
    expect(repo.responses.single, (message: 'ما زالت', status: null));
  });

  testWidgets('submit validates, attaches the chosen child and pops the id', (
    tester,
  ) async {
    final repo = _FakeRepo()
      ..options = const [ComplaintContextOption.student('s1', 'أحمد')];
    String? popped;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => SubmitComplaintPage(viewer: _parent, repository: repo),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('complaint-submit')));
    await tester.pump();
    expect(find.text('اكتب عنوان الشكوى'), findsOneWidget);
    expect(find.text('اكتب تفاصيل الشكوى'), findsOneWidget);
    expect(repo.submissions, isEmpty);

    await tester.tap(find.byKey(const Key('complaint-context')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أحمد').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('complaint-subject')), 'تأخر');
    await tester.enterText(find.byKey(const Key('complaint-message')), 'تفاصيل');
    await tester.tap(find.byKey(const Key('complaint-submit')));
    await tester.pumpAndSettle();

    expect(repo.submissions.single.studentId, 's1');
    expect(popped, 'new1');
  });
}
