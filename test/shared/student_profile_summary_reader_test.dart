import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/network/network_info.dart';
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource.dart';
import 'package:rafiq_academy/features/student/data/models/student_profile_model.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_profile_summary_reader_impl.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_repository_impl.dart';
import 'package:rafiq_academy/features/student/domain/student_profile_latest_evaluation.dart'
    as student_path;
import 'package:rafiq_academy/shared/domain/student_profile_latest_evaluation.dart';
import 'package:rafiq_academy/shared/domain/student_profile_summary.dart';

String _flat(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), '');

class _Network implements NetworkInfo {
  _Network(this.connected);
  final bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class _Datasource extends Fake implements StudentRemoteDatasource {
  _Datasource({this.profile, this.error});

  final StudentProfileModel? profile;
  final Object? error;
  final calls = <String>[];

  @override
  Future<StudentProfileModel> getStudentProfile(String uid) async {
    calls.add(uid);
    if (error != null) throw error!;
    return profile!;
  }
}

const _profile = StudentProfileModel(
  uid: 's1',
  name: ' سارة ',
  profileImageUrl: 'https://example.invalid/a.png',
  halaqaId: 'h1',
  halaqaName: 'حلقة النور',
  currentPlanName: 'خطة',
  overallProgressPercent: 55.5,
  totalVersesMemorized: 120,
  level: 3,
  totalStars: 7,
  badges: ['b1'],
  coins: 40,
  avatarId: 'owl',
);

StudentProfileSummaryReader _reader(_Datasource ds, {bool online = true}) =>
    StudentProfileSummaryReaderImpl(
      StudentRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: _Network(online),
      ),
    );

void main() {
  group('StudentProfileSummaryReaderImpl over StudentRepositoryImpl', () {
    test(
      'maps the display fields unchanged from the same profile read',
      () async {
        final ds = _Datasource(profile: _profile);

        final result = await _reader(ds).getStudentProfileSummary('s1');

        expect(
          result,
          const Right<Failure, StudentProfileSummary>(
            StudentProfileSummary(
              name: ' سارة ',
              profileImageUrl: 'https://example.invalid/a.png',
              halaqaName: 'حلقة النور',
              level: 3,
              overallProgressPercent: 55.5,
              totalVersesMemorized: 120,
            ),
          ),
        );
        expect(ds.calls, ['s1']);
      },
    );

    test('keeps entity defaults for missing optional fields', () async {
      const bare = StudentProfileModel(
        uid: 's2',
        name: 'علي',
        currentPlanName: '',
        overallProgressPercent: 0,
        totalStars: 0,
        badges: [],
      );
      final result = await _reader(
        _Datasource(profile: bare),
      ).getStudentProfileSummary('s2');
      final summary = result.getOrElse((_) => throw StateError('left'));

      expect(summary.profileImageUrl, isNull);
      expect(summary.halaqaName, '');
      expect(summary.level, 1);
      expect(summary.totalVersesMemorized, 0);
    });

    test('offline fails with NetworkFailure without a read', () async {
      final ds = _Datasource(profile: _profile);

      final result = await _reader(
        ds,
        online: false,
      ).getStudentProfileSummary('s1');

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(ds.calls, isEmpty);
    });

    test(
      'a data source error maps to ServerFailure with its message',
      () async {
        final result = await _reader(
          _Datasource(
            error: const ServerException('لم يتم العثور على بيانات الطالب'),
          ),
        ).getStudentProfileSummary('s1');

        expect(
          result,
          const Left<Failure, StudentProfileSummary>(
            ServerFailure('لم يتم العثور على بيانات الطالب'),
          ),
        );
      },
    );
  });

  group('StudentProfileSummary contract', () {
    test('exposes no student-only data and imports no role module', () {
      final source = File(
        'lib/shared/domain/student_profile_summary.dart',
      ).readAsStringSync();
      final fields = RegExp(
        r'^\s+final [\w?<>]+ (\w+);',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)).toSet();
      expect(fields, {
        'name',
        'profileImageUrl',
        'halaqaName',
        'level',
        'overallProgressPercent',
        'totalVersesMemorized',
      });
      expect(source, isNot(contains('features/')));
      expect(source, isNot(contains('core/di')));
    });
  });

  group('StudentProfileSummaryReader DI wiring (manual config edit)', () {
    final module = _flat('lib/core/di/di_module.dart');
    final config = _flat('lib/core/di/injection_container.config.dart');

    test('module adapts the existing StudentRepository registration', () {
      expect(
        module,
        contains(
          '@lazySingletonStudentProfileSummaryReaderstudentProfileSummaryReader(StudentRepositoryrepository,)=>StudentProfileSummaryReaderImpl(repository);',
        ),
      );
    });

    test('config registers the reader under _i1206 over _i724', () {
      expect(
        config,
        contains(
          "import'package:rafiq_academy/shared/domain/student_profile_summary.dart'as_i1206;",
        ),
      );
      expect(
        config,
        contains(
          'gh.lazySingleton<_i1206.StudentProfileSummaryReader>(()=>diModule.studentProfileSummaryReader(gh<_i724.StudentRepository>()),);',
        ),
      );
    });

    test('there is still exactly one StudentRepository registration', () {
      expect(
        'gh.lazySingleton<_i724.StudentRepository>('.allMatches(config),
        hasLength(1),
      );
    });

    test('the student profile use case keeps its own registration', () {
      expect(
        config,
        contains(
          'gh.lazySingleton<_i385.GetStudentProfileUseCase>(()=>_i385.GetStudentProfileUseCase(gh<_i724.StudentRepository>()),);',
        ),
      );
    });
  });

  group('parent child profile reads through shared contracts', () {
    const page =
        'lib/features/parent/presentation/pages/parent_child_profile_page.dart';

    test('imports no student module', () {
      final imports = RegExp(
        r"^import '([^']+)'",
        multiLine: true,
      ).allMatches(File(page).readAsStringSync()).map((m) => m.group(1)!);
      expect(imports.where((u) => u.contains('/student/')), isEmpty);
    });

    test('profile, recitations and achievements keep their read paths', () {
      final source = File(page).readAsStringSync();
      expect(source, contains('sl<StudentProfileSummaryReader>()'));
      expect(source, contains('sl<RecitationRecordsReader>()'));
      expect(source, contains('sl<GetChildAchievementsUseCase>()'));
      expect(source, isNot(contains('GetStudentProfileUseCase')));
    });
  });

  group('latest-evaluation projection', () {
    test('the student path is a pure re-export of the shared file', () {
      expect(
        File(
          'lib/features/student/domain/student_profile_latest_evaluation.dart',
        ).readAsStringSync().trim(),
        "export '../../../shared/domain/student_profile_latest_evaluation.dart';",
      );
      expect(
        identical(
          student_path.pickLatestStudentProfileEvaluation,
          pickLatestStudentProfileEvaluation,
        ),
        isTrue,
      );
    });

    test('the shared projection imports only shared code', () {
      final source = File(
        'lib/shared/domain/student_profile_latest_evaluation.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('features/')));
      expect(source, isNot(contains('core/di')));
    });
  });
}
