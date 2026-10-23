import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/awards/domain/award_submission_id.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/achievement_issue_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/admit_student_to_halaqa_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_absence_requests_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_halaqat_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervisor_day_board_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/issue_achievement_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/payment_review_usecases.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/register_new_student_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/submit_supervisor_report_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/transfer_student_between_halaqat_usecase.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'package:rafiq_academy/features/supervisor/presentation/widgets/issue_achievement_dialog.dart';

class _Unused1 extends Fake implements GetSupervisedHalaqatUseCase {}

class _Unused2 extends Fake implements GetSupervisorDayBoardUseCase {}

class _Unused3 extends Fake implements GetSupervisedAbsenceRequestsUseCase {}

class _Unused4 extends Fake implements IssueAchievementUseCase {}

class _Unused5 extends Fake implements SubmitSupervisorReportUseCase {}

class _Unused6 extends Fake implements RegisterNewStudentUseCase {}

class _Unused7 extends Fake implements AdmitStudentToHalaqaUseCase {}

class _Unused8 extends Fake implements TransferStudentBetweenHalaqatUseCase {}

class _Unused9 extends Fake implements GetSupervisedPaymentsUseCase {}

class _Unused10 extends Fake implements ReviewPaymentProofUseCase {}

SupervisorBloc _bloc() => SupervisorBloc(
  getSupervisedHalaqat: _Unused1(),
  getSupervisorDayBoard: _Unused2(),
  getSupervisedAbsenceRequests: _Unused3(),
  issueAchievement: _Unused4(),
  submitSupervisorReport: _Unused5(),
  admitStudentToHalaqa: _Unused7(),
  transferStudentBetweenHalaqat: _Unused8(),
  getSupervisedPayments: _Unused9(),
  reviewPaymentProof: _Unused10(),
  registerNewStudent: _Unused6(),
);

Future<List<AchievementIssueEntity>> _pump(
  WidgetTester tester, {
  required List<String> studentIds,
  Future<Map<String, String>> Function(List<String>)? loadNames,
  List<List<String>>? requested,
}) async {
  final submitted = <AchievementIssueEntity>[];
  final bloc = _bloc();
  // Awaiting close() of a bloc with a droppable() handler never completes
  // under the widget tester's fake async.
  addTearDown(() => unawaited(bloc.close()));
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: BlocProvider<SupervisorBloc>.value(
          value: bloc,
          child: Scaffold(
            body: IssueAchievementDialog(
              studentIds: studentIds,
              halaqaId: 'h1',
              issuedBy: 'sup1',
              achievementTypes: const ['star'],
              onSubmit: submitted.add,
              loadStudentNames: loadNames == null
                  ? null
                  : (ids) {
                      requested?.add(ids);
                      return loadNames(ids);
                    },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return submitted;
}

void main() {
  testWidgets('student picker shows names, not raw ids', (tester) async {
    final requested = <List<String>>[];
    await _pump(
      tester,
      studentIds: const ['uid_a', 'uid_b'],
      loadNames: (_) async => const {'uid_a': 'أحمد علي', 'uid_b': 'سعد'},
      requested: requested,
    );

    expect(requested, [
      ['uid_a', 'uid_b'],
    ]);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('أحمد علي'), findsWidgets);
    expect(find.text('سعد'), findsWidgets);
    expect(find.text('uid_a'), findsNothing);
    expect(find.text('uid_b'), findsNothing);
  });

  testWidgets('unresolved names fall back to the id', (tester) async {
    await _pump(
      tester,
      studentIds: const ['uid_a'],
      loadNames: (_) async => const {},
    );

    expect(find.text('uid_a'), findsOneWidget);
  });

  testWidgets('lookup failure keeps the dialog usable', (tester) async {
    await _pump(
      tester,
      studentIds: const ['uid_a'],
      loadNames: (_) async => throw Exception('denied'),
    );

    expect(find.text('uid_a'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submission still carries the student id', (tester) async {
    final submitted = await _pump(
      tester,
      studentIds: const ['uid_a'],
      loadNames: (_) async => const {'uid_a': 'أحمد علي'},
    );

    expect(find.text('أحمد علي'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'حفظ جزء عم');
    await tester.pump();
    await tester.tap(find.text('منح'));
    await tester.pump();

    expect(submitted, hasLength(1));
    expect(submitted.single.studentId, 'uid_a');
    expect(submitted.single.halaqaId, 'h1');
    expect(submitted.single.issuedBy, 'sup1');
    expect(AwardSubmissionId.isValid(submitted.single.achievementId), isTrue);
  });
}
