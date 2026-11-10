import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/awards/presentation/widgets/awards_loading_skeletons.dart';
import 'package:rafiq_academy/features/notifications/presentation/widgets/notifications_list_skeleton.dart';
import 'package:rafiq_academy/features/post/presentation/widgets/posts_list_skeleton.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/teacher_loading_skeletons.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/app_skeleton.dart';
import 'package:rafiq_academy/shared/widgets/student_page_skeletons.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('AppSkeletonCard', () {
    testWidgets('draws the bordered surface card with default padding', (
      tester,
    ) async {
      await _pump(tester, const AppSkeletonCard(child: SizedBox(height: 10)));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppSkeletonCard),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surface);
      expect(decoration.borderRadius, BorderRadius.circular(AppSizes.radiusL));
      expect(decoration.border, Border.all(color: AppColors.border));
      expect(container.padding, const EdgeInsets.all(AppSizes.paddingM));
      expect(tester.getSize(find.byType(AppSkeletonCard)).width, 400);
    });

    testWidgets('teacherSkeletonCard delegates with the given padding', (
      tester,
    ) async {
      const padding = EdgeInsets.fromLTRB(1, 2, 3, 4);
      await _pump(
        tester,
        teacherSkeletonCard(
          bone: Colors.grey,
          padding: padding,
          child: const SizedBox(height: 10),
        ),
      );
      final card = tester.widget<AppSkeletonCard>(find.byType(AppSkeletonCard));
      expect(card.padding, padding);
    });
  });

  group('moved loading skeletons render on the shared pulse', () {
    final cases = <String, (Widget, Type)>{
      'TeacherAwardsDashboardSkeleton': (
        const TeacherAwardsDashboardSkeleton(),
        TeacherAwardsDashboardSkeleton,
      ),
      'TeacherAwardsHistorySkeleton': (
        const TeacherAwardsHistorySkeleton(),
        TeacherAwardsHistorySkeleton,
      ),
      'TeacherPostsListSkeleton': (
        const TeacherPostsListSkeleton(),
        TeacherPostsListSkeleton,
      ),
      'TeacherNotificationsListSkeleton': (
        const TeacherNotificationsListSkeleton(),
        TeacherNotificationsListSkeleton,
      ),
      'StudentListPageSkeleton': (
        const StudentListPageSkeleton(),
        StudentListPageSkeleton,
      ),
      'StudentHomeBodySkeleton': (
        const StudentHomeBodySkeleton(),
        StudentHomeBodySkeleton,
      ),
    };

    cases.forEach((name, value) {
      testWidgets(name, (tester) async {
        await _pump(tester, value.$1);
        expect(tester.takeException(), isNull);
        expect(find.byType(value.$2), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(value.$2),
            matching: find.byType(AppSkeletonPulse),
          ),
          findsOneWidget,
        );
        expect(find.byType(AppSkeletonBox), findsWidgets);
      });
    });
  });

  group('item counts are preserved', () {
    testWidgets('awards dashboard: 3 stat cards and 4 history cards', (
      tester,
    ) async {
      await _pump(tester, const TeacherAwardsDashboardSkeleton());
      expect(find.byType(AppSkeletonCard), findsNWidgets(7));
    });

    testWidgets('awards history: 3 cards', (tester) async {
      await _pump(tester, const TeacherAwardsHistorySkeleton());
      expect(find.byType(AppSkeletonCard), findsNWidgets(3));
    });

    testWidgets('posts list honours itemCount', (tester) async {
      await _pump(tester, const TeacherPostsListSkeleton(itemCount: 2));
      expect(find.byType(AppSkeletonCard), findsNWidgets(2));
    });

    testWidgets('notifications list honours itemCount', (tester) async {
      await _pump(tester, const TeacherNotificationsListSkeleton(itemCount: 3));
      expect(find.byType(CircleAvatar), findsNWidgets(3));
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('student list page honours itemCount', (tester) async {
      await _pump(tester, const StudentListPageSkeleton(itemCount: 2));
      expect(find.byType(AppSkeletonBox), findsNWidgets(6));
    });
  });
}
