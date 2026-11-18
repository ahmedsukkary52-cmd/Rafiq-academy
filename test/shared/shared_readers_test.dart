import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/domain/attendance_record_entity.dart';
import 'package:rafiq_academy/shared/domain/halaqa_attendance_for_date.dart';
import 'package:rafiq_academy/shared/domain/load_halaqa_day_readiness.dart';
import 'package:rafiq_academy/shared/domain/payment_proof_reader.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_records_query_mode.dart';
import 'package:rafiq_academy/shared/domain/student_parent_links.dart';
import 'package:rafiq_academy/shared/domain/user_display_names.dart';

String _flat(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), '');

class _ProofReader implements PaymentProofReader {
  final Either<Failure, Uint8List> result;
  final calls = <List<String>>[];

  _ProofReader(this.result);

  @override
  Future<Either<Failure, Uint8List>> downloadPaymentProof({
    required String parentId,
    required String paymentId,
    required String storagePath,
  }) async {
    calls.add([parentId, paymentId, storagePath]);
    return result;
  }
}

class _AttendanceReader implements HalaqaDayFactsReader {
  final Either<Failure, List<AttendanceRecordEntity>> result;
  final calls = <String>[];

  _AttendanceReader(this.result);

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async {
    calls.add('$halaqaId@${date.toIso8601String()}');
    return result;
  }

  @override
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId, {int? maxRecords, RecitationRecordsQueryMode mode = RecitationRecordsQueryMode.fullHistory}) =>
      throw UnimplementedError();
}

