import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_operations_entities.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_operations_repository.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_billing_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_operations_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/approve_new_student_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/provision_user_usecase.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_operations_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_accounts_page.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';

class _Ops extends Fake implements AdminOperationsRepository {
  @override
  Future<Either<Failure, List<AdminDirectoryUser>>> listUsersByRole(String role) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<HalaqaEntity>>> listHalaqat() async => const Right([]);
}

class _Admin extends Fake implements AdminRepository {
  final provisioned = <String>[];

  @override
  Future<Either<Failure, String>> provisionUser({
    required String email,
    required String password,
    required String name,
    required String role,
    bool isActive = true,
  }) async {
    provisioned.add(role);
    return const Right('new-uid');
  }
}

void main() {
  late _Admin admin;

  setUp(() async {
    await sl.reset();
    admin = _Admin();
    final ops = _Ops();
    sl.registerFactory<AdminOperationsBloc>(
      () => AdminOperationsBloc(
        listUsersByRole: ListUsersByRoleUseCase(ops),
        listHalaqat: ListAdminHalaqatUseCase(ops),
        getParentChildren: GetParentChildrenUseCase(ops),
        provisionUser: ProvisionUserUseCase(admin),
        linkParentChild: LinkParentChildUseCase(ops),
        createHalaqa: CreateHalaqaUseCase(ops),
        addHalaqaSlot: AddHalaqaSlotUseCase(ops),
        setMeetingLink: SetHalaqaMeetingLinkUseCase(ops),
        admitStudent: ApproveNewStudentUseCase(admin),
        transferStudent: TransferStudentUseCase(ops),
        reinstatePaymentAccess: ReinstatePaymentAccessUseCase(admin),
      ),
    );
  });

  tearDown(() async => sl.reset());

  testWidgets('admin access needs an explicit role choice and confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminAccountsPage()));
    await tester.pumpAndSettle();

    expect(find.text('طالب'), findsOneWidget, reason: 'default is not admin');
    expect(find.byKey(const Key('provision-admin-warning')), findsNothing);

    await tester.tap(find.byKey(const Key('provision-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مسؤول إدارة (صلاحيات كاملة)').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('provision-admin-warning')), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'مدير مساعد');
    await tester.enterText(fields.at(1), 'deputy@example.com');
    await tester.enterText(fields.at(2), 'secret12');

    await tester.tap(find.text('إنشاء حساب المسؤول'));
    await tester.pumpAndSettle();
    expect(admin.provisioned, isEmpty, reason: 'blocked until confirmed');

    await tester.tap(find.byKey(const Key('provision-admin-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء حساب المسؤول'));
    await tester.pumpAndSettle();
    expect(admin.provisioned, ['admin']);
  });

  testWidgets('switching away from admin clears the confirmation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminAccountsPage()));
    await tester.pumpAndSettle();

    Future<void> choose(String label) async {
      await tester.tap(find.byKey(const Key('provision-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await choose('مسؤول إدارة (صلاحيات كاملة)');
    await tester.tap(find.byKey(const Key('provision-admin-confirm')));
    await tester.pumpAndSettle();
    await choose('معلم');
    await choose('مسؤول إدارة (صلاحيات كاملة)');
    final box = tester.widget<CheckboxListTile>(
      find.byKey(const Key('provision-admin-confirm')),
    );
    expect(box.value, isFalse);
  });
}
