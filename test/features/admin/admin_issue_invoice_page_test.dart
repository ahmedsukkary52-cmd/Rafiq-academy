import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_billing_usecases.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_issue_invoice_page.dart';
import 'package:rafiq_academy/features/directory/data/academy_directory_repository.dart';
import 'package:rafiq_academy/features/directory/domain/directory_models.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

class _FakeDirectory extends Fake implements AcademyDirectoryRepository {
  @override
  Future<DirectoryPage<DirectoryPerson>> browsePeople({
    required DirectoryRole role,
    DirectoryStatusFilter status = DirectoryStatusFilter.all,
    DirectoryRelationFilter relation = DirectoryRelationFilter.none,
    String? halaqaId,
    Object? cursor,
  }) async {
    return const DirectoryPage(
      items: [
        DirectoryPerson(
          uid: 's1',
          name: 'أحمد الطالب',
          role: 'student',
          academyRef: 'S-001',
          isActive: true,
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<List<DirectoryPerson>> searchPeople({
    DirectoryRole? role,
    required String query,
  }) async => const [];
}

class _FakeGenerate extends Fake implements GenerateInvoiceUseCase {
  GenerateInvoiceParams? last;
  Either<Failure, String> result = const Right('pay_1');

  @override
  Future<Either<Failure, String>> call(GenerateInvoiceParams params) async {
    last = params;
    return result;
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: child,
    ),
  );
}

void main() {
  testWidgets('requires student before submit', (tester) async {
    final generate = _FakeGenerate();
    await tester.pumpWidget(
      _wrap(
        AdminIssueInvoicePage(
          directoryRepository: _FakeDirectory(),
          generateInvoice: generate,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('issue-invoice-submit')));
    await tester.pump();

    expect(find.byKey(const Key('issue-invoice-error')), findsOneWidget);
    expect(find.textContaining('اختر طالباً'), findsOneWidget);
    expect(generate.last, isNull);
  });

  testWidgets('issues invoice for picked student and period', (tester) async {
    final generate = _FakeGenerate();
    await tester.pumpWidget(
      _wrap(
        AdminIssueInvoicePage(
          directoryRepository: _FakeDirectory(),
          generateInvoice: generate,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('issue-invoice-pick-student')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أحمد الطالب'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('issue-invoice-period')),
      '2026-11',
    );
    await tester.tap(find.byKey(const Key('issue-invoice-submit')));
    await tester.pumpAndSettle();

    expect(generate.last?.studentId, 's1');
    expect(generate.last?.periodKey, '2026-11');
    expect(find.byKey(const Key('issue-invoice-payment-id')), findsOneWidget);
    expect(find.textContaining('pay_1'), findsOneWidget);
  });

  testWidgets('surfaces callable failure message', (tester) async {
    final generate = _FakeGenerate()
      ..result = const Left(ServerFailure('لا يوجد ولي أمر مرتبط بهذا الطالب'));
    await tester.pumpWidget(
      _wrap(
        AdminIssueInvoicePage(
          directoryRepository: _FakeDirectory(),
          generateInvoice: generate,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('issue-invoice-pick-student')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أحمد الطالب'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('issue-invoice-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('لا يوجد ولي أمر'), findsOneWidget);
    expect(find.byKey(const Key('issue-invoice-payment-id')), findsNothing);
  });
}
