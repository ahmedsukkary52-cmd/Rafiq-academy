import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_event.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_state.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_students_tab.dart';

class _FakeAdminBloc extends Fake implements AdminBloc {
  final _states = StreamController<AdminState>.broadcast();

  @override
  AdminState state = const AdminState();

  @override
  Stream<AdminState> get stream => _states.stream;

  @override
  bool get isClosed => _states.isClosed;

  @override
  void add(AdminEvent event) {}

  void emit(AdminState next) {
    state = next;
    _states.add(next);
  }

  @override
  Future<void> close() => _states.close();
}

Future<void> _pump(WidgetTester tester, _FakeAdminBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AdminBloc>.value(
        value: bloc,
        child: const AdminStudentsTab(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows exactly one full-success notification', (tester) async {
    final bloc = _FakeAdminBloc();
    addTearDown(bloc.close);
    await _pump(tester, bloc);

    bloc.emit(
      const AdminState(
        toggleAccountStatus: SubmissionStatus.success,
        rosterStatus: SectionStatus.loaded,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('تم تفعيل/تعطيل الطالب بنجاح'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('shows exactly one callable-failure notification', (
    tester,
  ) async {
    final bloc = _FakeAdminBloc();
    addTearDown(bloc.close);
    await _pump(tester, bloc);

    bloc.emit(
      const AdminState(
        toggleAccountStatus: SubmissionStatus.error,
        toggleAccountError: 'Network error',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('فشل تغيير الحالة'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('shows exactly one partial-success notification', (tester) async {
    final bloc = _FakeAdminBloc();
    addTearDown(bloc.close);
    await _pump(tester, bloc);

    bloc.emit(
      const AdminState(
        toggleAccountStatus: SubmissionStatus.success,
        rosterStatus: SectionStatus.error,
        rosterError: 'Roster load failed',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('فشل تحديث القائمة'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
