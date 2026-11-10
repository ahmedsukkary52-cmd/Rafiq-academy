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
import 'package:rafiq_academy/features/admin/presentation/pages/admin_halaqat_page.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/shared/domain/halaqa_meeting_link.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

import '../../support/fake_halaqa_meeting_link_repository.dart';

class _FakeOpsRepo extends Fake implements AdminOperationsRepository {
  final calls = <String>[];
  int halaqatLoads = 0;

  @override
  Future<Either<Failure, List<AdminDirectoryUser>>> listUsersByRole(
    String role,
  ) async => const Right([]);

  @override
  Future<Either<Failure, List<HalaqaEntity>>> listHalaqat() async {
    halaqatLoads++;
    return Right([_halaqa('h1')]);
  }

  @override
  Future<Either<Failure, MeetingLinkChange>> setHalaqaMeetingLink({
    required String halaqaId,
    String? meetingLink,
    bool clear = false,
  }) async {
    calls.add(clear ? 'clear:$halaqaId' : 'set:$halaqaId:$meetingLink');
    return Right(clear ? MeetingLinkChange.clear : MeetingLinkChange.update);
  }
}

class _FakeAdminRepo extends Fake implements AdminRepository {}

HalaqaEntity _halaqa(String id) => HalaqaEntity(
  id: id,
  name: 'حلقة $id',
  teacherId: 't1',
  supervisorId: '',
  studentIds: const [],
  schedule: const [],
  status: 'active',
);

Future<_FakeOpsRepo> _pump(
  WidgetTester tester,
  FakeHalaqaMeetingLinkRepository links,
) async {
  await sl.reset();
  final ops = _FakeOpsRepo();
  final admin = _FakeAdminRepo();
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
  registerFakeMeetingLinks(links);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.theme, home: const AdminHalaqatPage()),
  );
  await tester.pumpAndSettle();
  return ops;
}

void main() {
  tearDown(() => sl.reset());

  group('B14 admin halaqat page reads halaqaMeetingLinks', () {
    testWidgets('a valid canonical link is shown and prefilled for edit', (
      tester,
    ) async {
      const link = 'https://meet.example.com/a';
      final links = FakeHalaqaMeetingLinkRepository({'h1': link});
      final ops = await _pump(tester, links);
      expect(links.reads, ['h1']);
      expect(find.text('رابط الاجتماع:'), findsOneWidget);
      expect(find.text(link), findsOneWidget);

      await tester.tap(find.text('تعديل الرابط'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('meetingLinkField')),
      );
      expect(field.controller!.text, link);

      links.links['h1'] = 'https://meet.example.com/b';
      await tester.enterText(
        find.byKey(const Key('meetingLinkField')),
        'https://meet.example.com/b',
      );
      await tester.tap(find.byKey(const Key('meetingLinkSave')));
      await tester.pumpAndSettle();
      expect(ops.calls, ['set:h1:https://meet.example.com/b']);
      expect(ops.halaqatLoads, 2);
      expect(links.reads.length, greaterThanOrEqualTo(2));
      expect(find.text('https://meet.example.com/b'), findsOneWidget);
    });

    testWidgets('a missing document offers add with an empty field', (
      tester,
    ) async {
      final links = FakeHalaqaMeetingLinkRepository();
      await _pump(tester, links);
      expect(find.text('رابط الاجتماع: لم يُضبط بعد'), findsOneWidget);
      await tester.tap(find.text('إضافة رابط'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('meetingLinkField')),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('an invalid stored link is never shown or prefilled', (
      tester,
    ) async {
      const bad = 'http://meet.example.com/bad';
      await _pump(tester, FakeHalaqaMeetingLinkRepository({'h1': bad}));
      expect(find.text('رابط الاجتماع المحفوظ غير صالح — حدّثه'), findsOneWidget);
      expect(find.text(bad), findsNothing);
      await tester.tap(find.text('تعديل الرابط'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('meetingLinkField')),
      );
      expect(field.controller!.text, isEmpty);
      expect(find.text(bad), findsNothing);
    });

    testWidgets('an invalid stored link can be cleared without showing it', (
      tester,
    ) async {
      final links = FakeHalaqaMeetingLinkRepository({'h1': ''});
      final ops = await _pump(tester, links);
      await tester.tap(find.text('تعديل الرابط'));
      await tester.pumpAndSettle();
      links.links.remove('h1');
      await tester.tap(find.byKey(const Key('meetingLinkClear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meetingLinkClear')));
      await tester.pumpAndSettle();
      expect(ops.calls, ['clear:h1']);
      expect(find.text('رابط الاجتماع: لم يُضبط بعد'), findsOneWidget);
    });

    testWidgets('a missing document offers no clear action', (tester) async {
      await _pump(tester, FakeHalaqaMeetingLinkRepository());
      await tester.tap(find.text('إضافة رابط'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meetingLinkClear')), findsNothing);
    });

    testWidgets('permission denied is distinct and disables editing', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeHalaqaMeetingLinkRepository()
          ..failure = const MeetingLinkAccessDeniedFailure(),
      );
      expect(find.text('لا تملك صلاحية عرض رابط الاجتماع'), findsOneWidget);
      expect(find.text('تعذر تحميل رابط الاجتماع'), findsNothing);
      final edit = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'تعديل الرابط'),
      );
      expect(edit.onPressed, isNull);
    });

    testWidgets('a load failure offers retry, which re-reads', (tester) async {
      final links = FakeHalaqaMeetingLinkRepository()
        ..failure = const NetworkFailure();
      await _pump(tester, links);
      expect(find.text('تعذر تحميل رابط الاجتماع'), findsOneWidget);
      expect(find.text('تعديل الرابط'), findsNothing);

      links
        ..failure = null
        ..links['h1'] = 'https://meet.example.com/a';
      await tester.tap(find.byKey(const Key('adminMeetingLinkRetry')));
      await tester.pumpAndSettle();
      expect(links.reads, ['h1', 'h1']);
      expect(find.text('https://meet.example.com/a'), findsOneWidget);
    });
  });
}
