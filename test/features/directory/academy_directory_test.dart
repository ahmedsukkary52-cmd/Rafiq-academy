import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/academy_data_revision.dart';
import 'package:rafiq_academy/features/directory/domain/directory_models.dart';
import 'package:rafiq_academy/features/directory/presentation/admin_add_member_page.dart';
import 'package:rafiq_academy/features/directory/presentation/admin_directory_page.dart';
import 'package:rafiq_academy/features/directory/presentation/admin_halaqa_profile_page.dart';
import 'package:rafiq_academy/features/directory/presentation/admin_person_profile_page.dart';
import 'package:rafiq_academy/features/directory/presentation/directory_navigation.dart';

import 'fake_academy.dart';

/// Pushes real profile pages backed by the same fake, so navigation can be
/// followed in both directions.
class PushingNavigator extends DirectoryNavigator {
  PushingNavigator(this.repo);

  final FakeAcademy repo;
  final log = <String>[];

  @override
  void openPerson(BuildContext context, String uid) {
    log.add('person:$uid');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminPersonProfilePage(uid: uid, repository: repo, navigator: this),
      ),
    );
  }

  @override
  void openHalaqa(BuildContext context, String halaqaId) {
    log.add('halaqa:$halaqaId');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminHalaqaProfilePage(halaqaId: halaqaId, repository: repo, navigator: this),
      ),
    );
  }

  @override
  void addChild(BuildContext context, DirectoryPerson parent) => log.add('addChild:${parent.uid}');

  @override
  void addStudent(BuildContext context) => log.add('addStudent');

  @override
  void addMember(BuildContext context, DirectoryRole role) => log.add('addMember:${role.wire}');

  @override
  void addAdmin(BuildContext context) => log.add('addAdmin');
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _pumpTall(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(900, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(child));
  await tester.pumpAndSettle();
}

