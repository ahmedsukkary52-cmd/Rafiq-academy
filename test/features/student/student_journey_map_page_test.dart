import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/student/domain/entities/student_profile_entity.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_bloc.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_event.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_state.dart';
import 'package:rafiq_academy/features/student/presentation/pages/student_journey_map_page.dart';
import 'package:rafiq_academy/features/student/presentation/widgets/student_loading_skeletons.dart';
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
  _FakeStudentBloc(this._state);

  final StudentState _state;
  final _controller = StreamController<StudentState>.broadcast();

  @override
  StudentState get state => _state;

  @override
  Stream<StudentState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(StudentEvent event) {}

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

Widget _wrap(StudentState state) {
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider<StudentBloc>.value(
        value: _FakeStudentBloc(state),
        child: const StudentJourneyMapPage(),
      ),
    ),
  );
}

void main() {
  testWidgets('journey map renders real profile data with a back action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const StudentState(
          profileStatus: SectionStatus.loaded,
          profile: _profile,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('جزء عم'), findsWidgets);
    expect(find.textContaining('3 يوم متواصل'), findsOneWidget);
    expect(find.textContaining('2 سورة'), findsOneWidget);
    expect(find.byTooltip('رجوع'), findsOneWidget);
  });

  testWidgets('journey map loading keeps a back action', (tester) async {
    await tester.pumpWidget(
      _wrap(const StudentState(profileStatus: SectionStatus.loading)),
    );
    await tester.pump();

    expect(find.byType(StudentHomeBodySkeleton), findsOneWidget);
    expect(find.byTooltip('رجوع'), findsOneWidget);
  });
}
