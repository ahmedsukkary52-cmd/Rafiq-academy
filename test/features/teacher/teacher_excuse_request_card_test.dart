import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/excuses/teacher_excuse_list_item_data.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/excuses/teacher_excuse_request_card.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

void main() {
  testWidgets('pending excuse card exposes approve and reject actions', (
    tester,
  ) async {
    var approved = false;
    var rejected = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: TeacherExcuseRequestCard(
              item: const TeacherExcuseListItemData(
                id: 'r1',
                title: 'استئذان — أحمد',
                dateLabel: '٢٨ ذو القعدة ١٤٤٦',
                reason: 'ظرف عائلي',
                status: AbsenceRequestStatus.pending,
                studentId: 's1',
                halaqaId: 'h1',
              ),
              onApprove: () => approved = true,
              onReject: () => rejected = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('قبول'), findsOneWidget);
    expect(find.text('رفض'), findsOneWidget);
    expect(find.text('معلق'), findsOneWidget);

    await tester.tap(find.text('قبول'));
    await tester.pump();
    expect(approved, isTrue);

    await tester.tap(find.text('رفض'));
    await tester.pump();
    expect(rejected, isTrue);
  });

  testWidgets('decided excuse card hides review actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: TeacherExcuseRequestCard(
              item: TeacherExcuseListItemData(
                id: 'r2',
                title: 'استئذان — سارة',
                dateLabel: '٢٠ ذو القعدة ١٤٤٦',
                reason: 'تم القرار',
                status: AbsenceRequestStatus.approved,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('قبول'), findsNothing);
    expect(find.text('رفض'), findsNothing);
    expect(find.text('مقبول'), findsOneWidget);
  });
}
