import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/network/network_info.dart';
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource.dart';
import 'package:rafiq_academy/features/student/data/repositories/student_repository_impl.dart';
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart';
import 'package:rafiq_academy/shared/data/models/recitation_record_model.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_records_reader.dart';

String _flat(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), '');

class _Network implements NetworkInfo {
  _Network(this.connected);
  final bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class _Datasource extends Fake implements StudentRemoteDatasource {
  _Datasource({this.records = const [], this.error});

  final List<RecitationRecordModel> records;
  final Object? error;
  final calls = <String>[];

  @override
  Future<List<RecitationRecordModel>> getRecitationRecords(
    String studentId,
  ) async {
    calls.add(studentId);
    if (error != null) throw error!;
    return records;
  }
}

RecitationRecordModel _record(String id, DateTime date) =>
    RecitationRecordModel(
      id: id,
      studentId: 's1',
      studentName: 'أحمد',
      teacherId: 't1',
      halaqaId: 'h1',
      date: date,
      type: RecitationType.memorization,
      versesRange: '1-5',
    );

const _parentPages = [
  'lib/features/parent/presentation/pages/parent_child_profile_page.dart',
  'lib/features/parent/presentation/pages/parent_evaluations_page.dart',
  'lib/features/parent/presentation/pages/parent_reports_page.dart',
];

void main() {
  group('RecitationRecordsReader served by StudentRepositoryImpl', () {
    test('returns the data source records unchanged, in order', () async {
      final records = [
        _record('r2', DateTime(2026, 10, 2)),
        _record('r1', DateTime(2026, 10, 1)),
      ];
      final ds = _Datasource(records: records);
      final RecitationRecordsReader reader = StudentRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: _Network(true),
      );

      final result = await reader.getRecitationRecords('s1');

      expect(result.getOrElse((_) => const []), records);
      expect(ds.calls, ['s1']);
    });

    test('offline fails with NetworkFailure without a read', () async {
      final ds = _Datasource();
      final RecitationRecordsReader reader = StudentRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: _Network(false),
      );

      final result = await reader.getRecitationRecords('s1');

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(ds.calls, isEmpty);
    });

    test(
      'a data source error maps to ServerFailure with its message',
      () async {
        final RecitationRecordsReader reader = StudentRepositoryImpl(
          remoteDatasource: _Datasource(
            error: const ServerException('permission-denied'),
          ),
          networkInfo: _Network(true),
        );

        final result = await reader.getRecitationRecords('s1');

        expect(
          result,
          const Left<Failure, List<RecitationRecordEntity>>(
            ServerFailure('permission-denied'),
          ),
        );
      },
    );

    test('StudentRepository implements the shared reader', () {
      RecitationRecordsReader records(StudentRepository r) => r;
      expect(records, isNotNull);
      expect(
        _flat(
          'lib/features/student/domain/repositories/student_repository.dart',
        ),
        contains(
          'abstractclassStudentRepositoryimplementsRecitationRecordsReader,StudentAchievementsReader{',
        ),
      );
    });
  });

  group('RecitationRecordsReader DI wiring (manual config edit)', () {
    final module = _flat('lib/core/di/di_module.dart');
    final config = _flat('lib/core/di/injection_container.config.dart');

    test('module binds the reader to the StudentRepository registration', () {
      expect(
        module,
        contains(
          '@lazySingletonRecitationRecordsReaderrecitationRecordsReader(StudentRepositoryrepository,)=>repository;',
        ),
      );
    });

    test('config registers the reader under _i1205', () {
      expect(
        config,
        contains(
          "import'package:rafiq_academy/shared/domain/recitation_records_reader.dart'as_i1205;",
        ),
      );
      expect(
        config,
        contains(
          'gh.lazySingleton<_i1205.RecitationRecordsReader>(()=>diModule.recitationRecordsReader(gh<_i724.StudentRepository>()),);',
        ),
      );
    });

    test('the student use case keeps its own registration', () {
      expect(
        config,
        contains(
          'gh.lazySingleton<_i124.GetRecitationRecordsUseCase>(()=>_i124.GetRecitationRecordsUseCase(gh<_i724.StudentRepository>()),);',
        ),
      );
    });
  });

  group('parent recitation reads go through the shared reader', () {
    for (final page in _parentPages) {
      test('${page.split('/').last} uses RecitationRecordsReader', () {
        final source = File(page).readAsStringSync();
        expect(source, isNot(contains('get_recitation_records_usecase')));
        expect(source, isNot(contains('GetRecitationRecordsUseCase')));
        expect(source, contains('sl<RecitationRecordsReader>()'));
      });
    }

    test('the shared reader contract imports no role module', () {
      final source = File(
        'lib/shared/domain/recitation_records_reader.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('features/')));
      expect(source, isNot(contains('core/di')));
    });
  });
}