Finder _keyPrefix(String prefix) => find.byWidgetPredicate(
  (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefix),
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _typeAndWait(WidgetTester tester, Finder f, String text) async {
  await tester.enterText(f, text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// No raw document id may be rendered anywhere.
void _expectNoRawIds(Iterable<String> ids) {
  for (final id in ids) {
    expect(find.text(id), findsNothing, reason: id);
    expect(find.textContaining(' $id'), findsNothing, reason: id);
  }
}

const _uids = ['p1', 's1', 's2', 's3', 't1', 't2', 'v1', 'v2', 'a1', 'h1'];

void main() {
  group('academy directory list', () {
    testWidgets('people are loaded one bounded page at a time', (tester) async {
      final repo = FakeAcademy.seeded(pageSize: 2)
        ..addPerson('s4', 'أنس كمال', DirectoryRole.student, 'S-004')
        ..addPerson('s5', 'هدى سامي', DirectoryRole.student, 'S-005');
      await _pumpTall(tester, AdminDirectoryPage(repository: repo, navigator: PushingNavigator(repo)));

      await _tap(tester, find.byKey(const Key('dir-tab-student')));
      expect(_keyPrefix('dir-person-'), findsNWidgets(2));
      await _tap(tester, find.byKey(const Key('dir-more-student')));
      expect(_keyPrefix('dir-person-'), findsNWidgets(4));
      await _tap(tester, find.byKey(const Key('dir-more-student')));
      expect(_keyPrefix('dir-person-'), findsNWidgets(5));
      expect(find.byKey(const Key('dir-more-student')), findsNothing);

      final studentCalls = repo.browseCalls.where((c) => c.role == DirectoryRole.student).toList();
      expect(studentCalls.map((c) => c.cursor), [null, 2, 4]);
      expect(studentCalls.every((c) => c.returned <= 2), isTrue);
      _expectNoRawIds(_uids);
    });

    testWidgets('search by academy code or by name', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminDirectoryPage(repository: repo, navigator: PushingNavigator(repo)));
      await _tap(tester, find.byKey(const Key('dir-tab-student')));

      await _typeAndWait(tester, find.byKey(const Key('dir-search-student')), 's2');
      expect(_keyPrefix('dir-person-'), findsOneWidget);
      expect(find.byKey(const Key('dir-person-S-002')), findsOneWidget);
      expect(find.text('طالب · S-002'), findsOneWidget);

      await _typeAndWait(tester, find.byKey(const Key('dir-search-student')), 'محمد');
      expect(find.byKey(const Key('dir-person-S-001')), findsOneWidget);
      expect(find.byKey(const Key('dir-person-S-002')), findsOneWidget);
      expect(find.byKey(const Key('dir-person-S-003')), findsNothing);
    });

    testWidgets('halaqa codes show in the list, search by code and on the profile', (tester) async {
      final repo = FakeAcademy.seeded();
      repo.halaqat['h2'] = FakeHalaqa('h2', 'حلقة المغرب', 'H-003', teacher: 't2');
      final nav = PushingNavigator(repo);
      await _pumpTall(tester, AdminDirectoryPage(repository: repo, navigator: nav));
      await _tap(tester, find.byKey(const Key('dir-tab-halaqat')));

      expect(find.text('حلقة الفجر · H-001'), findsOneWidget);
      expect(find.text('حلقة المغرب · H-003'), findsOneWidget);

      await _typeAndWait(tester, find.byKey(const Key('dir-search-halaqat')), 'h3');
      expect(find.byKey(const Key('dir-halaqa-حلقة المغرب')), findsOneWidget);
      expect(find.byKey(const Key('dir-halaqa-حلقة الفجر')), findsNothing);

      await _tap(tester, find.byKey(const Key('dir-halaqa-حلقة المغرب')));
      expect(nav.log, ['halaqa:h2']);
      expect(find.text('H-003'), findsOneWidget); // profile subtitle
      _expectNoRawIds(['h2', 't2']);
    });

    testWidgets('overview shows real counts that open the matching filtered list', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminDirectoryPage(repository: repo, navigator: PushingNavigator(repo)));

      final row = find.byKey(const Key('overview-طلاب بلا حلقة'));
      expect(find.descendant(of: row, matching: find.text('1')), findsOneWidget);
      await _tap(tester, row);

      expect(_keyPrefix('dir-person-'), findsOneWidget);
      expect(find.byKey(const Key('dir-person-S-003')), findsOneWidget);
      expect(repo.browseCalls.last.relation, DirectoryRelationFilter.studentsWithoutHalaqa);
    });

    testWidgets('add buttons: students via the guardian wizard, admins via admin accounts', (tester) async {
      final repo = FakeAcademy.seeded();
      final nav = PushingNavigator(repo);
      await _pumpTall(tester, AdminDirectoryPage(repository: repo, navigator: nav));

      await _tap(tester, find.byKey(const Key('dir-tab-student')));
      await _tap(tester, find.byKey(const Key('dir-add-student')));
      await _tap(tester, find.byKey(const Key('dir-tab-assistant_teacher')));
      await _tap(tester, find.byKey(const Key('dir-add-assistant_teacher')));
      await _tap(tester, find.byKey(const Key('dir-tab-admin')));
      await _tap(tester, find.byKey(const Key('dir-add-admin')));
      expect(nav.log, ['addStudent', 'addMember:assistant_teacher', 'addAdmin']);
    });
  });

  group('profiles agree from both sides', () {
    testWidgets('parent → child → teacher, all by name and code', (tester) async {
      final repo = FakeAcademy.seeded();
      final nav = PushingNavigator(repo);
      await _pumpTall(tester, AdminPersonProfilePage(uid: 'p1', repository: repo, navigator: nav));

      expect(find.text('ولي أمر · P-001'), findsWidgets);
      expect(find.byKey(const Key('person-S-001')), findsOneWidget);
      expect(find.byKey(const Key('person-S-002')), findsOneWidget);
      expect(find.byKey(const Key('halaqa-link-حلقة الفجر')), findsNWidgets(2));
      expect(find.byKey(const Key('staff-chip-المعلم-أحمد علي')), findsNWidgets(2));
      _expectNoRawIds(_uids);

      await _tap(tester, find.byKey(const Key('person-S-001')));
      expect(find.text('طالب · S-001'), findsWidgets);
      expect(find.byKey(const Key('person-P-001')), findsOneWidget);
      expect(find.byKey(const Key('person-S-002')), findsOneWidget); // sibling
      expect(find.byKey(const Key('halaqa-link-حلقة الفجر')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('staff-chip-المعلم-أحمد علي')));
      expect(find.text('معلم · T-001'), findsWidgets);
      expect(find.textContaining('المعلم الأساسي'), findsWidgets);
      expect(find.byKey(const Key('person-S-001')), findsOneWidget);
      expect(find.byKey(const Key('person-S-002')), findsOneWidget);
      expect(nav.log, ['person:s1', 'person:t1']);
      _expectNoRawIds(_uids);
    });

    testWidgets('halaqa → students with parents → supervisor', (tester) async {
      final repo = FakeAcademy.seeded();
      final nav = PushingNavigator(repo);
      await _pumpTall(tester, AdminHalaqaProfilePage(halaqaId: 'h1', repository: repo, navigator: nav));

      expect(find.byKey(const Key('person-T-001')), findsOneWidget);
      expect(find.byKey(const Key('person-V-001')), findsOneWidget);
      expect(find.byKey(const Key('parent-chip-محمد أحمد')), findsNWidgets(2));
      _expectNoRawIds(_uids);

      await _tap(tester, find.byKey(const Key('person-V-001')));
      expect(find.text('مشرف · V-001'), findsWidgets);
      expect(find.byKey(const Key('halaqa-link-حلقة الفجر')), findsOneWidget);
      expect(find.byKey(const Key('person-T-001')), findsOneWidget); // staff list
      expect(find.byKey(const Key('person-S-001')), findsOneWidget);
    });
  });

  group('future additions and relationship changes', () {
    testWidgets('S-003 added later: linked to P-001 and admitted to H-001 without re-import', (tester) async {
      final repo = FakeAcademy.seeded();
      final nav = PushingNavigator(repo);
      final before = AcademyDataRevision.structure.value;
      await _pumpTall(tester, AdminPersonProfilePage(uid: 's3', repository: repo, navigator: nav));
      expect(find.text('لا يوجد ولي أمر مرتبط.'), findsOneWidget);
      expect(find.text('غير مسجّل في حلقة.'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('action-link-parent')));
      await _typeAndWait(tester, find.byKey(const Key('picker-search')), 'P-001');
      await _tap(tester, find.byKey(const Key('pick-person-P-001')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('link:p1:s3'));
      expect(find.byKey(const Key('person-P-001')), findsOneWidget);
      expect(find.byKey(const Key('person-S-001')), findsOneWidget);
      expect(find.byKey(const Key('person-S-002')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('action-admit')));
      await _tap(tester, find.byKey(const Key('pick-halaqa-حلقة الفجر')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('admit:h1:s3'));
      expect(find.byKey(const Key('halaqa-link-حلقة الفجر')), findsOneWidget);
      expect(find.byKey(const Key('staff-chip-المعلم-أحمد علي')), findsOneWidget);
      expect(find.text('ربط عمر أحمد بولي الأمر محمد أحمد'), findsOneWidget);
      expect(find.text('إضافة عمر أحمد إلى حلقة الفجر'), findsOneWidget);
      expect(AcademyDataRevision.structure.value, before + 2);

      // The parent's side now lists three children.
      await _tap(tester, find.byKey(const Key('person-P-001')));
      expect(find.byKey(const Key('person-S-001')), findsOneWidget);
      expect(find.byKey(const Key('person-S-002')), findsOneWidget);
      expect(find.byKey(const Key('person-S-003')), findsOneWidget);
      _expectNoRawIds(_uids);
    });

    testWidgets('an already-linked parent is excluded from the picker', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminPersonProfilePage(uid: 's1', repository: repo, navigator: PushingNavigator(repo)));
      await _tap(tester, find.byKey(const Key('action-link-parent')));
      expect(find.byKey(const Key('pick-person-P-001')), findsNothing);
      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
    });

    testWidgets('replacing a parent moves the child in one recorded operation', (tester) async {
      final repo = FakeAcademy.seeded()..addPerson('p2', 'علي حسن', DirectoryRole.parent, 'P-002');
      final nav = PushingNavigator(repo);
      await _pumpTall(tester, AdminPersonProfilePage(uid: 's1', repository: repo, navigator: nav));

      await _tap(tester, find.byKey(const Key('parent-menu-محمد أحمد')));
      await _tap(tester, find.text('تغيير ولي الأمر'));
      await _tap(tester, find.byKey(const Key('pick-person-P-002')));
      await _tap(tester, find.byKey(const Key('confirm-change')));

      expect(repo.calls, contains('replace:s1:p1:p2'));
      expect(find.byKey(const Key('person-P-002')), findsOneWidget);
      expect(find.byKey(const Key('person-P-001')), findsNothing);
      expect(find.text('نقل ولاية يوسف محمد من محمد أحمد إلى علي حسن'), findsOneWidget);
      expect(repo.childrenOf['p1'], {'s2'});
      expect(repo.childrenOf['p2'], {'s1'});
    });

    testWidgets('a change made elsewhere refreshes an open profile', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminPersonProfilePage(uid: 'p1', repository: repo, navigator: PushingNavigator(repo)));
      expect(find.byKey(const Key('person-S-003')), findsNothing);

      await repo.linkParent(parentId: 'p1', studentId: 's3');
      AcademyDataRevision.bumpStructure();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('person-S-003')), findsOneWidget);
    });

    testWidgets('a server refusal is shown and nothing changes', (tester) async {
      final repo = FakeAcademy.seeded();
      repo.halaqat['h2'] = FakeHalaqa('h2', 'حلقة العصر', 'H-002', teacher: 't2');
      final before = AcademyDataRevision.structure.value;
      await _pumpTall(tester, AdminPersonProfilePage(uid: 's1', repository: repo, navigator: PushingNavigator(repo)));

      await _tap(tester, find.byKey(const Key('action-admit')));
      await _tap(tester, find.byKey(const Key('pick-halaqa-حلقة العصر')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(find.text('الطالب مسجّل في حلقة؛ استخدم النقل'), findsOneWidget);
      expect(repo.halaqat['h2']!.students, isEmpty);
      expect(AcademyDataRevision.structure.value, before);
    });
  });

  group('halaqa staff, assistants and temporary cover', () {
    testWidgets('teacher and supervisor are changed by search, with confirmation', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminHalaqaProfilePage(halaqaId: 'h1', repository: repo, navigator: PushingNavigator(repo)));

      await _tap(tester, find.byKey(const Key('action-change-teacher')));
      expect(find.byKey(const Key('pick-person-T-001')), findsNothing); // current
      await _tap(tester, find.byKey(const Key('pick-person-T-002')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('reassign:h1:teacher:t2'));
      expect(find.byKey(const Key('person-T-002')), findsOneWidget);
      expect(find.byKey(const Key('person-T-001')), findsNothing);
      expect(find.text('تغيير معلم حلقة الفجر من أحمد علي إلى خالد حسن'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('action-remove-supervisor')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('reassign:h1:supervisor:'));
      expect(find.text('لا يوجد مشرف'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('action-set-supervisor')));
      await _tap(tester, find.byKey(const Key('pick-person-V-002')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('reassign:h1:supervisor:v2'));
      expect(find.byKey(const Key('person-V-002')), findsOneWidget);
    });

    testWidgets('assistant joins beside the primary teacher; cover starts and ends', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminHalaqaProfilePage(halaqaId: 'h1', repository: repo, navigator: PushingNavigator(repo)));

      await _tap(tester, find.byKey(const Key('action-add-assistant')));
      await _tap(tester, find.byKey(const Key('pick-person-A-001')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('assistant:h1:a1:true'));
      expect(repo.halaqat['h1']!.teacher, 't1');
      expect(find.text('معلم · T-001 — المعلم الأساسي'), findsOneWidget);
      expect(find.text('مساعد مدرس · A-001 — مساعد مدرس'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('action-start-cover')));
      await _tap(tester, find.byKey(const Key('cover-assistant-خالد سعيد')));
      await tester.enterText(find.byKey(const Key('change-reason')), 'سفر المعلم');
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('cover:start:h1:a1:سفر المعلم'));
      expect(repo.halaqat['h1']!.teacher, 't1');
      expect(find.byKey(const Key('person-A-001')), findsNWidgets(2)); // staff + cover
      expect(find.byKey(const Key('action-start-cover')), findsNothing);
      final remove = tester.widget<IconButton>(find.byKey(const Key('action-remove-assistant-خالد سعيد')));
      expect(remove.onPressed, isNull);

      await _tap(tester, find.byKey(const Key('action-end-cover')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('cover:end:h1'));
      expect(repo.halaqat['h1']!.cover, isEmpty);
      expect(repo.halaqat['h1']!.teacher, 't1');
      expect(find.byKey(const Key('action-start-cover')), findsOneWidget);
      expect(find.text('فترات التغطية'), findsOneWidget);
      expect(find.text('خالد سعيد (مساعد)'), findsOneWidget);
      expect(find.text('انتهاء التغطية المؤقتة لـحلقة الفجر (خالد سعيد)'), findsOneWidget);
    });

    testWidgets('a teacher cover is picked by search and excludes the primary teacher', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminHalaqaProfilePage(halaqaId: 'h1', repository: repo, navigator: PushingNavigator(repo)));

      await _tap(tester, find.byKey(const Key('action-start-cover')));
      await _tap(tester, find.byKey(const Key('cover-other-teacher')));
      expect(find.byKey(const Key('pick-person-T-001')), findsNothing);
      await _tap(tester, find.byKey(const Key('pick-person-T-002')));
      await _tap(tester, find.byKey(const Key('confirm-change')));
      expect(repo.calls, contains('cover:start:h1:t2:'));

      // The covering teacher's profile shows the halaqa as a cover, not as theirs.
      await _tap(tester, find.byKey(const Key('person-T-002')).last);
      expect(find.textContaining('تغطية مؤقتة — '), findsOneWidget);
      expect(repo.halaqat['h1']!.teacher, 't1');
    });
  });

  group('account and recovery', () {
    testWidgets('a temporary password is issued once; the current one is never shown', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminPersonProfilePage(uid: 's1', repository: repo, navigator: PushingNavigator(repo)));

      expect(find.descendant(of: find.byKey(const Key('account-username')), matching: find.text('us001')),
          findsOneWidget);
      expect(find.text('تم تغييرها'), findsOneWidget);
      expect(find.text('لم يسجّل الدخول بعد'), findsOneWidget);
      expect(find.textContaining(FakeAcademy.temporaryPassword), findsNothing);
      expect(find.textContaining('لا يمكن لأحد — ولا المسؤول — رؤية كلمة المرور الحالية'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('account-reset')));
      expect(repo.calls.where((c) => c.startsWith('reset:')), isEmpty);
      await _tap(tester, find.byKey(const Key('confirm-reset')));
      expect(repo.calls, contains('reset:s1'));
      expect(find.text('كلمة المرور المؤقتة: ${FakeAcademy.temporaryPassword}'), findsOneWidget);
      expect(find.text('رقم الأكاديمية: S-001'), findsOneWidget);
      expect(find.text('لم تُغيَّر بعد — مطلوب تغييرها عند الدخول'), findsOneWidget);
      expect(find.byKey(const Key('account-recovery')), findsOneWidget);

      // Opening the profile again shows the recovery record, not the secret.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(AdminPersonProfilePage(uid: 's1', repository: repo, navigator: PushingNavigator(repo))),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(FakeAcademy.temporaryPassword), findsNothing);
      expect(find.byKey(const Key('account-recovery')), findsOneWidget);
    });

    testWidgets('email accounts are recovered through forgot-password', (tester) async {
      final repo = FakeAcademy.seeded();
      await _pumpTall(tester, AdminPersonProfilePage(uid: 'ad1', repository: repo, navigator: PushingNavigator(repo)));
      expect(find.byKey(const Key('account-reset')), findsNothing);
      expect(find.textContaining('نسيت كلمة المرور'), findsOneWidget);
    });

    test('account data carries no password field', () {
      final a = MemberAccount.fromMap({
        'loginKind': 'username',
        'username': 'us001',
        'mustChangePassword': true,
        'canResetPassword': true,
        'password': 'leaked',
        'temporaryPassword': 'leaked',
      });
      expect(a.props.map((p) => '$p').join('|'), isNot(contains('leaked')));
      expect(a.mustChangePassword, isTrue);
    });
  });

  group('adding people', () {
    testWidgets('assistant: validated, provisioned by the server, credentials once', (tester) async {
      final repo = FakeAcademy.seeded();
      final nav = PushingNavigator(repo);
      final before = AcademyDataRevision.structure.value;
      await _pumpTall(
        tester,
        AdminAddMemberPage(initialRole: DirectoryRole.assistant, repository: repo, navigator: nav),
      );

      final selected = tester.widget<ChoiceChip>(find.byKey(const Key('add-member-role-assistant_teacher')));
      expect(selected.selected, isTrue);
      expect(find.byKey(const Key('add-member-role-student')), findsNothing);
      expect(find.byKey(const Key('add-member-role-admin')), findsNothing);

      await tester.enterText(find.byKey(const Key('add-member-name')), 'x@y.com');
      await _tap(tester, find.byKey(const Key('add-member-submit')));
      expect(find.byKey(const Key('add-member-error')), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('create:')), isEmpty);

      await tester.enterText(find.byKey(const Key('add-member-name')), 'سالم  ناصر');
      await _tap(tester, find.byKey(const Key('add-member-submit')));
      expect(repo.calls, contains('create:assistant_teacher:سالم ناصر'));
      expect(find.byKey(const Key('add-member-done')), findsOneWidget);
      expect(find.text('رقم الأكاديمية: A-002'), findsOneWidget);
      expect(find.text('كلمة المرور المؤقتة: ${FakeAcademy.temporaryPassword}'), findsOneWidget);
      expect(AcademyDataRevision.structure.value, before + 1);

      await _tap(tester, find.byKey(const Key('add-member-open')));
      expect(nav.log, ['person:new1']);
      expect(find.text('مساعد مدرس · A-002'), findsWidgets);
      expect(find.text('غير معيّن مساعداً في أي حلقة.'), findsOneWidget);
    });

    testWidgets('students and admins are redirected to their dedicated flows', (tester) async {
      final repo = FakeAcademy.seeded();
      final nav = PushingNavigator(repo);
      await _pumpTall(tester, AdminAddMemberPage(repository: repo, navigator: nav));
      await _tap(tester, find.byKey(const Key('add-member-student')));
      await _tap(tester, find.byKey(const Key('add-member-admin')));
      expect(nav.log, ['addStudent', 'addAdmin']);
    });

    testWidgets('a parent profile adds another child with that parent preselected', (tester) async {
      final repo = FakeAcademy.seeded();
      final nav = PushingNavigator(repo);
      await _pumpTall(tester, AdminPersonProfilePage(uid: 'p1', repository: repo, navigator: nav));
      await _tap(tester, find.byKey(const Key('action-add-child')));
      expect(nav.log, ['addChild:p1']);
    });
  });
}
