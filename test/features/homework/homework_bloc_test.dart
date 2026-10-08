import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/homework/domain/entities/homework_entity.dart';
import 'package:rafiq_academy/features/homework/domain/repositories/homework_repository.dart';
import 'package:rafiq_academy/features/homework/domain/usecases/homework_usecases.dart';
import 'package:rafiq_academy/features/homework/presentation/bloc/homework_bloc.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';

typedef _Feed = Either<Failure, HomeworkEntity?>;

HomeworkEntity _hw({bool done = false, bool submitted = false}) =>
    HomeworkEntity(
      id: 'hw1',
      title: 'واجب',
      dueAt: DateTime(2026, 9, 3),
      isSubmitted: submitted,
      tasks: [
        HomeworkTaskEntity(
          id: 'task1',
          title: 'قراءة',
          points: 5,
          isCompleted: done,
          kind: HomeworkTaskKind.reading,
        ),
      ],
    );

const _recitation = SubmitRecitationParams(
  localFilePath: '/tmp/r.m4a',
  studentId: 's1',
  studentName: 'أحمد',
  teacherId: 't1',
  halaqaId: 'h1',
  assignmentId: 'hw1',
  taskId: 'task1',
  versesRange: 'الملك 1-5',
  durationSeconds: 30,
);

class _Watch extends Fake implements WatchLatestHomeworkUseCase {
  final streams = <StreamController<_Feed>>[];
  StreamController<_Feed> get latest => streams.last;

  @override
  Stream<_Feed> call(StudentUidParams p) {
    final c = StreamController<_Feed>();
    streams.add(c);
    return c.stream;
  }
}

class _Toggle extends Fake implements ToggleHomeworkTaskUseCase {
  final calls = <String>[];
  Either<Failure, HomeworkEntity> result = Right(_hw(done: true));

  @override
  Future<Either<Failure, HomeworkEntity>> call(ToggleHomeworkTaskParams p) async {
    calls.add(p.taskId);
    return result;
  }
}

class _Complete extends Fake implements CompleteHomeworkUseCase {
  final calls = <String>[];
  Completer<void>? gate;
  Either<Failure, int> result = const Right(5);

  @override
  Future<Either<Failure, int>> call(String homeworkId) async {
    calls.add(homeworkId);
    await gate?.future;
    return result;
  }
}

class _Recite extends Fake implements SubmitHomeworkRecitationUseCase {
  final calls = <SubmitRecitationParams>[];
  Completer<void>? gate;
  Either<Failure, HomeworkEntity> result = Right(_hw(done: true));