void main() {
  group('DownloadPaymentProofUseCase over PaymentProofReader', () {
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('reads a trusted proof path with trimmed ids', () async {
      final reader = _ProofReader(Right(bytes));
      final result = await DownloadPaymentProofUseCase(reader)(
        const DownloadPaymentProofParams(
          parentId: ' p1 ',
          paymentId: ' pay1 ',
          storagePath: ' payment_proofs/p1/pay1/1760000000000.png ',
        ),
      );

      expect(result, Right<Failure, Uint8List>(bytes));
      expect(reader.calls, [
        ['p1', 'pay1', 'payment_proofs/p1/pay1/1760000000000.png'],
      ]);
    });

    for (final path in [
      '',
      'payment_proofs/p2/pay1/1.png',
      'payment_proofs/p1/pay2/1.png',
      'https://example.invalid/proof.png',
    ]) {
      test('fails closed without a Storage read for "$path"', () async {
        final reader = _ProofReader(Right(bytes));
        final result = await DownloadPaymentProofUseCase(reader)(
          DownloadPaymentProofParams(
            parentId: 'p1',
            paymentId: 'pay1',
            storagePath: path,
          ),
        );

        expect(result.getLeft().toNullable(), isA<ValidationFailure>());
        expect(reader.calls, isEmpty);
      });
    }

    for (final failure in <Failure>[
      const AuthFailure('permission-denied'),
      const ServerFailure('object-not-found'),
      const NetworkFailure(),
    ]) {
      test('propagates ${failure.runtimeType} from the reader', () async {
        final result =
            await DownloadPaymentProofUseCase(_ProofReader(Left(failure)))(
              const DownloadPaymentProofParams(
                parentId: 'p1',
                paymentId: 'pay1',
                storagePath: 'payment_proofs/p1/pay1/1.jpg',
              ),
            );

        expect(result, Left<Failure, Uint8List>(failure));
      });
    }
  });

  group('GetHalaqaAttendanceForDateUseCase over HalaqaDayFactsReader', () {
    final date = DateTime(2026, 10, 24);

    test('reads the requested halaqa day', () async {
      final record = AttendanceRecordEntity(
        id: 'h1_s1',
        studentId: 's1',
        studentName: 's1',
        halaqaId: 'h1',
        date: date,
        status: AttendanceStatus.present,
        recordedBy: 't1',
        sessionId: 'h1_20261024',
      );
      final reader = _AttendanceReader(Right([record]));
      final result = await GetHalaqaAttendanceForDateUseCase(reader)(
        HalaqaAttendanceDateParams(halaqaId: 'h1', date: date),
      );

      expect(result.getOrElse((_) => const []), [record]);
      expect(reader.calls, ['h1@${date.toIso8601String()}']);
      expect(reader, isNot(isA<TeacherRepository>()));
    });

    test('propagates the reader failure', () async {
      const failure = AuthFailure('permission-denied');
      final result = await GetHalaqaAttendanceForDateUseCase(
        _AttendanceReader(const Left(failure)),
      )(HalaqaAttendanceDateParams(halaqaId: 'h1', date: date));

      expect(
        result,
        const Left<Failure, List<AttendanceRecordEntity>>(failure),
      );
    });
  });

  group('role repositories serve the shared readers', () {
    test('ParentRepository and SupervisorRepository implement them', () {
      expect(
        _flat(
          'lib/features/parent/domain/repositories/parent_repositories.dart',
        ),
        contains(
          'abstractclassParentRepositoryimplementsPaymentProofReader,StudentParentLinkReader{',
        ),
      );
      expect(
        _flat(
          'lib/features/supervisor/domain/repositories/parent_repository.dart',
        ),
        contains(
          'abstractclassSupervisorRepositoryimplementsUserDisplayNameReader{',
        ),
      );
    });

    test('a role repository is assignable to its shared reader', () {
      // Compile-time proof that the DI module bindings type-check.
      PaymentProofReader proofs(ParentRepository r) => r;
      StudentParentLinkReader links(ParentRepository r) => r;
      UserDisplayNameReader names(SupervisorRepository r) => r;
      HalaqaDayFactsReader facts(TeacherRepository r) => r;
      expect([proofs, links, names, facts], hasLength(4));
    });
  });

  group('DI wiring (manual config edit, not regenerated)', () {
    final module = _flat('lib/core/di/di_module.dart');
    final config = _flat('lib/core/di/injection_container.config.dart');

    const bindings = {
      'HalaqaDayFactsReaderhalaqaDayFactsReader(TeacherRepositoryrepository)=>repository;':
          'gh.lazySingleton<_i1201.HalaqaDayFactsReader>(()=>diModule.halaqaDayFactsReader(gh<_i1050.TeacherRepository>()),);',
      'PaymentProofReaderpaymentProofReader(ParentRepositoryrepository)=>repository;':
          'gh.lazySingleton<_i1202.PaymentProofReader>(()=>diModule.paymentProofReader(gh<_i493.ParentRepository>()),);',
      'StudentParentLinkReaderstudentParentLinkReader(ParentRepositoryrepository,)=>repository;':
          'gh.lazySingleton<_i1203.StudentParentLinkReader>(()=>diModule.studentParentLinkReader(gh<_i493.ParentRepository>()),);',
      'UserDisplayNameReaderuserDisplayNameReader(SupervisorRepositoryrepository,)=>repository;':
          'gh.lazySingleton<_i1204.UserDisplayNameReader>(()=>diModule.userDisplayNameReader(gh<_i307.SupervisorRepository>()),);',
    };

    bindings.forEach((moduleSource, configSource) {
      final name = moduleSource.substring(0, moduleSource.indexOf('('));
      test('binds $name in the module and the config', () {
        expect(module, contains('@lazySingleton$moduleSource'));
        expect(config, contains(configSource));
      });
    });

    test('config imports each shared reader under its alias', () {
      for (final entry in {
        'load_halaqa_day_readiness': '_i1201',
        'payment_proof_reader': '_i1202',
        'student_parent_links': '_i1203',
        'user_display_names': '_i1204',
      }.entries) {
        expect(
          config,
          contains(
            "import'package:rafiq_academy/shared/domain/${entry.key}.dart'as${entry.value};",
          ),
        );
      }
    });

    test('use cases resolve the readers, not the role repositories', () {
      expect(
        config,
        contains(
          '_i824.GetSupervisorDayBoardUseCase(dayFactsReader:gh<_i1201.HalaqaDayFactsReader>(),supervisorRepository:gh<_i307.SupervisorRepository>(),)',
        ),
      );
      expect(
        config,
        contains(
          '_i122.GetHalaqaAttendanceForDateUseCase(gh<_i1201.HalaqaDayFactsReader>(),)',
        ),
      );
      expect(
        config,
        contains(
          '_i1202.DownloadPaymentProofUseCase(gh<_i1202.PaymentProofReader>(),)',
        ),
      );
      expect(
        config,
        contains(
          "import'package:rafiq_academy/shared/domain/halaqa_attendance_for_date.dart'as_i122;",
        ),
      );
      expect(config, isNot(contains('_i347.DownloadPaymentProofUseCase')));
    });
  });

  group('removed cross-role dependencies stay removed', () {
    const forbidden = {
      'lib/features/supervisor/domain/usecases/get_supervisor_day_board_usecase.dart':
          'teacher_repository.dart',
      'lib/features/supervisor/presentation/pages/supervisor_attendance_page.dart':
          'features/teacher/',
      'lib/features/supervisor/presentation/pages/supervisor_payments_page.dart':
          'parent/presentation/',
      'lib/features/admin/presentation/pages/payment_review_page.dart':
          'parent/presentation/',
      'lib/features/supervisor/presentation/pages/supervisor_follow_up_page.dart':
          'parent_repositories.dart',
      'lib/features/supervisor/presentation/pages/supervisor_messages_tab.dart':
          'parent_repositories.dart',
      'lib/features/staff/contact_parent/contact_student_parent.dart':
          'parent_repositories.dart',
      'lib/features/staff/student_profile/presentation/pages/student_profile_page.dart':
          'parent_repositories.dart',
      'lib/features/teacher/presentation/pages/teacher_classes_page.dart':
          'supervisor/domain/',
      'lib/features/supervisor/data/data_sources/supervisor_remote_datasource.dart':
          'parent/data/',
      'lib/features/supervisor/data/data_sources/supervisor_remote_datasource_impl.dart':
          'parent/data/',
    };

    forbidden.forEach((file, target) {
      test('${file.split('/').last} does not import $target', () {
        final imports = RegExp(
          r"^import '([^']+)'",
          multiLine: true,
        ).allMatches(File(file).readAsStringSync()).map((m) => m.group(1)!);
        expect(imports.where((uri) => uri.contains(target)), isEmpty);
      });
    });

    test('only the parent feature and DI resolve ParentRepository from sl', () {
      final offenders = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.startsWith('lib/features/parent/') ||
            path.startsWith('lib/core/di/')) {
          continue;
        }
        if (file.readAsStringSync().contains('sl<ParentRepository>')) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
