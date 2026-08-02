import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/teacher_home_figma_cards.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

/// Captures stats + empty/filled session cards for Figma visual comparison.
/// Output: docs/figma_teacher_refs/captures/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory('docs/figma_teacher_refs/captures');

  setUpAll(() {
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture-root')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${outDir.path}/$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  }

  Widget frame(Widget child) {
    return MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: RepaintBoundary(
              key: const ValueKey('capture-root'),
              child: ColoredBox(
                color: AppColors.background,
                child: Padding(padding: const EdgeInsets.all(20), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('capture empty session + stats (current Home body)', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TeacherHomeStatsGrid(
              studentsCount: 42,
              sessionsToday: 3,
              pendingTasks: 5,
              newMessages: 8,
            ),
            const SizedBox(height: 16),
            TeacherHomeSessionCard.empty(),
          ],
        ),
      ),
    );
    await capture(tester, 'home_stats_empty_session');
  });

  testWidgets('capture filled session + stats (Figma success state)', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TeacherHomeStatsGrid(
              studentsCount: 42,
              sessionsToday: 3,
              pendingTasks: 5,
              newMessages: 8,
            ),
            const SizedBox(height: 16),
            TeacherHomeSessionCard.filled(
              halaqaName: 'حلقة المتقدمين — جزء تبارك',
              startAt: DateTime(2024, 6, 3, 19, 0),
              studentCount: 14,
              onStart: () {},
            ),
          ],
        ),
      ),
    );
    await capture(tester, 'home_stats_filled_session');
  });
}
