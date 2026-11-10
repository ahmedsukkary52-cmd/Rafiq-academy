import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/features/student/domain/entities/student_profile_entity.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_bloc.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_state.dart';
import 'package:rafiq_academy/features/student/presentation/student_bloc_current_profile.dart';
import 'package:rafiq_academy/shared/domain/current_student_profile.dart';

class _StudentBlocStub extends Cubit<StudentState> implements StudentBloc {
  _StudentBlocStub(super.initialState);

  void push(StudentState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StudentProfileEntity _profile({String name = 'أحمد', String? halaqaId}) =>
    StudentProfileEntity(
      uid: 's1',
      name: name,
      currentPlanName: '',
      overallProgressPercent: 0,
      totalStars: 0,
      badges: const [],
      halaqaId: halaqaId,
    );

late _StudentBlocStub _bloc;

void main() {
  setUp(() async {
    await sl.reset();
    _bloc = _StudentBlocStub(const StudentState());
    sl.registerSingleton<StudentBloc>(_bloc);
  });

  tearDown(() async {
    await _bloc.close();
    await sl.reset();
  });

  test('implements the shared contract', () {
    expect(const StudentBlocCurrentProfile(), isA<CurrentStudentProfile>());
  });

  test('fields are null before the profile loads', () {
    const source = StudentBlocCurrentProfile();
    expect(source.name, isNull);
    expect(source.halaqaId, isNull);
  });

  test('returns the loaded profile values untrimmed', () {
    _bloc.push(StudentState(profile: _profile(halaqaId: ' h1 ')));
    const source = StudentBlocCurrentProfile();
    expect(source.name, 'أحمد');
    expect(source.halaqaId, ' h1 ');
  });

  test('a profile without a halaqa returns a null halaqa id', () {
    _bloc.push(StudentState(profile: _profile()));
    expect(const StudentBlocCurrentProfile().halaqaId, isNull);
  });

  test('every read sees the latest emitted profile', () async {
    const source = StudentBlocCurrentProfile();
    expect(source.halaqaId, isNull);

    _bloc.push(StudentState(profile: _profile(halaqaId: 'h1')));
    expect(source.halaqaId, 'h1');

    _bloc.push(
      StudentState(
        profile: _profile(name: 'محمد', halaqaId: 'h2'),
      ),
    );
    expect(source.name, 'محمد');
    expect(source.halaqaId, 'h2');
  });
}
