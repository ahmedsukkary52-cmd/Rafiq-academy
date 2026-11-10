import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/student/domain/entities/student_profile_entity.dart';
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart';
import 'package:rafiq_academy/features/student/domain/usecases/get_student_halaqa_usecase.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_bloc.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_state.dart';
import 'package:rafiq_academy/features/student/presentation/student_chat_teacher_resolver.dart';
import 'package:rafiq_academy/shared/domain/assignment_entity.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';

class _StudentBlocStub extends Cubit<StudentState> implements StudentBloc {
  _StudentBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StudentRepository extends Fake implements StudentRepository {
  Either<Failure, HalaqaEntity> halaqa = const Left(ServerFailure('x'));
  final requested = <String>[];

  @override
  Future<Either<Failure, HalaqaEntity>> getStudentHalaqa(
    String halaqaId,
  ) async {
    requested.add(halaqaId);
    return halaqa;
  }
}

StudentProfileEntity _profile({String? halaqaId}) => StudentProfileEntity(
  uid: 's1',
  name: 'أحمد',
  currentPlanName: '',
  overallProgressPercent: 0,
  totalStars: 0,
  badges: const [],
  halaqaId: halaqaId,
);

HalaqaEntity _halaqa(String teacherId) => HalaqaEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: teacherId,
  supervisorId: 'sup1',
  studentIds: const ['s1'],
  schedule: const [],
  status: 'active',
);

AssignmentEntity _assignment(String assignedBy) => AssignmentEntity(
  id: 'a1',
  studentId: 's1',
  assignedBy: assignedBy,
  newMemorizationRange: 'الملك 1-5',
  reviewRange: '',
  dueDate: DateTime(2026, 9, 10),
);

void main() {
  late _StudentBlocStub bloc;
  late _StudentRepository repo;
  const resolver = StudentBlocChatTeacherResolver();

  setUp(() async {
    await sl.reset();
    bloc = _StudentBlocStub(const StudentState());
    repo = _StudentRepository();
    sl.registerSingleton<StudentBloc>(bloc);
    sl.registerLazySingleton(() => GetStudentHalaqaUseCase(repo));
  });

  tearDown(() async {
    await bloc.close();
    await sl.reset();
  });

  test('uses the loaded halaqa teacher without fetching', () async {
    bloc.emit(
      StudentState(
        profile: _profile(halaqaId: 'h1'),
        halaqa: _halaqa('t1'),
      ),
    );
    final result = await resolver.resolveTeacher();
    expect(result.teacherUid, 't1');
    expect(result.hasHalaqa, isTrue);
    expect(repo.requested, isEmpty);
  });

  test(
    'fetches the profile halaqa when the loaded one has no teacher',
    () async {
      repo.halaqa = Right(_halaqa('t2'));
      bloc.emit(
        StudentState(
          profile: _profile(halaqaId: 'h1'),
          halaqa: _halaqa(''),
        ),
      );
      final result = await resolver.resolveTeacher();
      expect(repo.requested, ['h1']);
      expect(result.teacherUid, 't2');
    },
  );

  test('falls back to the latest assignment when the fetch fails', () async {
    bloc.emit(
      StudentState(
        profile: _profile(halaqaId: 'h1'),
        latestAssignment: _assignment('t3'),
      ),
    );
    final result = await resolver.resolveTeacher();
    expect(repo.requested, ['h1']);
    expect(result.teacherUid, 't3');
    expect(result.hasHalaqa, isTrue);
  });

  test('no halaqa and no assignment resolves nothing', () async {
    bloc.emit(StudentState(profile: _profile()));
    final result = await resolver.resolveTeacher();
    expect(repo.requested, isEmpty);
    expect(result.teacherUid, isNull);
    expect(result.hasHalaqa, isFalse);
  });

  test('a halaqa without a resolvable teacher keeps hasHalaqa', () async {
    bloc.emit(StudentState(profile: _profile(halaqaId: 'h1')));
    final result = await resolver.resolveTeacher();
    expect(result.teacherUid, isNull);
    expect(result.hasHalaqa, isTrue);
  });

  test('reads the latest student state on every call', () async {
    final first = await resolver.resolveTeacher();
    expect(first.teacherUid, isNull);

    bloc.emit(StudentState(latestAssignment: _assignment('t4')));
    final second = await resolver.resolveTeacher();
    expect(second.teacherUid, 't4');
    expect(second.hasHalaqa, isFalse);
  });
}
