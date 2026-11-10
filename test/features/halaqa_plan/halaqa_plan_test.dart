import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/halaqa_plan/domain/entities/halaqa_plan.dart';
import 'package:rafiq_academy/features/halaqa_plan/domain/repositories/halaqa_plan_repository.dart';
import 'package:rafiq_academy/features/halaqa_plan/domain/usecases/get_student_halaqa_plan_usecase.dart';
import 'package:rafiq_academy/features/halaqa_plan/presentation/bloc/halaqa_plan_bloc.dart';
import 'package:rafiq_academy/features/halaqa_plan/presentation/pages/student_halaqa_plan_page.dart';
import 'package:rafiq_academy/shared/domain/assignment_entity.dart';

AssignmentEntity _a(
  String id,
  int day, {
  String newRange = '',
  String review = '',
  bool done = false,
  String halaqaId = 'h1',
}) => AssignmentEntity(
  id: id,
  studentId: 's1',
  assignedBy: 't1',
  halaqaId: halaqaId,
  newMemorizationRange: newRange,
  reviewRange: review,
  dueDate: DateTime(2026, 9, day),
  isSubmitted: done,
);

class _FakeRepo implements HalaqaPlanRepository {
  Either<Failure, HalaqaPlan> result;
  _FakeRepo(this.result);

  @override
  Future<Either<Failure, HalaqaPlan>> getStudentPlan({
    required String studentId,
    String? halaqaId,
  }) async => result;
}

void main() {
  group('HalaqaPlan.fromAssignments', () {
    final plan = HalaqaPlan.fromAssignments([
      _a('a3', 3, newRange: 'البقرة 11-20', review: 'الفاتحة'),
      _a('a1', 1, newRange: 'البقرة 1-5', done: true),
      _a('a2', 2, newRange: 'البقرة 6-10', review: 'الناس', done: true),
      _a('x', 4, newRange: 'آل عمران 1-5', halaqaId: 'other'),
    ], halaqaId: 'h1');

    test('orders by due date and skips other halaqat', () {
      expect(plan.newMemorization.entries.map((e) => e.assignmentId), [
        'a1',
        'a2',
        'a3',
      ]);
    });

    test('start / reached / next follow assignment status', () {
      final t = plan.newMemorization;
      expect(t.startPoint?.portion, 'البقرة 1-5');
      expect(t.reachedPoint?.portion, 'البقرة 6-10');
      expect(t.nextPortion?.portion, 'البقرة 11-20');
      expect(t.completed.map((e) => e.portion), ['البقرة 6-10', 'البقرة 1-5']);
    });

    test('review track keeps only assignments with a review range', () {
      final r = plan.review;
      expect(r.entries.map((e) => e.portion), ['الناس', 'الفاتحة']);
      expect(r.reachedPoint?.portion, 'الناس');
      expect(r.nextPortion?.portion, 'الفاتحة');
    });

    test('no assignments yields an empty plan', () {
      expect(HalaqaPlan.fromAssignments(const []).isEmpty, isTrue);
    });
  });

  group('HalaqaPlanBloc', () {
    test('rejects a missing student id without reading', () async {
      final bloc = HalaqaPlanBloc(
        getPlan: GetStudentHalaqaPlanUseCase(
          _FakeRepo(Right(HalaqaPlan.fromAssignments(const []))),
        ),
      );
      bloc.add(const LoadStudentHalaqaPlanEvent(studentId: ' '));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, SectionStatus.error);
      await bloc.close();
    });

    test('loads the plan', () async {
      final plan = HalaqaPlan.fromAssignments([_a('a1', 1, newRange: 'x')]);
      final bloc = HalaqaPlanBloc(
        getPlan: GetStudentHalaqaPlanUseCase(_FakeRepo(Right(plan))),
      );
      bloc.add(const LoadStudentHalaqaPlanEvent(studentId: 's1'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, SectionStatus.loaded);
      expect(bloc.state.plan, plan);
      await bloc.close();
    });
  });

  group('StudentHalaqaPlanView', () {
    Future<void> pump(WidgetTester tester, HalaqaPlanState state) async {
      final bloc = HalaqaPlanBloc(
        getPlan: GetStudentHalaqaPlanUseCase(
          _FakeRepo(Right(HalaqaPlan.fromAssignments(const []))),
        ),
      )..emit(state);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: StudentHalaqaPlanView(onRetry: () {}),
          ),
        ),
      );
    }

    testWidgets('renders both tracks with the four Arabic sections', (
      tester,
    ) async {
      await pump(
        tester,
        HalaqaPlanState(
          status: SectionStatus.loaded,
          plan: HalaqaPlan.fromAssignments([
            _a('a1', 1, newRange: 'البقرة 1-5', review: 'الناس', done: true),
            _a('a2', 2, newRange: 'البقرة 6-10', review: 'الفلق'),
          ]),
        ),
      );
      expect(find.text('الجديد'), findsOneWidget);
      expect(find.text('المراجعة'), findsOneWidget);
      for (final title in StudentHalaqaPlanView.sectionTitles.take(3)) {
        expect(find.text(title), findsNWidgets(2));
      }
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('empty plan shows a truthful empty state', (tester) async {
      await pump(
        tester,
        HalaqaPlanState(
          status: SectionStatus.loaded,
          plan: HalaqaPlan.fromAssignments(const []),
        ),
      );
      expect(find.text('لا توجد خطة مسجّلة بعد'), findsOneWidget);
    });
  });
}
