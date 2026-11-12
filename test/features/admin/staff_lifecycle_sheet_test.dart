import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/admin/data/staff_lifecycle_repository.dart';
import 'package:rafiq_academy/features/admin/presentation/widgets/staff_lifecycle_sheet.dart';

class _FakeStaff extends Fake implements StaffLifecycleRepository {
  _FakeStaff({this.halaqat = const [], this.others = const [], this.failStatus});

  List<StaffHalaqa> halaqat;
  final List<StaffMember> others;
  final String? failStatus;
  final calls = <String>[];

  @override
  Future<List<StaffHalaqa>> assignedHalaqat(String uid, String role) async =>
      halaqat;

  @override
  Future<List<StaffMember>> replacements(String role, {required String excludeUid}) async =>
      others.where((m) => m.uid != excludeUid).toList();

  @override
  Future<void> reassign({
    required String halaqaId,
    required String role,
    required String newStaffId,
  }) async {
    calls.add('reassign:$halaqaId:$role:$newStaffId');
    halaqat = halaqat.where((h) => h.id != halaqaId).toList();
  }

  @override
  Future<void> setStatus({required String uid, required StaffAction action}) async {
    calls.add('status:$uid:${action.wire}');
    if (failStatus != null) throw ServerException(failStatus!);
  }
}

const _t1 = StaffMember(uid: 't1', name: 'أحمد', role: AppRoles.teacher, status: StaffStatus.active);
const _t2 = StaffMember(uid: 't2', name: 'محمود', role: AppRoles.teacher, status: StaffStatus.active);

Future<List<bool>> _open(WidgetTester tester, StaffMember member, _FakeStaff repo) async {
  final results = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showStaffLifecycleSheet(context, member: member, repository: repo),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Finder _action(String wire) => find.byKey(Key('staff-action-$wire'));

bool _enabled(WidgetTester tester, String wire) =>
    tester.widget<OutlinedButton>(_action(wire)).onPressed != null;

void main() {
  testWidgets('deactivating a teacher requires a replacement for every halaqa, then reassigns before deactivating', (
    tester,
  ) async {
    final repo = _FakeStaff(
      halaqat: const [StaffHalaqa(id: 'h1', name: 'حلقة الفجر')],
      others: const [_t2],
    );
    final results = await _open(tester, _t1, repo);

    expect(find.text('اختر بديلاً لكل حلقة قبل التعطيل'), findsOneWidget);
    expect(find.text('حلقة الفجر'), findsOneWidget);
    expect(find.text('التعطيل: '), findsNothing);
    expect(_enabled(tester, 'deactivate'), isFalse);
    expect(_action('archive'), findsNothing, reason: 'archive needs a deactivated account');

    await tester.tap(find.byKey(const Key('replace-h1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('محمود').last);
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'deactivate'), isTrue);

    await tester.tap(_action('deactivate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff-confirm')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['reassign:h1:teacher:t2', 'status:t1:deactivate']);
    expect(results, [true]);
  });

  testWidgets('a server refusal is shown in place and the sheet stays open', (tester) async {
    final repo = _FakeStaff(failStatus: 'أعد إسناد حلقات هذا الحساب أولاً: حلقة العصر');
    final results = await _open(tester, _t1, repo);
    expect(find.text('لا حلقات مسندة حالياً'), findsOneWidget);
    await tester.tap(_action('deactivate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff-error')), findsOneWidget);
    expect(find.textContaining('حلقة العصر'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('no other active teacher: explains why deactivation is blocked', (tester) async {
    final repo = _FakeStaff(halaqat: const [StaffHalaqa(id: 'h1', name: 'حلقة الفجر')]);
    await _open(tester, _t1, repo);
    expect(find.textContaining('لا يوجد معلم نشط آخر'), findsOneWidget);
    expect(_enabled(tester, 'deactivate'), isFalse);
  });

  testWidgets('supervisors may hand a halaqa to "no supervisor"', (tester) async {
    final repo = _FakeStaff(halaqat: const [StaffHalaqa(id: 'h1', name: 'حلقة الفجر')]);
    await _open(
      tester,
      const StaffMember(uid: 's1', name: 'سعاد', role: AppRoles.supervisor, status: StaffStatus.active),
      repo,
    );
    await tester.tap(find.byKey(const Key('replace-h1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بدون مشرف').last);
    await tester.pumpAndSettle();
    await tester.tap(_action('deactivate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['reassign:h1:supervisor:', 'status:s1:deactivate']);
  });

  testWidgets('archived account: reactivate or delete; delete needs explicit acknowledgement', (tester) async {
    final repo = _FakeStaff();
    final results = await _open(
      tester,
      const StaffMember(uid: 't9', name: 'قديم', role: AppRoles.teacher, status: StaffStatus.archived),
      repo,
    );
    expect(find.text('مؤرشف'), findsOneWidget);
    expect(_action('reactivate'), findsOneWidget);
    expect(_action('deactivate'), findsNothing);

    await tester.tap(_action('delete'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('staff-confirm'));
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);
    await tester.tap(find.byKey(const Key('confirm-delete-check')));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repo.calls, ['status:t9:delete']);
    expect(results, [true]);
  });

  test('status derivation and allowed actions mirror the server', () {
    expect(StaffStatus.fromUser({'isActive': false}), StaffStatus.deactivated);
    expect(StaffStatus.fromUser({}), StaffStatus.active);
    expect(StaffStatus.fromUser({'staffStatus': 'archived', 'isActive': false}), StaffStatus.archived);
    expect(StaffAction.availableFor(StaffStatus.deleted), isEmpty);
    expect(StaffAction.availableFor(StaffStatus.deactivated), [StaffAction.reactivate, StaffAction.archive]);
  });
}
