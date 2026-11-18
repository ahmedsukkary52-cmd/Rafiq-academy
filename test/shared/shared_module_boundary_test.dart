import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/domain/attendance_record_entity.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/shared/domain/halaqa_roster.dart';
import 'package:rafiq_academy/shared/domain/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/shared/domain/load_halaqa_day_readiness.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_records_query_mode.dart';

const _roleModules = ['student', 'teacher', 'supervisor', 'parent', 'admin'];

/// Import targets of [file], as `lib/`-relative paths (Dart clamps `..` at
/// the package root).
Iterable<String> _libImports(File file) sync* {
  final dir = '/${file.parent.path.replaceAll(r'\', '/')}/';
  final fromDir = dir
      .substring(dir.lastIndexOf('/lib/') + '/lib/'.length)
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  final directive = RegExp(r"^(?:import|export) '([^']+)'", multiLine: true);
  for (final match in directive.allMatches(file.readAsStringSync())) {
    final uri = match.group(1)!;
    if (uri.startsWith('package:rafiq_academy/')) {
      yield uri.substring('package:rafiq_academy/'.length);
    } else if (!uri.contains(':')) {
      final parts = [...fromDir];
      for (final segment in uri.split('/')) {
        if (segment == '..') {
          if (parts.isNotEmpty) parts.removeLast();
        } else if (segment != '.') {
          parts.add(segment);
        }
      }
      yield parts.join('/');
    }
  }
}

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _flat(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), '');

class _FakeRosterReader implements HalaqaRosterReader {
  final calls = <String>[];

  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String halaqaId,
  ) async {
    calls.add(halaqaId);
    return const Right([HalaqaStudentSummaryEntity(uid: 's1', name: 'طالب')]);
  }
}

class _FakeDayFactsReader implements HalaqaDayFactsReader {
  final calls = <String>[];

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async {
    calls.add('attendance:$halaqaId');
    return const Right([]);
  }

  @override
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  ) async {
    calls.add('due:$halaqaId');
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId, {int? maxRecords, RecitationRecordsQueryMode mode = RecitationRecordsQueryMode.fullHistory}) async {
    calls.add('reviews:$halaqaId');
    return const Right([]);
  }
}

