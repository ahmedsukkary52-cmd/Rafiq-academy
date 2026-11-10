import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart';
import 'package:rafiq_academy/features/student/domain/usecases/get_student_halaqa_usecase.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';
import 'package:rafiq_academy/shared/domain/absence_request_projection.dart';
import 'package:rafiq_academy/shared/domain/assignment_entity.dart';
import 'package:rafiq_academy/shared/domain/id_params.dart';

class _StudentRepository extends Fake implements StudentRepository {
  final StreamController<Either<Failure, AssignmentEntity?>> controller;
  final watched = <String>[];

  _StudentRepository(this.controller);

  @override
  Stream<Either<Failure, AssignmentEntity?>> watchLatestAssignment(
    String studentId,
  ) {
    watched.add(studentId);
    return controller.stream;
  }
}

Iterable<String> _imports(String path) => RegExp(
  r"^import '([^']+)'",
  multiLine: true,
).allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!);

void main() {
  group('shared id params', () {
    test('keep value equality and props', () {
      expect(const StudentUidParams('s1'), const StudentUidParams('s1'));
      expect(const StudentUidParams('s1'), isNot(const StudentUidParams('s2')));
      expect(const StudentUidParams('s1').props, ['s1']);
      expect(const HalaqaIdParams('h1'), const HalaqaIdParams('h1'));
      expect(const HalaqaIdParams('h1'), isNot(const HalaqaIdParams('h2')));
      expect(const HalaqaIdParams('h1').props, ['h1']);
    });

    test('are the types the student use cases accept', () {
      // Compile-time: the student use cases still take the shared params.
      final useCase = WatchLatestAssignmentUseCase(
        _StudentRepository(StreamController()),
      );
      Stream<Either<Failure, AssignmentEntity?>> Function(StudentUidParams)
      watch = useCase.call;
      Future<Either<Failure, dynamic>> Function(HalaqaIdParams) halaqa =
          GetStudentHalaqaUseCase(_StudentRepository(StreamController())).call;
      expect([watch, halaqa], hasLength(2));
    });
  });

  group('WatchLatestAssignmentUseCase with shared StudentUidParams', () {
    test(
      'forwards the uid and relays events, errors and order unchanged',
      () async {
        final controller =
            StreamController<Either<Failure, AssignmentEntity?>>();
        final repo = _StudentRepository(controller);
        final assignment = AssignmentEntity(
          id: 'a1',
          studentId: 's1',
          assignedBy: 't1',
          newMemorizationRange: '1-5',
          reviewRange: '6-10',
          dueDate: DateTime(2026, 10, 25),
        );
        const failure = ServerFailure('permission-denied');

        final events = <Either<Failure, AssignmentEntity?>>[];
        final done = WatchLatestAssignmentUseCase(repo)(
          const StudentUidParams('s1'),
        ).forEach(events.add);
        controller
          ..add(const Right(null))
          ..add(Right(assignment))
          ..add(const Left(failure))
          ..add(Right(assignment));
        await controller.close();
        await done;

        expect(repo.watched, ['s1']);
        expect(events, [
          const Right<Failure, AssignmentEntity?>(null),
          Right<Failure, AssignmentEntity?>(assignment),
          const Left<Failure, AssignmentEntity?>(failure),
          Right<Failure, AssignmentEntity?>(assignment),
        ]);
      },
    );
  });

  group('removed role dependencies stay removed', () {
    const paramsOnlyImporters = [
      'lib/features/parent/domain/usecases/get_child_achievements_usecase.dart',
      'lib/features/parent/presentation/pages/parent_achievements_page.dart',
      'lib/features/parent/presentation/pages/parent_child_profile_page.dart',
      'lib/features/student/presentation/student_chat_teacher_resolver.dart',
      'lib/features/homework/domain/usecases/homework_usecases.dart',
      'lib/features/homework/presentation/bloc/homework_bloc.dart',
      'lib/features/progress_report/presentation/bloc/progress_report_bloc.dart',
    ];
    for (final path in paramsOnlyImporters) {
      test('${path.split('/').last} takes the params from shared', () {
        final imports = _imports(path).toList();
        expect(
          imports.where((u) => u.contains('watch_latest_assignment_usecase')),
          isEmpty,
        );
        expect(
          imports.where((u) => u.endsWith('shared/domain/id_params.dart')),
          hasLength(1),
        );
      });
    }

    for (final path in [
      'lib/features/parent/presentation/pages/parent_evaluations_page.dart',
      'lib/features/parent/presentation/pages/parent_reports_page.dart',
      'lib/features/supervisor/presentation/pages/supervisor_awards_hub_page.dart',
    ]) {
      test('${path.split('/').last} imports no student module', () {
        final imports = _imports(path).toList();
        expect(imports.where((u) => u.contains('/student/')), isEmpty);
        expect(
          imports.any((u) => u.endsWith('shared/domain/id_params.dart')),
          File(path).readAsStringSync().contains('StudentUidParams'),
          reason: 'params, when used, come from shared id_params only',
        );
      });
    }

    test('supervisor absence section reads the shared projection directly', () {
      final imports = _imports(
        'lib/features/supervisor/presentation/widgets/supervisor_absence_requests_section.dart',
      ).toList();
      expect(imports.where((u) => u.contains('/parent/')), isEmpty);
      expect(
        imports.where(
          (u) => u.endsWith('shared/domain/absence_request_projection.dart'),
        ),
        hasLength(1),
      );
    });

    test('the parent re-export stays a pure re-export of the shared file', () {
      final source = File(
        'lib/features/parent/domain/absence_request_projection.dart',
      ).readAsStringSync();
      expect(
        source,
        contains(
          "export '../../../../shared/domain/absence_request_projection.dart';",
        ),
      );
      expect(
        RegExp(r'^(class|enum|extension) ', multiLine: true).hasMatch(source),
        isFalse,
      );
    });
  });

  group('shared absence-request projection', () {
    test('labels every status', () {
      for (final status in AbsenceRequestStatus.values) {
        expect(AbsenceRequestProjection.statusLabel(status), isNotEmpty);
      }
    });
  });
}
