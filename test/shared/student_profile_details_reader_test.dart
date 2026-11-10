import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:rafiq_academy/core/di/di_module.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/network/network_info.dart';
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource.dart';
import 'package:rafiq_academy/features/student/data/models/student_profile_model.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_halaqa_name_reader_impl.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_profile_details_reader_impl.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_profile_summary_reader_impl.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_repository_impl.dart';
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart';
import 'package:rafiq_academy/shared/data/models/halaqa_model.dart';
import 'package:rafiq_academy/shared/domain/halaqa_name_reader.dart';
import 'package:rafiq_academy/shared/domain/recitation_records_reader.dart';
import 'package:rafiq_academy/shared/domain/student_profile_details.dart';
import 'package:rafiq_academy/shared/domain/student_profile_summary.dart';

class _Module extends DiModule {}

String _flat(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), '');

Set<String?> _fields(String path) => RegExp(
  r'^\s+final [\w?<>]+ (\w+);',
  multiLine: true,
).allMatches(File(path).readAsStringSync()).map((m) => m.group(1)).toSet();

class _Network implements NetworkInfo {
  _Network(this.connected);
  final bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class _Datasource extends Fake implements StudentRemoteDatasource {
  _Datasource({this.profile, this.halaqa, this.error});

  final StudentProfileModel? profile;
  final HalaqaModel? halaqa;
  final Object? error;
  final calls = <String>[];

  @override
  Future<StudentProfileModel> getStudentProfile(String uid) async {
    calls.add('profile $uid');
    if (error != null) throw error!;
    return profile!;
  }

  @override
  Future<HalaqaModel> getStudentHalaqa(String halaqaId) async {
    calls.add('halaqa $halaqaId');
    if (error != null) throw error!;
    return halaqa!;
  }
}

final _profile = StudentProfileModel(
  uid: 's1',
  name: ' سارة ',
  profileImageUrl: 'https://example.invalid/a.png',
  halaqaId: 'h1',
  halaqaName: 'حلقة النور',
  currentPlanName: 'خطة',
  overallProgressPercent: 55.5,
  totalVersesMemorized: 120,
  streakDays: 4,
  level: 3,
  totalStars: 7,
  badges: const ['b1'],
  coins: 40,
  avatarId: 'owl',
  createdAt: DateTime(2024, 9, 3),
);

StudentRepositoryImpl _repo(_Datasource ds, {bool online = true}) =>
    StudentRepositoryImpl(remoteDatasource: ds, networkInfo: _Network(online));

void main() {
  group('StudentProfileDetailsReaderImpl over StudentRepositoryImpl', () {
    test('maps the staff fields from one profile read', () async {
      final ds = _Datasource(profile: _profile);

      final result = await StudentProfileDetailsReaderImpl(
        _repo(ds),
      ).getStudentProfileDetails('s1');

      expect(
        result,
        Right<Failure, StudentProfileDetails>(
          StudentProfileDetails(
            summary: const StudentProfileSummary(
              name: ' سارة ',
              profileImageUrl: 'https://example.invalid/a.png',
              halaqaName: 'حلقة النور',
              level: 3,
              overallProgressPercent: 55.5,
              totalVersesMemorized: 120,
            ),
            halaqaId: 'h1',
            currentPlanName: 'خطة',
            streakDays: 4,
            createdAt: DateTime(2024, 9, 3),
          ),
        ),
      );
      expect(ds.calls, ['profile s1']);
    });

    test('the summary part is the summary reader mapping', () async {
      final ds = _Datasource(profile: _profile);
      final repo = _repo(ds);

      final details = (await StudentProfileDetailsReaderImpl(
        repo,
      ).getStudentProfileDetails('s1')).getOrElse((_) => throw StateError(''));
      final summary = (await StudentProfileSummaryReaderImpl(
        repo,
      ).getStudentProfileSummary('s1')).getOrElse((_) => throw StateError(''));

      expect(details.summary, summary);
      expect(
        details.summary,
        StudentProfileSummaryReaderImpl.summaryOf(_profile),
      );
    });

    test('keeps entity defaults for missing optional fields', () async {
      const bare = StudentProfileModel(
        uid: 's2',
        name: 'علي',
        currentPlanName: '',
        overallProgressPercent: 0,
        totalStars: 0,
        badges: [],
      );
      final details = (await StudentProfileDetailsReaderImpl(
        _repo(_Datasource(profile: bare)),
      ).getStudentProfileDetails('s2')).getOrElse((_) => throw StateError(''));

      expect(details.halaqaId, isNull);
      expect(details.createdAt, isNull);
      expect(details.streakDays, 0);
      expect(details.currentPlanName, '');
      expect(details.summary.halaqaName, '');
    });

    test('offline fails with NetworkFailure without a read', () async {
      final ds = _Datasource(profile: _profile);

      final result = await StudentProfileDetailsReaderImpl(
        _repo(ds, online: false),
      ).getStudentProfileDetails('s1');

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(ds.calls, isEmpty);
    });

    test(
      'a data source error maps to ServerFailure with its message',
      () async {
        final result = await StudentProfileDetailsReaderImpl(
          _repo(
            _Datasource(
              error: const ServerException('لم يتم العثور على بيانات الطالب'),
            ),
          ),
        ).getStudentProfileDetails('s1');

        expect(
          result,
          const Left<Failure, StudentProfileDetails>(
            ServerFailure('لم يتم العثور على بيانات الطالب'),
          ),
        );
      },
    );
  });

  group('StudentHalaqaNameReaderImpl over StudentRepositoryImpl', () {
    const halaqa = HalaqaModel(
      id: 'h1',
      name: 'حلقة الفجر',
      teacherId: 't1',
      supervisorId: 'sv1',
      studentIds: ['s1'],
      schedule: [],
      status: 'active',
    );

    test('returns only the name from one halaqa read', () async {
      final ds = _Datasource(halaqa: halaqa);

      final result = await StudentHalaqaNameReaderImpl(
        _repo(ds),
      ).getHalaqaName('h1');

      expect(result, const Right<Failure, String>('حلقة الفجر'));
      expect(ds.calls, ['halaqa h1']);
    });

    test('offline fails with NetworkFailure without a read', () async {
      final ds = _Datasource(halaqa: halaqa);

      final result = await StudentHalaqaNameReaderImpl(
        _repo(ds, online: false),
      ).getHalaqaName('h1');

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(ds.calls, isEmpty);
    });

    test(
      'a data source error maps to ServerFailure with its message',
      () async {
        final result = await StudentHalaqaNameReaderImpl(
          _repo(_Datasource(error: const ServerException('غير موجودة'))),
        ).getHalaqaName('h1');

        expect(
          result,
          const Left<Failure, String>(ServerFailure('غير موجودة')),
        );
      },
    );
  });

  group('shared contracts', () {
    test('details expose only the staff profile fields', () {
      expect(_fields('lib/shared/domain/student_profile_details.dart'), {
        'summary',
        'halaqaId',
        'currentPlanName',
        'streakDays',
        'createdAt',
      });
    });

    test('contracts import only shared/core code', () {
      for (final path in [
        'lib/shared/domain/student_profile_details.dart',
        'lib/shared/domain/halaqa_name_reader.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('features/')), reason: path);
        expect(source, isNot(contains('core/di')), reason: path);
      }
    });

    test('the halaqa reader returns a name, not a halaqa entity', () {
      final source = File(
        'lib/shared/domain/halaqa_name_reader.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('Future<Either<Failure, String>> getHalaqaName('),
      );
      expect(source, isNot(contains('HalaqaEntity')));
    });
  });

  group('DI module factories reuse one StudentRepository (runtime)', () {
    test('every reader wraps the same registered repository instance', () {
      final gh = GetIt.asNewInstance();
      final module = _Module();
      final repo = _repo(_Datasource());
      gh
        ..registerLazySingleton<StudentRepository>(() => repo)
        ..registerLazySingleton<StudentProfileDetailsReader>(
          () => module.studentProfileDetailsReader(gh<StudentRepository>()),
        )
        ..registerLazySingleton<HalaqaNameReader>(
          () => module.halaqaNameReader(gh<StudentRepository>()),
        )
        ..registerLazySingleton<RecitationRecordsReader>(
          () => module.recitationRecordsReader(gh<StudentRepository>()),
        )
        ..registerLazySingleton<StudentProfileSummaryReader>(
          () => module.studentProfileSummaryReader(gh<StudentRepository>()),
        );

      final details =
          gh<StudentProfileDetailsReader>() as StudentProfileDetailsReaderImpl;
      final halaqa = gh<HalaqaNameReader>() as StudentHalaqaNameReaderImpl;
      final summary =
          gh<StudentProfileSummaryReader>() as StudentProfileSummaryReaderImpl;

      expect(identical(details.repository, repo), isTrue);
      expect(identical(halaqa.repository, repo), isTrue);
      expect(identical(summary.repository, repo), isTrue);
      expect(identical(gh<RecitationRecordsReader>(), repo), isTrue);
      expect(identical(gh<StudentProfileDetailsReader>(), details), isTrue);
      expect(identical(gh<HalaqaNameReader>(), halaqa), isTrue);
    });
  });

  group('DI wiring (manual config edit)', () {
    final module = _flat('lib/core/di/di_module.dart');
    final config = _flat('lib/core/di/injection_container.config.dart');

    test('module adapts the existing StudentRepository registration', () {
      expect(
        module,
        contains(
          '@lazySingletonStudentProfileDetailsReaderstudentProfileDetailsReader(StudentRepositoryrepository,)=>StudentProfileDetailsReaderImpl(repository);',
        ),
      );
      expect(
        module,
        contains(
          '@lazySingletonHalaqaNameReaderhalaqaNameReader(StudentRepositoryrepository)=>StudentHalaqaNameReaderImpl(repository);',
        ),
      );
    });

    test('config registers both readers over _i724', () {
      expect(
        config,
        contains(
          "import'package:rafiq_academy/shared/domain/student_profile_details.dart'as_i1208;",
        ),
      );
      expect(
        config,
        contains(
          "import'package:rafiq_academy/shared/domain/halaqa_name_reader.dart'as_i1209;",
        ),
      );
      expect(
        config,
        contains(
          'gh.lazySingleton<_i1208.StudentProfileDetailsReader>(()=>diModule.studentProfileDetailsReader(gh<_i724.StudentRepository>()),);',
        ),
      );
      expect(
        config,
        contains(
          'gh.lazySingleton<_i1209.HalaqaNameReader>(()=>diModule.halaqaNameReader(gh<_i724.StudentRepository>()),);',
        ),
      );
    });

    test('each alias is declared once and each reader registered once', () {
      expect('as_i1208;'.allMatches(config), hasLength(1));
      expect('as_i1209;'.allMatches(config), hasLength(1));
      expect(
        'gh.lazySingleton<_i1208.StudentProfileDetailsReader>('.allMatches(
          config,
        ),
        hasLength(1),
      );
      expect(
        'gh.lazySingleton<_i1209.HalaqaNameReader>('.allMatches(config),
        hasLength(1),
      );
    });

    test('there is still exactly one StudentRepository registration', () {
      expect(
        'gh.lazySingleton<_i724.StudentRepository>('.allMatches(config),
        hasLength(1),
      );
      expect('StudentRepositoryImpl('.allMatches(config), hasLength(1));
    });

    test('recitations reuse the existing reader registration', () {
      expect(
        config,
        contains(
          'gh.lazySingleton<_i1205.RecitationRecordsReader>(()=>diModule.recitationRecordsReader(gh<_i724.StudentRepository>()),);',
        ),
      );
      expect(module, contains('=>repository;'));
    });

    test('the student use cases keep their registrations', () {
      for (final line in [
        'gh.lazySingleton<_i385.GetStudentProfileUseCase>(()=>_i385.GetStudentProfileUseCase(gh<_i724.StudentRepository>()),);',
        'gh.lazySingleton<_i554.GetStudentHalaqaUseCase>(()=>_i554.GetStudentHalaqaUseCase(gh<_i724.StudentRepository>()),);',
        'gh.lazySingleton<_i124.GetRecitationRecordsUseCase>(()=>_i124.GetRecitationRecordsUseCase(gh<_i724.StudentRepository>()),);',
      ]) {
        expect(config, contains(line));
      }
    });
  });

  group('no duplicated queries', () {
    test('the adapters hold no Firestore code of their own', () {
      for (final path in [
        'lib/features/student/data/repositories/student_profile_details_reader_impl.dart',
        'lib/features/student/data/repositories/student_halaqa_name_reader_impl.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('cloud_firestore')), reason: path);
        expect(source, isNot(contains('collection(')), reason: path);
        expect(source, contains('final StudentRepository repository;'));
      }
    });

    test('profile and halaqa documents are read only by the data source', () {
      final offenders = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.endsWith('student_remote_datasource_impl.dart') ||
            path.endsWith('student/data/models/student_profile_model.dart')) {
          continue;
        }
        final source = file.readAsStringSync();
        if (source.contains('StudentProfileModel.fromFirestore(')) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
