import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/student/domain/entities/student_profile_entity.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_bloc.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_event.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_state.dart';
import 'package:rafiq_academy/features/student/presentation/pages/student_streak_page.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

const _profile = StudentProfileEntity(
  uid: 's1',
  name: 'أحمد',
  currentPlanName: '',
  overallProgressPercent: 0,
  totalStars: 0,
  badges: [],
  halaqaId: 'h1',
  streakDays: 7,
);

class _FakeStudentBloc extends Fake implements StudentBloc {
  _FakeStudentBloc(this._state);

  final StudentState _state;
  final _controller = StreamController<StudentState>.broadcast();
  final events = <StudentEvent>[];

  @override
  StudentState get state => _state;

  @override
  Stream<StudentState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(StudentEvent event) => events.add(event);

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  testWidgets(
    'a direct link to the streak page says it is not activated and shows '
    'no unwired streak value, with a back action',
    (tester) async {
      final bloc = _FakeStudentBloc(
        const StudentState(
          profileStatus: SectionStatus.loaded,
          profile: _profile,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLocaleConfig.locale,
          supportedLocales: AppLocaleConfig.supportedLocales,
          localizationsDelegates: AppLocaleConfig.localizationsDelegates,
          theme: AppTheme.theme,
          home: BlocProvider<StudentBloc>.value(
            value: bloc,
            child: const StudentStreakPage(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('student-streak-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('7'), findsNothing);
      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(bloc.events, isEmpty);
    },
  );
}
