import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_bloc.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_event.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_state.dart';
import 'package:rafiq_academy/features/mushaf/presentation/mushaf_mode.dart';
import 'package:rafiq_academy/features/mushaf/presentation/pages/mushaf_reader_host.dart';
import 'package:rafiq_academy/features/student/presentation/pages/student_mushaf_page.dart';

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MushafBlocStub extends Cubit<MushafState> implements MushafBloc {
  _MushafBlocStub() : super(const MushafState());

  final events = <MushafEvent>[];

  @override
  void add(MushafEvent event) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _student = UserEntity(
  uid: 's1',
  name: 'أحمد',
  role: AppRoles.student,
  isActive: true,
  createdAt: DateTime(2026),
);

late _MushafBlocStub _mushaf;
late List<MushafMode> _readerModes;

Widget _reader(MushafMode mode) {
  _readerModes.add(mode);
  return Text('reader ${mode.name}');
}

Future<void> _pump(
  WidgetTester tester,
  MushafReaderHost host, {
  AuthState? auth,
}) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: _AuthBlocStub(auth ?? AuthAuthenticated(_student)),
        ),
        BlocProvider<MushafBloc>.value(value: _mushaf),
      ],
      child: MaterialApp(home: host),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    _mushaf = _MushafBlocStub();
    _readerModes = [];
  });

  tearDown(() async {
    await _mushaf.close();
  });

  testWidgets('shows the supplied reader with the default reading mode', (
    tester,
  ) async {
    await _pump(tester, const MushafReaderHost(reader: _reader));
    expect(find.text('reader reading'), findsOneWidget);
    expect(_readerModes.toSet(), {MushafMode.reading});
    expect(_mushaf.events, [const InitializeMushafEvent(studentId: 's1')]);
  });

  testWidgets('passes the deep-link surah and recitation mode through', (
    tester,
  ) async {
    await _pump(
      tester,
      const MushafReaderHost(
        reader: _reader,
        preferredSurah: 18,
        forceSurahJump: true,
        initialMode: MushafMode.recitation,
      ),
    );
    expect(find.text('reader recitation'), findsOneWidget);
    expect(_mushaf.events, [
      const InitializeMushafEvent(
        studentId: 's1',
        preferredSurah: 18,
        forceSurahJump: true,
      ),
    ]);
  });

  testWidgets('signed-out users see the reader without initialization', (
    tester,
  ) async {
    await _pump(
      tester,
      const MushafReaderHost(reader: _reader),
      auth: const AuthUnauthenticated(),
    );
    expect(find.text('reader reading'), findsOneWidget);
    expect(_mushaf.events, isEmpty);
  });

  test('the student builder creates StudentMushafPage with the mode', () {
    for (final mode in MushafMode.values) {
      final page = buildStudentMushafReader(mode);
      expect(page, isA<StudentMushafPage>());
      expect((page as StudentMushafPage).initialMode, mode);
      expect(page.preferredSurah, isNull);
    }
  });
}
