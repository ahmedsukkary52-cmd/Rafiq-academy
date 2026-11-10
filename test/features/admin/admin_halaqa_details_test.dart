import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_directory_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_halaqa_details_page.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';

const _halaqa = AdminHalaqaSummaryEntity(
  id: 'h1',
  name: 'حلقة النور',
  teacherId: 't1',
  supervisorId: '',
  studentCount: 2,
  teacherName: 'أحمد',
);

Widget _host(Widget child) => MaterialApp(
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

void main() {
  testWidgets('shows schedule and roster; tapping a student opens them', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      _host(
        AdminHalaqaDetailsPage(
          halaqa: _halaqa,
          loader: (_) async => const AdminHalaqaDetails(
            schedule: [
              HalaqaScheduleEntity(
                day: 'الأحد',
                startTime: '16:00',
                endTime: '17:00',
              ),
            ],
            students: [(uid: 's1', name: 'خالد'), (uid: 's2', name: 'سعد')],
          ),
          onOpenStudent: (_, id) => opened = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المعلم: أحمد'), findsOneWidget);
    expect(find.text('المشرف: غير معيّن'), findsOneWidget);
    expect(find.text('الأحد 16:00–17:00'), findsOneWidget);
    expect(find.text('خالد'), findsOneWidget);
    expect(find.textContaining('s1'), findsNothing);

    await tester.tap(find.byKey(const Key('halaqa-student-s2')));
    expect(opened, 's2');
  });

  testWidgets('load failure shows the error and retry reloads', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        AdminHalaqaDetailsPage(
          halaqa: _halaqa,
          loader: (_) async {
            calls++;
            if (calls == 1) throw 'تعذر تحميل بيانات الحلقة';
            return const AdminHalaqaDetails(schedule: [], students: []);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل بيانات الحلقة'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byKey(const Key('halaqa-details-no-students')), findsOneWidget);
    expect(find.text('لا توجد مواعيد'), findsOneWidget);
  });
}
