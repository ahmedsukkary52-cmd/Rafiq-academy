import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/network/network_info.dart';
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_repository_impl.dart';
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart';
import 'package:rafiq_academy/shared/data/models/achievement_model.dart';
import 'package:rafiq_academy/shared/domain/achievement_entity.dart';
import 'package:rafiq_academy/shared/domain/student_achievements_reader.dart';

String _flat(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), '');

const _hubPage =
    'lib/features/supervisor/presentation/pages/supervisor_awards_hub_page.dart';

class _Network implements NetworkInfo {
  _Network(this.connected);
  final bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class _Datasource extends Fake implements StudentRemoteDatasource {
  _Datasource({this.achievements = const [], this.error});

  final List<AchievementModel> achievements;
  final Object? error;
  final calls = <String>[];

  @override
  Future<List<AchievementModel>> getAchievements(String studentId) async {
    calls.add(studentId);
    if (error != null) throw error!;
    return achievements;
  }
}

AchievementModel _achievement(String id, DateTime date) => AchievementModel(
  id: id,
  studentId: 's1',
  type: AchievementType.star,
  title: 'نجمة',
  issuedBy: 'sup1',
  date: date,
);

void main() {
  group('StudentAchievementsReader served by StudentRepositoryImpl', () {
    test('returns the data source achievements unchanged, in order', () async {
      final achievements = [
        _achievement('a2', DateTime(2026, 10, 2)),
        _achievement('a1', DateTime(2026, 10, 1)),
      ];
      final ds = _Datasource(achievements: achievements);
      final StudentAchievementsReader reader = StudentRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: _Network(true),
      );

      final result = await reader.getAchievements('s1');

      expect(result.getOrElse((_) => const []), achievements);
      expect(ds.calls, ['s1']);
    });

    test('offline fails with NetworkFailure without a read', () async {
      final ds = _Datasource();
      final StudentAchievementsReader reader = StudentRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: _Network(false),
      );

      final result = await reader.getAchievements('s1');

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(ds.calls, isEmpty);
    });

    test(
      'a data source error maps to ServerFailure with its message',
      () async {
        final StudentAchievementsReader reader = StudentRepositoryImpl(
          remoteDatasource: _Datasource(
            error: const ServerException('permission-denied'),
          ),
          networkInfo: _Network(true),
        );

        final result = await reader.getAchievements('s1');

        expect(
          result,
          const Left<Failure, List<AchievementEntity>>(
            ServerFailure('permission-denied'),
          ),
        );
      },
    );

    test('StudentRepository implements the shared reader', () {
      StudentAchievementsReader achievements(StudentRepository r) => r;
      expect(achievements, isNotNull);
      expect(
        _flat(
          'lib/features/student/domain/repositories/student_repository.dart',
        ),
        contains(
          '@overrideFuture<Either<Failure,List<AchievementEntity>>>getAchievements(StringstudentId,);',
        ),
      );
    });
  });

  group('StudentAchievementsReader DI wiring (manual config edit)', () {
    final module = _flat('lib/core/di/di_module.dart');
    final config = _flat('lib/core/di/injection_container.config.dart');

    test('module binds the reader to the StudentRepository registration', () {
      expect(
        module,
        contains(
          '@lazySingletonStudentAchievementsReaderstudentAchievementsReader(StudentRepositoryrepository,)=>repository;',
        ),
      );
    });

    test('config registers the reader under _i1207', () {
      expect(
        config,
        contains(
          "import'package:rafiq_academy/shared/domain/student_achievements_reader.dart'as_i1207;",
        ),
      );
      expect(
        config,
        contains(
          'gh.lazySingleton<_i1207.StudentAchievementsReader>(()=>diModule.studentAchievementsReader(gh<_i724.StudentRepository>()),);',
        ),
      );
    });

    test('StudentRepository stays a single registration', () {
      expect(
        RegExp(
          r'gh\.lazySingleton<_i724\.StudentRepository>',
        ).allMatches(config),
        hasLength(1),
      );
    });

    test('the student use case keeps its own registration', () {
      expect(
        config,
        contains(
          'gh.lazySingleton<_i224.GetAchievementsUseCase>(()=>_i224.GetAchievementsUseCase(gh<_i724.StudentRepository>()),);',
        ),
      );
      expect(
        config,
        contains('getAchievements:gh<_i224.GetAchievementsUseCase>(),'),
      );
    });
  });

  group('supervisor awards hub reads through the shared reader', () {
    test('imports no student module and uses StudentAchievementsReader', () {
      final source = File(_hubPage).readAsStringSync();
      expect(source, isNot(contains('/student/')));
      expect(source, isNot(contains('GetAchievementsUseCase')));
      expect(
        _flat(_hubPage),
        contains(
          'awaitsl<StudentAchievementsReader>().getAchievements(row.studentId,);',
        ),
      );
    });

    test('the shared reader contract imports no role module', () {
      final source = File(
        'lib/shared/domain/student_achievements_reader.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('features/')));
      expect(source, isNot(contains('core/di')));
    });
  });

  group('parents stay on the achievements callable', () {
    test('no parent file references StudentAchievementsReader', () {
      final hits = Directory('lib/features/parent')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) => f.readAsStringSync().contains('StudentAchievementsReader'),
          )
          .map((f) => f.path)
          .toList();
      expect(hits, isEmpty);
    });

    test('the parent data source still calls getParentAchievements', () {
      expect(
        File(
          'lib/features/parent/data/data_source/parent_remote_datasource_impl.dart',
        ).readAsStringSync(),
        contains(".httpsCallable('getParentAchievements')"),
      );
    });
  });
}