void main() {
  group('lib/shared module boundary', () {
    test('no shared file imports a role module', () {
      final offenders = <String>[];
      for (final file in _dartFiles('lib/shared')) {
        for (final target in _libImports(file)) {
          for (final role in _roleModules) {
            if (target.startsWith('features/$role/')) {
              offenders.add('${file.path} -> $target');
            }
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('no shared file reaches a role module or core/di transitively', () {
      final via = <String, String?>{};
      final queue = <String>[];
      for (final file in _dartFiles('lib/shared')) {
        final path = file.path.replaceAll(r'\', '/');
        final rel = path.substring(path.lastIndexOf('lib/') + 'lib/'.length);
        via[rel] = null;
        queue.add(rel);
      }
      final offenders = <String>[];
      while (queue.isNotEmpty) {
        final rel = queue.removeAt(0);
        final blocked =
            rel.startsWith('core/di/') ||
            _roleModules.any((role) => rel.startsWith('features/$role/'));
        if (blocked) {
          final chain = <String>[];
          for (String? at = rel; at != null; at = via[at]) {
            chain.insert(0, at);
          }
          offenders.add(chain.join(' -> '));
          continue;
        }
        final file = File('lib/$rel');
        if (!file.existsSync()) continue;
        for (final target in _libImports(file)) {
          if (!via.containsKey(target)) {
            via[target] = rel;
            queue.add(target);
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('extracted files live only in lib/shared', () {
      const moved = {
        'lib/features/student/domain/entities/halaqa_entity.dart':
            'lib/shared/domain/halaqa_entity.dart',
        'lib/features/student/domain/entities/recitation_record_entity.dart':
            'lib/shared/domain/recitation_record_entity.dart',
        'lib/features/student/domain/entities/assignment_entity.dart':
            'lib/shared/domain/assignment_entity.dart',
        'lib/features/teacher/domain/entities/attendance_record_entity.dart':
            'lib/shared/domain/attendance_record_entity.dart',
        'lib/features/teacher/domain/entities/halaqa_students_summary_entity.dart':
            'lib/shared/domain/halaqa_students_summary_entity.dart',
        'lib/features/student/data/models/halaqa_model.dart':
            'lib/shared/data/models/halaqa_model.dart',
        'lib/features/student/data/models/halaqa_schedule_model.dart':
            'lib/shared/data/models/halaqa_schedule_model.dart',
        'lib/features/student/data/models/recitation_record_model.dart':
            'lib/shared/data/models/recitation_record_model.dart',
        'lib/features/student/data/models/assignment_model.dart':
            'lib/shared/data/models/assignment_model.dart',
        'lib/features/teacher/domain/usecases/get_halaqa_students_usecase.dart':
            'lib/shared/domain/halaqa_roster.dart',
        'lib/features/parent/domain/parent_payment_proof.dart':
            'lib/shared/domain/parent_payment_proof.dart',
        'lib/features/teacher/domain/usecases/get_halaqa_attendance_for_date_usecase.dart':
            'lib/shared/domain/halaqa_attendance_for_date.dart',
        'lib/features/parent/presentation/widgets/payment_proof_image.dart':
            'lib/shared/widgets/payment_proof_image.dart',
      };
      moved.forEach((oldPath, newPath) {
        expect(File(oldPath).existsSync(), isFalse, reason: oldPath);
        expect(File(newPath).existsSync(), isTrue, reason: newPath);
      });
    });

    test('Payment and AttendanceStatus types are declared once, in shared', () {
      final declarations = <String, List<String>>{};
      final pattern = RegExp(
        r'^(?:enum|class) (PaymentStatus|PaymentEntity|AttendanceStatus|'
        r'HalaqaStudentsParams|PaymentModel|DownloadPaymentProofParams|'
        r'DownloadPaymentProofUseCase|HalaqaAttendanceDateParams|'
        r'StudentUidParams|HalaqaIdParams|MonthlyScheduleParams)\b',
        multiLine: true,
      );
      for (final file in _dartFiles('lib')) {
        for (final m in pattern.allMatches(file.readAsStringSync())) {
          declarations
              .putIfAbsent(m.group(1)!, () => [])
              .add(file.path.replaceAll(r'\', '/'));
        }
      }
      for (final paths in declarations.values) {
        paths.sort();
      }
      expect(declarations, {
        'PaymentStatus': ['lib/shared/domain/payment_entity.dart'],
        'PaymentEntity': ['lib/shared/domain/payment_entity.dart'],
        'AttendanceStatus': ['lib/shared/domain/attendance_record_entity.dart'],
        'HalaqaStudentsParams': ['lib/shared/domain/halaqa_roster.dart'],
        'PaymentModel': ['lib/shared/data/models/payment_model.dart'],
        'DownloadPaymentProofParams': [
          'lib/shared/domain/payment_proof_reader.dart',
        ],
        'DownloadPaymentProofUseCase': [
          'lib/shared/domain/payment_proof_reader.dart',
        ],
        'HalaqaAttendanceDateParams': [
          'lib/shared/domain/halaqa_attendance_for_date.dart',
        ],
        'StudentUidParams': ['lib/shared/domain/id_params.dart'],
        // analytics and awards keep their own same-named, feature-local class.
        'HalaqaIdParams': [
          'lib/features/analytics/domain/usecases/analytics_usecases.dart',
          'lib/features/awards/domain/usecases/awards_usecases.dart',
          'lib/shared/domain/id_params.dart',
        ],
        'MonthlyScheduleParams': [
          'lib/features/student/domain/usecases/watch_latest_assignment_usecase.dart',
        ],
      });
    });
  });

  group('shared Halaqa roster contract', () {
    test('GetHalaqaStudentsUseCase reads through HalaqaRosterReader', () async {
      final reader = _FakeRosterReader();
      final result = await GetHalaqaStudentsUseCase(
        reader,
      ).call(const HalaqaStudentsParams('h1'));

      expect(reader.calls, ['h1']);
      expect(result.getOrElse((_) => const []).single.uid, 's1');
    });

    test('TeacherRepository serves the shared roster and day-facts reads', () {
      expect(
        _flat(
          'lib/features/teacher/domain/repositories/teacher_repository.dart',
        ),
        contains(
          'abstractclassTeacherRepositoryimplementsHalaqaRosterReader,HalaqaDayFactsReader{',
        ),
      );
    });

    test('DI binds HalaqaRosterReader to the TeacherRepository registration', () {
      expect(
        _flat('lib/core/di/di_module.dart'),
        contains(
          '@lazySingletonHalaqaRosterReaderhalaqaRosterReader(TeacherRepositoryrepository)=>repository;',
        ),
      );
      final config = _flat('lib/core/di/injection_container.config.dart');
      expect(
        config,
        contains(
          "import'package:rafiq_academy/shared/domain/halaqa_roster.dart'as_i440;",
        ),
      );
      expect(
        config,
        contains(
          'gh.lazySingleton<_i440.HalaqaRosterReader>(()=>diModule.halaqaRosterReader(gh<_i1050.TeacherRepository>()),);',
        ),
      );
      expect(
        config,
        contains(
          '_i440.GetHalaqaStudentsUseCase(gh<_i440.HalaqaRosterReader>())',
        ),
      );
      expect(config, isNot(contains('get_halaqa_students_usecase.dart')));
    });
  });

  group('shared Halaqa day readiness', () {
    test(
      'loads facts from any HalaqaDayFactsReader, not only the teacher repository',
      () async {
        final reader = _FakeDayFactsReader();
        const halaqa = HalaqaEntity(
          id: 'h1',
          name: 'H1',
          teacherId: 't1',
          supervisorId: 'sv1',
          studentIds: ['s1'],
          schedule: [],
          status: 'active',
        );

        final result = await loadHalaqaDayFacts(
          teacherRepository: reader,
          halaqa: halaqa,
          now: DateTime(2026, 10, 24, 9),
        );

        expect(result.isRight(), isTrue);
        expect(reader.calls, ['attendance:h1', 'due:h1', 'reviews:h1']);
        expect(reader, isNot(isA<TeacherRepository>()));
      },
    );
  });
}