  @override
  Future<Either<Failure, HomeworkEntity>> call(SubmitRecitationParams p) async {
    calls.add(p);
    await gate?.future;
    return result;
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Watch watch;
  late _Toggle toggle;
  late _Complete complete;
  late _Recite recite;
  late HomeworkBloc bloc;

  setUp(() {
    watch = _Watch();
    toggle = _Toggle();
    complete = _Complete();
    recite = _Recite();
    bloc = HomeworkBloc(
      watchLatestHomework: watch,
      toggleHomeworkTask: toggle,
      completeHomework: complete,
      submitHomeworkRecitation: recite,
    );
  });

  tearDown(() => bloc.close());

  Future<void> loadWith(HomeworkEntity? hw) async {
    bloc.add(const LoadHomeworkEvent('s1'));
    await _settle();
    watch.latest.add(Right(hw));
    await _settle();
  }

  test('initial state is idle', () {
    expect(bloc.state, const HomeworkState());
  });

  group('load', () {
    test('loading then loaded', () async {
      bloc.add(const LoadHomeworkEvent('s1'));
      await _settle();
      expect(bloc.state.status, SectionStatus.loading);
      expect(bloc.state.studentId, 's1');

      watch.latest.add(Right(_hw()));
      await _settle();
      expect(bloc.state.status, SectionStatus.loaded);
      expect(bloc.state.homework!.id, 'hw1');
    });

    test('no homework clears a previously shown one', () async {
      await loadWith(_hw());
      watch.latest.add(const Right(null));
      await _settle();

      expect(bloc.state.status, SectionStatus.loaded);
      expect(bloc.state.homework, isNull);
    });

    test('stream failure, then retry recovers', () async {
      bloc.add(const LoadHomeworkEvent('s1'));
      await _settle();
      watch.latest.add(const Left(ServerFailure('تعذر')));
      await _settle();
      expect(bloc.state.status, SectionStatus.error);
      expect(bloc.state.errorMessage, 'تعذر');

      await loadWith(_hw());
      expect(bloc.state.status, SectionStatus.loaded);
      expect(watch.streams.first.hasListener, isFalse);
    });
  });

  group('toggle task', () {
    test('updates the homework', () async {
      await loadWith(_hw());
      bloc.add(const ToggleTaskEvent('task1'));
      await _settle();

      expect(toggle.calls, ['task1']);
      expect(bloc.state.homework!.allCompleted, isTrue);
    });

    test('ignored once submitted', () async {
      await loadWith(_hw(done: true, submitted: true));
      bloc.add(const ToggleTaskEvent('task1'));
      await _settle();
      expect(toggle.calls, isEmpty);
    });

    test('failure surfaces a message', () async {
      toggle.result = const Left(ServerFailure('غير متاح'));
      await loadWith(_hw());
      bloc.add(const ToggleTaskEvent('task1'));
      await _settle();
      expect(bloc.state.errorMessage, 'غير متاح');
    });
  });

  group('finish homework', () {
    test('success locks the homework and reports earned points', () async {
      await loadWith(_hw(done: true));
      bloc.add(const FinishHomeworkEvent());
      await _settle();

      expect(complete.calls, ['hw1']);
      expect(bloc.state.submissionStatus, SubmissionStatus.success);
      expect(bloc.state.lastEarnedPoints, 5);
      expect(bloc.state.homework!.isSubmitted, isTrue);
    });

    test('not allowed until every task is done', () async {
      await loadWith(_hw());
      bloc.add(const FinishHomeworkEvent());
      await _settle();
      expect(complete.calls, isEmpty);
    });

    test('a second tap while submitting is dropped', () async {
      complete.gate = Completer<void>();
      await loadWith(_hw(done: true));

      bloc.add(const FinishHomeworkEvent());
      await _settle();
      bloc.add(const FinishHomeworkEvent());
      await _settle();
      complete.gate!.complete();
      await _settle();

      expect(complete.calls, hasLength(1));
    });

    test('failure keeps the homework open for retry', () async {
      complete.result = const Left(ServerFailure('انتهى الموعد'));
      await loadWith(_hw(done: true));
      bloc.add(const FinishHomeworkEvent());
      await _settle();

      expect(bloc.state.submissionStatus, SubmissionStatus.error);
      expect(bloc.state.errorMessage, 'انتهى الموعد');
      expect(bloc.state.homework!.isSubmitted, isFalse);

      complete.result = const Right(5);
      bloc.add(const FinishHomeworkEvent());
      await _settle();
      expect(bloc.state.submissionStatus, SubmissionStatus.success);
    });
  });

  group('recitation upload', () {
    test('success replaces the homework', () async {
      await loadWith(_hw());
      bloc.add(const SubmitRecitationEvent(_recitation));
      await _settle();

      expect(recite.calls.single.taskId, 'task1');
      expect(bloc.state.recitationUploadStatus, SubmissionStatus.success);
      expect(bloc.state.homework!.allCompleted, isTrue);
    });

    test('a second upload while one is in flight is dropped', () async {
      recite.gate = Completer<void>();
      bloc
        ..add(const SubmitRecitationEvent(_recitation))
        ..add(const SubmitRecitationEvent(_recitation));
      await _settle();
      recite.gate!.complete();
      await _settle();

      expect(recite.calls, hasLength(1));
    });

    test('failure is shown and cleared by ClearHomeworkMessage', () async {
      recite.result = const Left(ServerFailure('فشل الرفع'));
      bloc.add(const SubmitRecitationEvent(_recitation));
      await _settle();
      expect(bloc.state.recitationUploadStatus, SubmissionStatus.error);
      expect(bloc.state.recitationError, 'فشل الرفع');

      bloc.add(const ClearHomeworkMessageEvent());
      await _settle();
      expect(bloc.state.recitationError, isNull);
      expect(bloc.state.submissionStatus, SubmissionStatus.idle);
    });
  });
}
