import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_event.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_state.dart';
import 'package:rafiq_academy/features/supervisor/presentation/pages/supervisor_register_page.dart';

class _FakeSupervisorBloc extends Fake implements SupervisorBloc {
  final _states = StreamController<SupervisorState>.broadcast();

  @override
  SupervisorState state = SupervisorState.initial();

  @override
  Stream<SupervisorState> get stream => _states.stream;

  @override
  bool get isClosed => _states.isClosed;

  @override
  void add(SupervisorEvent event) {}

  void emitState(SupervisorState next) {
    state = next;
    _states.add(next);
  }

  @override
  Future<void> close() => _states.close();
}

void main() {
  testWidgets('partial enrollment keeps the form open for retry', (
    tester,
  ) async {
    final bloc = _FakeSupervisorBloc();
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SupervisorBloc>.value(
          value: bloc,
          child: const SupervisorRegisterPage(),
        ),
      ),
    );
    await tester.pump();

    bloc.emitState(
      SupervisorState(
        admitStudentStatus: SubmissionStatus.success,
        admitStudentRosterRefreshFailed: true,
        halaqatStatus: SectionStatus.error,
        halaqatError: 'تعذر تحديث القائمة',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SupervisorRegisterPage), findsOneWidget);
    expect(find.textContaining('تعذر تحديث القائمة'), findsOneWidget);
  });
}
