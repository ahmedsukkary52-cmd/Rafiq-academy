import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/core/router/app_routes.dart';
import 'package:rafiq_academy/features/student/domain/entities/student_profile_entity.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_bloc.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_event.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_state.dart';
import 'package:rafiq_academy/features/student/presentation/pages/student_home_page.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

const _profile = StudentProfileEntity(
  uid: 's1',
  name: 'أحمد',
  currentPlanName: 'جزء عم',
  overallProgressPercent: 40,
  totalStars: 10,
  badges: [],
  halaqaId: 'h1',
  streakDays: 3,
  completedSurahs: 2,
);

class _FakeStudentBloc extends Fake implements StudentBloc {
  final _controller = StreamController<StudentState>.broadcast();

  @override
  StudentState get state => const StudentState(
    profileStatus: SectionStatus.loaded,
    profile: _profile,
  );

  @override
  Stream<StudentState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(StudentEvent event) {}

  @override
  Future<void> close() => _controller.close();
}

class _RecordingRouter extends Fake implements GoRouter {
  final pushed = <String>[];

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    pushed.add(location);
    return null;
  }
}

Widget _wrap(_RecordingRouter router) {
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: InheritedGoRouter(
      goRouter: router,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BlocProvider<StudentBloc>.value(
            value: _FakeStudentBloc(),
            child: const StudentProfileTab(),
          ),
        ),
      ),
    ),
  );
}

List<String> _menuLabels(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.title! as Text).data!)
    .where((label) => label != 'تسجيل الخروج')
    .toList();

void main() {
  testWidgets('profile tab no longer shows parent-account or help items', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_RecordingRouter()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('حساب ولي الأمر'), findsNothing);
    expect(find.text('المساعدة والدعم'), findsNothing);
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('only the settings item routes to student settings', (
    tester,
  ) async {
    final router = _RecordingRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final labels = _menuLabels(tester);
    expect(labels, isNotEmpty);

    final destinations = <String, String>{};
    for (final label in labels) {
      final item = find.widgetWithText(ListTile, label);
      await tester.ensureVisible(item);
      await tester.pump();
      final before = router.pushed.length;
      await tester.tap(item);
      await tester.pump();
      expect(router.pushed.length, before + 1, reason: label);
      destinations[label] = router.pushed.last;
    }
    expect(tester.takeException(), isNull);

    final toSettings = destinations.entries
        .where((e) => e.value == AppRoutes.studentSettings)
        .map((e) => e.key)
        .toList();
    expect(toSettings, ['الإعدادات']);
  });

  testWidgets('menu ink paints above the coloured card, not behind it', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_RecordingRouter()));
    await tester.pump();

    for (final label in _menuLabels(tester)) {
      final item = find.widgetWithText(ListTile, label);
      await tester.ensureVisible(item);
      await tester.pump();

      // The nearest Material above each tile is transparent and sits inside
      // the decorated card, so the tile's ink is painted on top of the card.
      final nearest = find
          .ancestor(of: item, matching: find.byType(Material))
          .first;
      final material = tester.widget<Material>(nearest);
      expect(material.color, Colors.transparent, reason: label);
      expect(material.clipBehavior, Clip.antiAlias, reason: label);
      expect(
        find.ancestor(
          of: nearest,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        ),
        findsWidgets,
        reason: label,
      );
      expect(
        Material.of(tester.element(item)).color,
        Colors.transparent,
        reason: '$label: ink controller is the card-level Material',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
