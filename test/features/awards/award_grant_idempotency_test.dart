import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/data/admin_grant_reward_payload_codec.dart';
import 'package:rafiq_academy/features/admin/data/datasources/admin_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/admin/domain/admin_grant_reward_params.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_directory_entity.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_halaqa_roster_entity.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/approve_new_student_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/communication_settings_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/ensure_admin_internal_chat_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_academy_stats_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_academy_student_roster_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_admin_directory_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_all_teachers_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_complaints_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_financial_summary_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_payments_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_teacher_activity_log_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/grant_admin_reward_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/registration_request_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/respond_to_complaint_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/send_broadcast_notification_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/toggle_account_status_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/update_complaint_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/update_teacher_performance_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/update_teacher_quota_usecase.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_event.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_misc_pages.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/awards/data/award_grant_errors.dart';
import 'package:rafiq_academy/features/awards/data/datasources/award_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/awards/data/granted_award_payload_codec.dart';
import 'package:rafiq_academy/features/awards/data/models/granted_award_model.dart';
import 'package:rafiq_academy/features/awards/data/shared_preferences_unresolved_award_store.dart';
import 'package:rafiq_academy/features/awards/domain/award_submission_id.dart';
import 'package:rafiq_academy/features/awards/domain/unresolved_award_store.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/awards/domain/repositories/awards_repository.dart';
import 'package:rafiq_academy/features/awards/domain/usecases/awards_usecases.dart';
import 'package:rafiq_academy/features/awards/presentation/bloc/awards_bloc.dart';
import 'package:rafiq_academy/features/awards/presentation/bloc/awards_event.dart';
import 'package:rafiq_academy/features/awards/presentation/pages/awards_page.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:rafiq_academy/features/supervisor/data/achievement_issue_payload_codec.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/achievement_issue_entity.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_callables.dart';

const _awardId = 'awardSubmission01';

GrantedAwardModel _model({String id = _awardId}) => GrantedAwardModel(
  id: id,
  studentId: 's1',
  studentName: 'أحمد',
  type: AwardType.performanceStars,
  title: 'نجم الحلقة',
  grantedBy: 'teacher1',
  halaqaId: 'h1',
  grantedAt: DateTime(2026, 9, 1),
  recipientStudentIds: const ['s1'],
);

AdminGrantRewardParams _params({String awardId = _awardId}) =>
    AdminGrantRewardParams(
      awardId: awardId,
      targetKind: AdminRewardTargetKind.student,
      targetId: 's1',
      type: 'star',
      title: 'تميز',
      grantedBy: 'admin1',
      halaqaId: 'h1',
      recipientStudentIds: const ['s1'],
    );

class _MemoryStore implements UnresolvedAwardStore {
  final records = <String, String>{};
  bool failReads = false;
  bool failWrites = false;
  int writes = 0;

  /// When set, each write waits for it and then applies [failWrites].
  Completer<void>? writeGate;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('storage unavailable');
    return records[key];
  }

  @override
  Future<void> write(String key, String record) async {
    writes++;
    final gate = writeGate;
    if (gate != null) await gate.future;
    if (failWrites) throw StateError('disk full');
    records[key] = record;
  }

  @override
  Future<void> remove(String key) async => records.remove(key);
}

/// Mirrors SharedPreferences: the cache changes first, then the platform
/// write reports failure.
class _FailingPrefs extends Fake implements SharedPreferences {
  _FailingPrefs(this.values);

  final Map<String, String> values;

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return false;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

class _GatedStore extends _MemoryStore {
  final gate = Completer<void>();

  @override
  Future<String?> read(String key) async {
    await gate.future;
    return super.read(key);
  }
}

const _teacherKey = 'awards.unresolved.grantAward.teacher.teacher1';

Future<void> _useDurableStore() async {
  SharedPreferences.setMockInitialValues({});
  AwardSubmissionId.clearUnresolvedRegistry();
  await sl.reset();
  sl.registerLazySingleton<UnresolvedAwardStore>(
    SharedPreferencesUnresolvedAwardStore.new,
  );
}

Future<void> _resetDurableStore() {
  AwardSubmissionId.clearUnresolvedRegistry();
  return sl.reset();
}

/// Leaves an unresolved teacher grant behind, as an earlier sheet would.
Future<GrantedAwardEntity> _seedTeacherUnresolved({
  String? image,
  required bool restart,
}) async {
  final ids = AwardSubmissionId<GrantedAwardEntity>.durable(
    scope: const AwardOperationScope(
      operation: AwardOperationScope.grantAward,
      form: 'teacher',
      uid: 'teacher1',
    ),
    store: sl<UnresolvedAwardStore>(),
    codec: const GrantedAwardPayloadCodec(),
  );
  await ids.restore();
  final prepared = await ids.prepare(['seed'], (id) => GrantedAwardEntity(
    id: id,
    studentId: 's1',
    studentName: 'أحمد',
    type: AwardType.performance,
    title: 'نجم الحلقة',
    localImagePath: image,
    grantedBy: 'teacher1',
    halaqaId: 'h1',
    halaqaIds: const ['h1'],
    grantedAt: DateTime(2026, 9, 1),
    recipientStudentIds: const ['s1'],
    recipientCount: 1,
  ));
  final award = prepared.payload!;
  await ids.markUnresolved();
  if (restart) AwardSubmissionId.clearUnresolvedRegistry();
  return award;
}

class _AwardsRepo extends Fake implements AwardsRepository {
  final grants = <GrantedAwardEntity>[];
  final results = <Completer<Either<Failure, Unit>>>[];

  @override
  Future<Either<Failure, Unit>> grantAward(GrantedAwardEntity award) {
    grants.add(award);
    final c = Completer<Either<Failure, Unit>>();
    results.add(c);
    return c.future;
  }

  @override
  Future<Either<Failure, AwardsStatsEntity>> getAwardsStats(
    String halaqaId,
  ) async => const Left(ServerFailure('stats unavailable'));

  @override
  Future<Either<Failure, List<GrantedAwardEntity>>> getGrantedAwards(
    String halaqaId,
  ) async => const Right([]);
}

AwardsBloc _awardsBloc(AwardsRepository r) => AwardsBloc(
  getAwardsStats: GetAwardsStatsUseCase(r),
  getGrantedAwards: GetGrantedAwardsUseCase(r),
  grantAward: GrantAwardUseCase(r),
  generateCertificatePdf: GenerateCertificatePdfUseCase(r),
);

AdminHalaqaRosterEntity _rosterHalaqa(
  String id,
  String name,
  List<String> studentIds,
) => AdminHalaqaRosterEntity(
  id: id,
  name: name,
  teacherId: 'teacher1',
  supervisorId: 'sup1',
  status: 'active',
  students: [
    for (final sid in studentIds)
      AdminRosterStudentEntity(
        uid: sid,
        name: sid == 's1' ? 'أحمد' : 'طالب $sid',
        isActive: true,
      ),
  ],
);

class _RewardRepo extends Fake implements AdminRepository {
  final grants = <AdminGrantRewardParams>[];
  final results = <Completer<Either<Failure, Unit>>>[];

  /// What the next roster load returns; tests change it between loads.
  List<AdminHalaqaRosterEntity> roster = [
    _rosterHalaqa('h1', 'حلقة الفجر', ['s1']),
  ];
  List<AdminHalaqaSummaryEntity> halaqat = const [];

  /// Runs synchronously when a grant reaches the repository.
  void Function(AdminGrantRewardParams params)? onGrant;

  @override
  Future<Either<Failure, Unit>> grantReward(AdminGrantRewardParams params) {
    onGrant?.call(params);
    grants.add(params);
    final c = Completer<Either<Failure, Unit>>();
    results.add(c);
    return c.future;
  }

  @override
  Future<Either<Failure, List<AdminHalaqaRosterEntity>>>
  getAcademyStudentRoster() async => Right(roster);

  @override
  Future<Either<Failure, List<AdminHalaqaSummaryEntity>>>
  getAllHalaqat() async => Right(halaqat);

  @override
  Future<Either<Failure, List<AdminStaffSummaryEntity>>>
  getAllSupervisors() async => const Right([]);
}

AdminBloc _adminBloc(AdminRepository r) => AdminBloc(
  getAcademyStats: GetAcademyStatsUseCase(r),
  getFinancialSummary: GetFinancialSummaryUseCase(r),
  getPayments: GetPaymentsUseCase(r),
  getComplaints: GetComplaintsUseCase(r),
  approveNewStudent: ApproveNewStudentUseCase(r),
  toggleAccountStatus: ToggleAccountStatusUseCase(r),
  respondToComplaint: RespondToComplaintUseCase(r),
  sendBroadcastNotification: SendBroadcastNotificationUseCase(r),
  getAllTeachers: GetAllTeachersUseCase(r),
  updateTeacherPerformance: UpdateTeacherPerformanceUseCase(r),
  updateTeacherQuota: UpdateTeacherQuotaUseCase(r),
  getTeacherActivityLog: GetTeacherActivityLogUseCase(r),
  getAcademyStudentRoster: GetAcademyStudentRosterUseCase(r),
  getRegistrationRequests: GetRegistrationRequestsUseCase(r),
  rejectRegistrationRequest: RejectRegistrationRequestUseCase(r),
  approveRegistrationRequest: ApproveRegistrationRequestUseCase(r),
  getAllHalaqat: GetAllHalaqatUseCase(r),
  getAllSupervisors: GetAllSupervisorsUseCase(r),
  updateComplaint: UpdateComplaintUseCase(r),
  getCommunicationSettings: GetCommunicationSettingsUseCase(r),
  saveCommunicationSettings: SaveCommunicationSettingsUseCase(r),
  grantAdminReward: GrantAdminRewardUseCase(r),
  ensureAdminInternalChat: EnsureAdminInternalChatUseCase(r),
);

/// The sheet only reads these blocs' state.
class _TeacherBlocStub extends Cubit<TeacherState> implements TeacherBloc {
  _TeacherBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _teacherState = TeacherState(
  halaqat: [
    HalaqaEntity(
      id: 'h1',
      name: 'حلقة الفجر',
      teacherId: 'teacher1',
      supervisorId: 'sup1',
      studentIds: ['s1'],
      schedule: [],
      status: 'active',
    ),
  ],
  studentsHalaqaId: 'h1',
  students: [HalaqaStudentSummaryEntity(uid: 's1', name: 'أحمد')],
);

final _teacher = UserEntity(
  uid: 'teacher1',
  name: 'معلم',
  role: 'teacher',
  isActive: true,
  createdAt: DateTime(2026),
);

final _admin = UserEntity(
  uid: 'admin1',
  name: 'مدير',
  role: 'admin',
  isActive: true,
  createdAt: DateTime(2026),
);

final _submit = find.byKey(const Key('create-award-submit'));
final _error = find.byKey(const Key('create-award-error'));

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await _settle(tester);
}

Future<void> _pumpHost(WidgetTester tester, AwardsBloc bloc) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final teacher = _TeacherBlocStub(_teacherState);
  final auth = _AuthBlocStub(AuthAuthenticated(_teacher));
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<TeacherBloc>.value(value: teacher),
        BlocProvider<AuthBloc>.value(value: auth),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => BlocProvider.value(
                  value: bloc,
                  child: const CreateAwardSheet(
                    halaqaId: 'h1',
                    preset: AwardType.performanceStars,
                    preselectedStudentId: 's1',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Bounded pumps: the submit spinner keeps scheduling frames, so
/// pumpAndSettle would never return while a grant is in flight.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapSubmit(WidgetTester tester, {bool twice = false}) async {
  await tester.ensureVisible(_submit);
  await tester.tap(_submit);
  if (twice) await tester.tap(_submit, warnIfMissed: false);
  await tester.pump();
}

Future<void> _close(WidgetTester tester, Bloc<Object?, Object?> bloc) async {
  unawaited(bloc.close());
  await tester.pump();
}

void main() {
  group('AwardSubmissionId', () {
    test('retries of the same payload share one server-valid id', () {
      final ids = AwardSubmissionId(random: Random(1));
      final first = ids.idFor(['star', 'نجم', 's1']);
      expect(AwardSubmissionId.isValid(first), isTrue);
      expect(ids.idFor(['star', 'نجم', 's1']), first);
    });

    test('a changed payload is a new submission', () {
      final ids = AwardSubmissionId(random: Random(1));
      final first = ids.idFor(['star', 'نجم', 's1']);
      expect(ids.idFor(['star', 'نجم', 's2']), isNot(first));
    });

    test('after a confirmed grant an identical payload gets a new id', () {
      final ids = AwardSubmissionId(random: Random(1));
      final first = ids.idFor(['star', 'نجم', 's1']);
      ids.complete();
      expect(ids.idFor(['star', 'نجم', 's1']), isNot(first));
    });

    test('empty or malformed ids are rejected', () {
      expect(AwardSubmissionId.isValid(''), isFalse);
      expect(AwardSubmissionId.isValid('short'), isFalse);
      expect(AwardSubmissionId.isValid('has space in it'), isFalse);
    });

    test('an unresolved request pins its id; a changed payload is refused', () {
      final ids = AwardSubmissionId(random: Random(1));
      final first = ids.idFor(['star', 'نجم', 's1']);
      ids
        ..submitted('payload-1')
        ..markUnresolved();
      expect(ids.isUnresolved, isTrue);
      expect(ids.unresolved!.id, first);
      expect(ids.unresolved!.payload, 'payload-1');
      expect(() => ids.idFor(['star', 'نجم معدل', 's1']), throwsStateError);
      expect(ids.idFor(['star', 'نجم', 's1']), first);
    });

    test(
      'only a confirmed success or an explicit abandon releases the pin',
      () {
        for (final release in <void Function(AwardSubmissionId)>[
          (ids) => ids.complete(),
          (ids) => ids.abandon(),
        ]) {
          final ids = AwardSubmissionId(random: Random(1));
          final first = ids.idFor(['star', 'نجم', 's1']);
          ids
            ..submitted('payload')
            ..markUnresolved();
          release(ids);
          expect(ids.isUnresolved, isFalse);
          expect(ids.idFor(['star', 'نجم معدل', 's1']), isNot(first));
        }
      },
    );

    test('marking unresolved without a submitted request does nothing', () {
      final ids = AwardSubmissionId(random: Random(1))..markUnresolved();
      expect(ids.isUnresolved, isFalse);
    });

  });

  group('durable unresolved award records', () {
    late _MemoryStore store;

    setUp(() {
      store = _MemoryStore();
      AwardSubmissionId.clearUnresolvedRegistry();
    });
    tearDown(AwardSubmissionId.clearUnresolvedRegistry);

    AwardSubmissionId<AdminGrantRewardParams> admin({
      String uid = 'admin1',
      String form = 'admin',
      String operation = AwardOperationScope.grantAward,
      UnresolvedAwardStore? using,
    }) => AwardSubmissionId.durable(
      scope: AwardOperationScope(operation: operation, form: form, uid: uid),
      store: using ?? store,
      codec: const AdminGrantRewardPayloadCodec(),
      random: Random(7),
    );

    const key = 'awards.unresolved.grantAward.admin.admin1';

    AdminGrantRewardParams params(String id, String title) =>
        AdminGrantRewardParams(
          awardId: id,
          targetKind: AdminRewardTargetKind.student,
          targetId: 's1',
          type: 'star',
          title: title,
          description: 'سبب',
          grantedBy: 'admin1',
          halaqaId: 'h1',
          studentName: 'أحمد',
          recipientStudentIds: const ['s1'],
        );

    Future<AdminGrantRewardParams> pinOne(
      AwardSubmissionId<AdminGrantRewardParams> ids, {
      bool unresolved = true,
    }) async {
      await ids.restore();
      final prepared = await ids.prepare(
        ['student', 's1', 'star', 'تميز'],
        (id) => params(id, 'تميز'),
      );
      expect(prepared.status, AwardPrepareStatus.ready);
      if (unresolved) await ids.markUnresolved();
      return prepared.payload!;
    }

    test('an unresolved request survives a restart with the same id and the '
        'exact payload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = SharedPreferencesUnresolvedAwardStore();
      final sent = await pinOne(admin(using: prefs));

      AwardSubmissionId.clearUnresolvedRegistry();
      final restored = admin(using: prefs);
      expect(restored.blocksNewSubmission, isTrue);
      await restored.restore();
      expect(restored.unresolved!.id, sent.awardId);
      expect(restored.unresolved!.payload, sent);
      expect(identical(restored.unresolved!.payload, sent), isFalse);
      expect(restored.canRetry, isTrue);
      expect(restored.blocksNewSubmission, isTrue);
      expect(() => restored.idFor(['student', 's1', 'star', 'آخر']),
          throwsStateError);
    });

    test('the record is written before sending, so a crash mid-flight '
        'restores it as unresolved', () async {
      final sent = await pinOne(admin(), unresolved: false);
      expect(await store.read(key), contains('"status":"inFlight"'));

      AwardSubmissionId.clearUnresolvedRegistry();
      final restored = admin();
      await restored.restore();
      expect(restored.unresolved!.payload, sent);
      expect(restored.canRetry, isTrue);
    });

    test('a confirmed success clears the record', () async {
      final ids = admin();
      await pinOne(ids);
      await ids.complete();
      expect(await store.read(key), isNull);

      AwardSubmissionId.clearUnresolvedRegistry();
      final next = admin();
      await next.restore();
      expect(next.blocksNewSubmission, isFalse);
    });

    test('a confirmed abandon clears the record', () async {
      final ids = admin();
      final sent = await pinOne(ids);
      await ids.abandon();
      expect(await store.read(key), isNull);
      expect(ids.blocksNewSubmission, isFalse);
      expect(ids.idFor(['student', 's1', 'star', 'تميز']),
          isNot(sent.awardId));
    });

    test('a confirmed rejection clears an in-flight record but never a '
        'pinned one', () async {
      final inFlight = admin();
      await pinOne(inFlight, unresolved: false);
      await inFlight.confirmedFailure();
      expect(await store.read(key), isNull);

      final pinned = admin(uid: 'admin2');
      await pinOne(pinned);
      await pinned.confirmedFailure();
      expect(
        await store.read('awards.unresolved.grantAward.admin.admin2'),
        isNotNull,
      );
      expect(pinned.isUnresolved, isTrue);
    });

    test('corrupt, mismatched or unsupported records block new submissions '
        'until abandoned', () async {
      final valid = await pinOne(admin());
      final good = (await store.read(key))!;
      AwardSubmissionId.clearUnresolvedRegistry();
      final bad = <String>[
        'not json',
        '[]',
        good.replaceFirst('"v":1', '"v":2'),
        good.replaceFirst('"uid":"admin1"', '"uid":"admin9"'),
        good.replaceFirst('"form":"admin"', '"form":"teacher"'),
        good.replaceFirst('"status":"unresolved"', '"status":"done"'),
        good.replaceFirst('"title":"تميز"', '"title":7'),
        good.replaceFirst('"awardId":"${valid.awardId}"', '"awardId":"other"'),
        good.replaceFirst('"targetKind":"student"', '"targetKind":"class"'),
        // Saved before recipients were pinned: cannot be resent exactly.
        good.replaceFirst(',"recipientStudentIds":["s1"]', ''),
        good.replaceFirst('"recipientStudentIds":["s1"]',
            '"recipientStudentIds":[]'),
        good.replaceFirst('"halaqaId":"h1"', '"halaqaId":null'),
      ];
      for (final raw in bad) {
        await store.write(key, raw);
        final ids = admin();
        await ids.restore();
        expect(ids.recoveryProblem, AwardRecoveryProblem.unreadable,
            reason: raw);
        expect(ids.blocksNewSubmission, isTrue);
        expect(ids.canRetry, isFalse);
        expect(() => ids.idFor(['x']), throwsStateError);
        expect(await store.read(key), raw, reason: 'never silently dropped');

        await ids.abandon();
        expect(await store.read(key), isNull);
        expect(ids.blocksNewSubmission, isFalse);
      }
    });

    test('a store that cannot be read fails safe', () async {
      store.failReads = true;
      final ids = admin();
      await ids.restore();
      expect(ids.recoveryProblem, AwardRecoveryProblem.unreadable);
      expect(ids.blocksNewSubmission, isTrue);
    });

    test('records are scoped by account, form and operation', () async {
      await pinOne(admin());
      AwardSubmissionId.clearUnresolvedRegistry();
      for (final other in [
        admin(uid: 'admin2'),
        admin(form: 'teacher'),
        admin(operation: AwardOperationScope.issueAchievement),
      ]) {
        await other.restore();
        expect(other.blocksNewSubmission, isFalse);
      }
      final same = admin();
      await same.restore();
      expect(same.isUnresolved, isTrue);
    });

    test('no id is issued before the saved state is restored', () async {
      final ids = admin();
      expect(ids.blocksNewSubmission, isTrue);
      expect(() => ids.idFor(['x']), throwsStateError);
    });

    test('teacher records round-trip exactly and never save image paths',
        () async {
      AwardSubmissionId<GrantedAwardEntity> teacher() =>
          AwardSubmissionId.durable(
            scope: const AwardOperationScope(
              operation: AwardOperationScope.grantAward,
              form: 'teacher',
              uid: 'teacher1',
            ),
            store: store,
            codec: const GrantedAwardPayloadCodec(),
          );
      GrantedAwardEntity entity(String id, {String? image}) =>
          GrantedAwardEntity(
            id: id,
            studentId: 's1',
            studentName: 'أحمد',
            type: AwardType.performance,
            title: 'نجم الحلقة',
            description: 'تميز',
            localImagePath: image,
            grantedBy: 'teacher1',
            halaqaId: 'h1',
            halaqaName: 'حلقة الفجر',
            halaqaIds: const ['h1'],
            halaqaNames: const ['حلقة الفجر'],
            grantedAt: DateTime(2026, 9, 1, 10, 30),
            recipientStudentIds: const ['s1'],
            recipientCount: 1,
          );

      final plain = teacher();
      await plain.restore();
      final sent = (await plain.prepare(['plain'], entity)).payload!;
      await plain.markUnresolved();
      AwardSubmissionId.clearUnresolvedRegistry();
      final restoredPlain = teacher();
      await restoredPlain.restore();
      expect(restoredPlain.unresolved!.payload, sent);
      expect(restoredPlain.canRetry, isTrue);
      await restoredPlain.abandon();

      final withImage = teacher();
      await withImage.restore();
      final imaged = (await withImage.prepare(
        ['img'],
        (id) => entity(id, image: r'C:\pics\a.png'),
      )).payload!;
      await withImage.markUnresolved();
      final raw = (await store.read(
        'awards.unresolved.grantAward.teacher.teacher1',
      ))!;
      expect(raw, isNot(contains('a.png')));
      expect(raw, contains('"imageAttached":true'));

      final sameSession = teacher();
      await sameSession.restore();
      expect(identical(sameSession.unresolved!.payload, imaged), isTrue);
      expect(sameSession.canRetry, isTrue);

      AwardSubmissionId.clearUnresolvedRegistry();
      final afterRestart = teacher();
      await afterRestart.restore();
      expect(afterRestart.unresolved!.id, imaged.id);
      expect(
        afterRestart.recoveryProblem,
        AwardRecoveryProblem.imageNotRestorable,
      );
      expect(afterRestart.canRetry, isFalse);
      expect(afterRestart.blocksNewSubmission, isTrue);
    });

    test('supervisor records round-trip exactly', () async {
      AwardSubmissionId<AchievementIssueEntity> staff() =>
          AwardSubmissionId.durable(
            scope: const AwardOperationScope(
              operation: AwardOperationScope.issueAchievement,
              form: 'staff',
              uid: 'sup1',
            ),
            store: store,
            codec: const AchievementIssuePayloadCodec(),
          );
      final ids = staff();
      await ids.restore();
      final sent = (await ids.prepare(
        ['s1'],
        (id) => AchievementIssueEntity(
          achievementId: id,
          studentId: 's1',
          type: 'star',
          title: 'حفظ جزء عم',
          issuedBy: 'sup1',
          halaqaId: 'h1',
        ),
      )).payload!;
      await ids.markUnresolved();
      AwardSubmissionId.clearUnresolvedRegistry();
      final restored = staff();
      await restored.restore();
      expect(restored.unresolved!.payload, sent);
    });

    const fingerprint = ['student', 's1', 'star', 'تميز'];

    test('a failed initial save returns nothing to send; retrying the save '
        'reuses the id and yields exactly one payload', () async {
      final ids = admin();
      await ids.restore();
      store.failWrites = true;
      final failed = await ids.prepare(fingerprint, (id) => params(id, 'تميز'));
      expect(failed.status, AwardPrepareStatus.localSaveFailed);
      expect(failed.payload, isNull);
      expect(store.records, isEmpty);
      expect(ids.isPreparing, isFalse);
      expect(ids.isUnresolved, isFalse);
      expect(ids.blocksNewSubmission, isFalse);

      store.failWrites = false;
      final built = <String>[];
      final ready = await ids.prepare(fingerprint, (id) {
        built.add(id);
        return params(id, 'تميز');
      });
      expect(ready.status, AwardPrepareStatus.ready);
      expect(ready.payload!.awardId, built.single);
      expect(await store.read(key), contains(built.single));
      expect(
        await ids.prepare(fingerprint, (id) => params(id, 'تميز')),
        isA<AwardPreparation<AdminGrantRewardParams>>().having(
          (p) => p.status,
          'status',
          AwardPrepareStatus.busy,
        ),
        reason: 'one ready payload per operation until its outcome',
      );
    });

    test('the SharedPreferences store reports a false write as a failure '
        'and keeps the previous value readable', () async {
      final prefs = _FailingPrefs({key: 'previous'});
      final shared = SharedPreferencesUnresolvedAwardStore(
        preferences: () async => prefs,
      );
      await expectLater(shared.write(key, 'next'), throwsStateError);
      expect(await shared.read(key), 'previous');

      prefs.values.remove(key);
      await expectLater(shared.write(key, 'next'), throwsStateError);
      expect(await shared.read(key), isNull);

      final ids = admin(using: shared);
      await ids.restore();
      final failed = await ids.prepare(fingerprint, (id) => params(id, 'تميز'));
      expect(failed.status, AwardPrepareStatus.localSaveFailed);
      expect(failed.payload, isNull);
      expect(await shared.read(key), isNull);
    });

    test('concurrent submissions during a delayed save create one operation; '
        'the pinned payload cannot be replaced', () async {
      final ids = admin();
      await ids.restore();
      store.writeGate = Completer<void>();
      final builds = <String>[];
      final first = ids.prepare(fingerprint, (id) {
        builds.add(id);
        return params(id, 'تميز');
      });
      expect(ids.isPreparing, isTrue);
      expect(ids.blocksNewSubmission, isTrue);

      final second = await ids.prepare(['student', 's1', 'star', 'آخر'], (id) {
        builds.add(id);
        return params(id, 'آخر');
      });
      final other = admin();
      await other.restore();
      final third = await other.prepare(['student', 's1', 'star', 'ثالث'], (
        id,
      ) {
        builds.add(id);
        return params(id, 'ثالث');
      });
      expect(second.status, AwardPrepareStatus.busy);
      expect(third.status, AwardPrepareStatus.busy);
      expect(store.writes, 1);

      store.writeGate!.complete();
      final ready = await first;
      expect(ready.status, AwardPrepareStatus.ready);
      expect(builds, [ready.payload!.awardId]);
      final saved = (await store.read(key))!;
      expect(saved, contains(ready.payload!.awardId));
      expect(saved, contains('"title":"تميز"'));
      expect(saved, isNot(contains('آخر')));
      expect(saved, isNot(contains('ثالث')));

      final afterwards = await other.prepare(
        ['student', 's1', 'star', 'ثالث'],
        (id) => params(id, 'ثالث'),
      );
      expect(afterwards.status, AwardPrepareStatus.blocked);
      expect(store.writes, 1);
      expect(await store.read(key), saved);
    });

    test('a delayed save that then fails releases the guard and leaves '
        'nothing to resolve', () async {
      final ids = admin();
      await ids.restore();
      store
        ..writeGate = Completer<void>()
        ..failWrites = true;
      final pending = ids.prepare(fingerprint, (id) => params(id, 'تميز'));
      expect(ids.isPreparing, isTrue);
      store.writeGate!.complete();
      final failed = await pending;
      expect(failed.status, AwardPrepareStatus.localSaveFailed);
      expect(ids.isPreparing, isFalse);
      expect(ids.blocksNewSubmission, isFalse);
      expect(ids.isUnresolved, isFalse);
      await ids.markUnresolved();
      expect(ids.isUnresolved, isFalse, reason: 'nothing was sent');
      expect(store.records, isEmpty);

      store
        ..writeGate = null
        ..failWrites = false;
      final ready = await ids.prepare(fingerprint, (id) => params(id, 'تميز'));
      expect(ready.status, AwardPrepareStatus.ready);
    });

    test('an unconfirmed outcome keeps the original id even when updating '
        'the record fails', () async {
      final ids = admin();
      final sent = await pinOne(ids, unresolved: false);
      store.failWrites = true;
      await ids.markUnresolved();
      expect(ids.unresolved!.id, sent.awardId);
      expect(ids.unresolved!.payload, sent);
      final saved = (await store.read(key))!;
      expect(saved, contains(sent.awardId));
      expect(saved, contains('"status":"inFlight"'));

      AwardSubmissionId.clearUnresolvedRegistry();
      final restored = admin();
      await restored.restore();
      expect(restored.unresolved!.id, sent.awardId);
      expect(restored.canRetry, isTrue);
    });

    test('a valid unresolved record is never replaced or deleted by a new '
        'submission whose save fails', () async {
      final stale = admin();
      await stale.restore();
      final sent = await pinOne(admin());
      final saved = (await store.read(key))!;
      AwardSubmissionId.clearUnresolvedRegistry();

      store.failWrites = true;
      final writes = store.writes;
      final attempt = await stale.prepare(
        ['student', 's1', 'star', 'آخر'],
        (id) => params(id, 'آخر'),
      );
      expect(attempt.status, AwardPrepareStatus.blocked);
      expect(store.writes, writes, reason: 'an existing record is adopted');
      expect(stale.unresolved!.id, sent.awardId);
      await stale.confirmedFailure();
      expect(await store.read(key), saved);
    });

    test('D: a pinned admin operation cannot be re-prepared with different '
        'recipients, and restores with its original ones', () async {
      final ids = admin();
      final sent = await pinOne(ids);
      final saved = (await store.read(key))!;
      expect(saved, contains('"recipientStudentIds":["s1"]'));

      final changed = await ids.prepare(
        ['student', 's1', 'star', 'تميز', 'h2', '|', 's1', 's9'],
        (id) => AdminGrantRewardParams(
          awardId: id,
          targetKind: AdminRewardTargetKind.student,
          targetId: 's1',
          type: 'star',
          title: 'تميز',
          grantedBy: 'admin1',
          halaqaId: 'h2',
          recipientStudentIds: const ['s1', 's9'],
        ),
      );
      expect(changed.status, AwardPrepareStatus.blocked);
      expect(changed.payload, isNull);
      expect(ids.unresolved!.payload, sent);
      expect(await store.read(key), saved);

      AwardSubmissionId.clearUnresolvedRegistry();
      final restored = admin();
      await restored.restore();
      expect(restored.unresolved!.id, sent.awardId);
      expect(restored.unresolved!.payload.halaqaId, 'h1');
      expect(restored.unresolved!.payload.recipientStudentIds, ['s1']);
    });
  });

  group('grant error mapping', () {
    test('ambiguous transport errors say the retry is safe', () {
      for (final code in ['deadline-exceeded', 'unavailable', 'internal']) {
        expect(
          awardGrantErrorMessage(code, 'DEADLINE_EXCEEDED'),
          kAwardGrantUnconfirmedMessage,
        );
      }
    });

    test('server Arabic rejections pass through; raw text never does', () {
      expect(
        awardGrantErrorMessage('permission-denied', 'غير مسموح'),
        'غير مسموح',
      );
      expect(
        awardGrantErrorMessage('invalid-argument', 'Bad Request'),
        kAwardGrantFailedMessage,
      );
      expect(
        awardGrantErrorMessage('unauthenticated', 'UNAUTHENTICATED'),
        kAwardGrantSignedOutMessage,
      );
    });
  });

  group('teacher grant datasource', () {
    late FakeFunctions functions;
    late AwardsRemoteDatasourceImpl datasource;

    setUp(() {
      functions = FakeFunctions()..handlers['grantAward'] = (_) => null;
      datasource = AwardsRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        storage: UnusedStorage(),
        functions: functions,
      );
    });

    test('a timeout and its retry send the same awardId', () async {
      functions.handlers['grantAward'] = (_) =>
          throw FakeFunctionsError('deadline-exceeded', 'DEADLINE_EXCEEDED');
      await expectLater(
        datasource.grantAward(_model()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            kAwardGrantUnconfirmedMessage,
          ),
        ),
      );

      functions.handlers['grantAward'] = (_) => {
        'awardId': _awardId,
        'recipientCount': 1,
        'alreadyGranted': true,
      };
      await datasource.grantAward(_model());

      final ids = [for (final c in functions.calls) (c.$2 as Map)['awardId']];
      expect(ids, [_awardId, _awardId]);
    });

    test('a missing submission id is rejected before the server', () async {
      await expectLater(
        datasource.grantAward(_model(id: '')),
        throwsA(isA<ServerException>()),
      );
      expect(functions.calls, isEmpty);
    });

    test(
      'an unexpected error after sending is reported as unconfirmed',
      () async {
        functions.handlers['grantAward'] = (_) => throw StateError('socket');
        await expectLater(
          datasource.grantAward(_model()),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              kAwardGrantUnconfirmedMessage,
            ),
          ),
        );
      },
    );

    test('a committed grant whose response is lost: the retry replays it and '
        'a different payload under that id is refused', () async {
      // Mirrors the server: commit first, then the response never arrives.
      final committed = <String, Map>{};
      var dropResponse = true;
      functions.handlers['grantAward'] = (payload) {
        final p = payload as Map;
        final id = p['awardId'] as String;
        final prior = committed[id];
        if (prior != null) {
          if (prior['title'] != p['title']) {
            throw FakeFunctionsError(
              'failed-precondition',
              'معرّف العملية مستخدم لطلب مختلف.',
            );
          }
          return {'awardId': id, 'recipientCount': 1, 'alreadyGranted': true};
        }
        committed[id] = Map.of(p);
        if (dropResponse) {
          throw FakeFunctionsError('deadline-exceeded', 'DEADLINE_EXCEEDED');
        }
        return {'awardId': id, 'recipientCount': 1, 'alreadyGranted': false};
      };

      await expectLater(
        datasource.grantAward(_model()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            kAwardGrantUnconfirmedMessage,
          ),
        ),
      );
      dropResponse = false;
      await datasource.grantAward(_model());
      expect(committed, hasLength(1));

      final edited = GrantedAwardModel(
        id: _awardId,
        studentId: 's1',
        studentName: 'أحمد',
        type: AwardType.performanceStars,
        title: 'عنوان آخر',
        grantedBy: 'teacher1',
        halaqaId: 'h1',
        grantedAt: DateTime(2026, 9, 1),
        recipientStudentIds: const ['s1'],
      );
      await expectLater(
        datasource.grantAward(edited),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            isNot(kAwardGrantUnconfirmedMessage),
          ),
        ),
      );
      expect(committed[_awardId]!['title'], 'نجم الحلقة');
    });
  });

  group('admin grant datasource', () {
    late FakeFunctions functions;
    late AdminRemoteDatasourceImpl datasource;

    setUp(() {
      functions = FakeFunctions()..handlers['grantAward'] = (_) => null;
      datasource = AdminRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
      );
    });

    test('sends the submission id, reused across retries', () async {
      await datasource.grantReward(_params());
      await datasource.grantReward(_params());

      final ids = [for (final c in functions.calls) (c.$2 as Map)['awardId']];
      expect(ids, [_awardId, _awardId]);
      expect(
        (functions.payloadOf('grantAward') as Map)['type'],
        'performance_stars',
      );
    });

    test('raw callable text is not shown and a bad id never calls', () async {
      functions.handlers['grantAward'] = (_) =>
          throw FakeFunctionsError('unavailable', 'UNAVAILABLE');
      await expectLater(
        datasource.grantReward(_params()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            kAwardGrantUnconfirmedMessage,
          ),
        ),
      );

      functions.calls.clear();
      await expectLater(
        datasource.grantReward(_params(awardId: '')),
        throwsA(isA<ServerException>()),
      );
      expect(functions.calls, isEmpty);
    });

    test('a retry sends the pinned halaqa and recipients without reading '
        'Firestore', () async {
      const pinned = AdminGrantRewardParams(
        awardId: _awardId,
        targetKind: AdminRewardTargetKind.halaqa,
        targetId: 'h1',
        type: 'star',
        title: 'تميز',
        grantedBy: 'admin1',
        halaqaId: 'h1',
        recipientStudentIds: ['s1', 's2'],
      );
      // UnusedFirestore throws on any access, which would fail the call.
      await datasource.grantReward(pinned);
      await datasource.grantReward(pinned);
      for (final call in functions.calls) {
        final payload = call.$2 as Map;
        expect(payload['awardId'], _awardId);
        expect(payload['halaqaId'], 'h1');
        expect(payload['halaqaIds'], ['h1']);
        expect(payload['recipientStudentIds'], ['s1', 's2']);
      }
      expect(functions.calls, hasLength(2));
    });

    test('a failure before sending is confirmed; after sending it is '
        'unconfirmed', () async {
      // No pinned halaqa or recipients: refused before any callable.
      await expectLater(
        datasource.grantReward(
          const AdminGrantRewardParams(
            awardId: _awardId,
            targetKind: AdminRewardTargetKind.student,
            targetId: 's1',
            type: 'star',
            title: 'تميز',
            grantedBy: 'admin1',
          ),
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            kAwardGrantFailedMessage,
          ),
        ),
      );
      expect(functions.calls, isEmpty);

      functions.handlers['grantAward'] = (_) => throw StateError('socket');
      await expectLater(
        datasource.grantReward(_params()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            kAwardGrantUnconfirmedMessage,
          ),
        ),
      );
    });
  });

  group('blocs', () {
    test(
      'awards bloc drops a duplicate grant and reloads after success',
      () async {
        final repo = _AwardsRepo();
        final bloc = _awardsBloc(repo);
        final award = _model();

        bloc
          ..add(GrantAwardEvent(award))
          ..add(GrantAwardEvent(award));
        await Future<void>.delayed(Duration.zero);
        expect(repo.grants, hasLength(1));

        repo.results.single.complete(const Right(unit));
        await bloc.stream.firstWhere(
          (s) => s.awardsStatus == SectionStatus.loaded,
        );
        expect(bloc.state.grantStatus, SubmissionStatus.success);
        await bloc.close();
      },
    );

    test('awards bloc reports a definitive failure', () async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo)..add(GrantAwardEvent(_model()));
      await Future<void>.delayed(Duration.zero);

      repo.results.single.complete(
        const Left(ServerFailure('لا تملك صلاحية منح جوائز في هذه الحلقة')),
      );
      final state = await bloc.stream.firstWhere(
        (s) => s.grantStatus == SubmissionStatus.error,
      );
      expect(state.grantError, 'لا تملك صلاحية منح جوائز في هذه الحلقة');
      await bloc.close();
    });

    test('admin bloc drops a duplicate reward grant', () async {
      final repo = _RewardRepo();
      final bloc = _adminBloc(repo)
        ..add(GrantAdminRewardEvent(params: _params()))
        ..add(GrantAdminRewardEvent(params: _params()));
      await Future<void>.delayed(Duration.zero);
      expect(repo.grants, hasLength(1));

      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      final state = await bloc.stream.firstWhere(
        (s) => s.grantRewardStatus == SubmissionStatus.error,
      );
      expect(state.grantRewardError, kAwardGrantUnconfirmedMessage);
      await bloc.close();
    });
  });

  group('create award sheet', () {
    setUp(_useDurableStore);
    tearDown(_resetDurableStore);

    testWidgets('an unresolved grant survives an app restart: the reopened '
        'sheet resends the same id and exact values', (tester) async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);
      await _tapSubmit(tester);
      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      Navigator.of(tester.element(find.byType(CreateAwardSheet))).pop();
      await _settle(tester);
      bloc.add(const ResetGrantAwardEvent());
      await tester.pump();

      AwardSubmissionId.clearUnresolvedRegistry();
      await _openSheet(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      await _tapSubmit(tester);
      expect(repo.grants, hasLength(2));
      expect(identical(repo.grants.last, repo.grants.first), isFalse);
      expect(repo.grants.last, repo.grants.first);

      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(find.byType(CreateAwardSheet), findsNothing);
      expect(await sl<UnresolvedAwardStore>().read(_teacherKey), isNull);
      await _close(tester, bloc);
    });

    testWidgets('in the same session an image award is resent with its '
        'original image and the image cannot be changed', (tester) async {
      final seeded = await _seedTeacherUnresolved(
        image: r'C:\pics\award.png',
        restart: false,
      );
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      expect(find.byKey(const Key('award-unresolved-blocked')), findsNothing);

      // Absorbed by the lock: the file picker is never opened.
      await tester.tap(find.text('اختيار صورة'), warnIfMissed: false);
      await tester.pump();

      await _tapSubmit(tester);
      expect(repo.grants, hasLength(1));
      expect(identical(repo.grants.single, seeded), isTrue);
      expect(repo.grants.single.localImagePath, r'C:\pics\award.png');
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('after a restart an image award cannot be resent; abandoning '
        'is explicit and then allows a new grant', (tester) async {
      final seeded = await _seedTeacherUnresolved(
        image: r'C:\pics\award.png',
        restart: true,
      );
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      expect(find.text(kAwardImageNotRestorableNotice), findsOneWidget);

      await _tapSubmit(tester);
      expect(repo.grants, isEmpty);

      final abandon = find.byKey(const Key('award-abandon'));
      await tester.ensureVisible(abandon);
      await tester.tap(abandon);
      await _settle(tester);
      expect(find.text(kAwardGrantAbandonWarning), findsOneWidget);
      await tester.tap(find.byKey(const Key('award-abandon-confirm')));
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsNothing);
      expect(await sl<UnresolvedAwardStore>().read(_teacherKey), isNull);

      await _tapSubmit(tester);
      expect(repo.grants, hasLength(1));
      expect(repo.grants.single.id, isNot(seeded.id));
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('submitting stays disabled until saved requests are restored',
        (tester) async {
      final store = _GatedStore();
      await sl.reset();
      sl.registerLazySingleton<UnresolvedAwardStore>(() => store);
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester);
      expect(repo.grants, isEmpty);

      store.gate.complete();
      await _settle(tester);
      await _tapSubmit(tester);
      expect(repo.grants, hasLength(1));
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('while unresolved the form is locked and the retry resends the '
        'exact pinned award, even after a confirmed retry failure', (
      tester,
    ) async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester);
      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      expect(find.text(kAwardGrantRetrySameLabel), findsOneWidget);

      // Taps on the locked fields are absorbed; even a programmatic text
      // change does not reach the pinned request.
      await tester.tap(
        find.text(AwardType.attendance.title),
        warnIfMissed: false,
      );
      await tester.enterText(find.byType(TextField).first, 'عنوان معدل');
      await tester.pump();

      await _tapSubmit(tester);
      expect(repo.grants, hasLength(2));
      expect(identical(repo.grants.last, repo.grants.first), isTrue);

      repo.results.last.complete(
        const Left(ServerFailure('لا تملك صلاحية منح جوائز في هذه الحلقة')),
      );
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      expect(
        find.text('لا تملك صلاحية منح جوائز في هذه الحلقة'),
        findsOneWidget,
      );

      await _tapSubmit(tester);
      expect(repo.grants, hasLength(3));
      expect(repo.grants.last.id, repo.grants.first.id);
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(find.byType(CreateAwardSheet), findsNothing);
      await _close(tester, bloc);
    });

    testWidgets('abandon asks for confirmation, warns it cancels nothing, '
        'then a new submission gets a new id', (tester) async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester);
      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);

      final abandon = find.byKey(const Key('award-abandon'));
      await tester.ensureVisible(abandon);
      await tester.tap(abandon);
      await _settle(tester);
      expect(find.text(kAwardGrantAbandonWarning), findsOneWidget);
      await tester.tap(find.text('رجوع'));
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);

      await tester.tap(abandon);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('award-abandon-confirm')));
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsNothing);
      expect(find.text(kAwardGrantRetrySameLabel), findsNothing);

      await _tapSubmit(tester);
      expect(repo.grants, hasLength(2));
      expect(repo.grants.last.id, isNot(repo.grants.first.id));
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('closing and reopening the sheet restores the pinned request', (
      tester,
    ) async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester);
      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      Navigator.of(tester.element(find.byType(CreateAwardSheet))).pop();
      await _settle(tester);
      expect(find.byType(CreateAwardSheet), findsNothing);
      bloc.add(const ResetGrantAwardEvent());
      await tester.pump();

      await _openSheet(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      await _tapSubmit(tester);
      expect(repo.grants, hasLength(2));
      expect(identical(repo.grants.last, repo.grants.first), isTrue);

      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(find.byType(CreateAwardSheet), findsNothing);
      bloc.add(const ResetGrantAwardEvent());
      await tester.pump();

      await _openSheet(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsNothing);
      await _tapSubmit(tester);
      expect(repo.grants.last.id, isNot(repo.grants.first.id));
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('an unconfirmed grant keeps the sheet; the retry reuses the id '
        'and success closes it', (tester) async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester);
      expect(repo.grants, hasLength(1));
      expect(find.byType(CreateAwardSheet), findsOneWidget);

      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      expect(find.byType(CreateAwardSheet), findsOneWidget);
      expect(_error, findsOneWidget);
      expect(find.text(kAwardGrantUnconfirmedMessage), findsOneWidget);
      expect(find.text(AwardType.performanceStars.title), findsWidgets);

      await _tapSubmit(tester);
      expect(repo.grants, hasLength(2));
      expect(repo.grants.last.id, repo.grants.first.id);
      expect(AwardSubmissionId.isValid(repo.grants.first.id), isTrue);
      expect(find.byType(CreateAwardSheet), findsOneWidget);

      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(find.byType(CreateAwardSheet), findsNothing);
      await _close(tester, bloc);
    });

    testWidgets('repeated taps send one grant; a later sheet is a new '
        'operation', (tester) async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester, twice: true);
      await _settle(tester);
      expect(repo.grants, hasLength(1));

      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      expect(find.byType(CreateAwardSheet), findsNothing);
      bloc.add(const ResetGrantAwardEvent());
      await tester.pump();

      await _openSheet(tester);
      await _tapSubmit(tester);
      expect(repo.grants, hasLength(2));
      expect(repo.grants.last.id, isNot(repo.grants.first.id));
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('while the request is being saved the sheet is locked and '
        'nothing is sent', (tester) async {
      final store = _MemoryStore()..writeGate = Completer<void>();
      await sl.reset();
      sl.registerLazySingleton<UnresolvedAwardStore>(() => store);
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester, twice: true);
      await _tapSubmit(tester);
      expect(store.writes, 1);
      expect(repo.grants, isEmpty);
      expect(tester.widget<AppButton>(_submit).onPressed, isNull);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.byType(TextField).first,
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );

      store.writeGate!.complete();
      await _settle(tester);
      expect(repo.grants, hasLength(1));
      expect(await store.read(_teacherKey), contains(repo.grants.single.id));
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      expect(await store.read(_teacherKey), isNull);
      await _close(tester, bloc);
    });

    testWidgets('a failed local save sends nothing and explains why; retrying '
        'the save sends exactly one grant', (tester) async {
      final store = _MemoryStore()..failWrites = true;
      await sl.reset();
      sl.registerLazySingleton<UnresolvedAwardStore>(() => store);
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester);
      await _settle(tester);
      expect(repo.grants, isEmpty);
      expect(store.records, isEmpty);
      expect(find.text(kAwardLocalSaveFailedMessage), findsOneWidget);
      expect(tester.widget<AppButton>(_submit).onPressed, isNotNull);

      store.failWrites = false;
      await _tapSubmit(tester, twice: true);
      await _settle(tester);
      expect(repo.grants, hasLength(1));
      expect(find.text(kAwardLocalSaveFailedMessage), findsNothing);
      expect(await store.read(_teacherKey), contains(repo.grants.single.id));
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('an error after sending stays unresolved under the original '
        'id', (tester) async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);
      await _tapSubmit(tester);
      final sentId = repo.grants.single.id;

      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      final saved = await sl<UnresolvedAwardStore>().read(_teacherKey);
      expect(saved, contains(sentId));
      expect(saved, contains('"status":"unresolved"'));
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);

      await _tapSubmit(tester);
      expect(repo.grants.last.id, sentId);
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('a definitive failure leaves the form editable and '
        'retryable', (tester) async {
      final repo = _AwardsRepo();
      final bloc = _awardsBloc(repo);
      await _pumpHost(tester, bloc);
      await _openSheet(tester);

      await _tapSubmit(tester);
      repo.results.single.complete(
        const Left(ServerFailure('الطالب ليس ضمن الحلقات المختارة')),
      );
      await _settle(tester);

      expect(find.text('الطالب ليس ضمن الحلقات المختارة'), findsOneWidget);
      expect(find.byType(CreateAwardSheet), findsOneWidget);
      await _tapSubmit(tester);
      expect(repo.grants, hasLength(2));
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(find.byType(CreateAwardSheet), findsNothing);
      await _close(tester, bloc);
    });
  });

  group('admin rewards page', () {
    setUp(_useDurableStore);
    tearDown(_resetDurableStore);

    final grantButton = find.byKey(const Key('admin-reward-grant'));

    Future<AdminBloc> pumpAdmin(WidgetTester tester, _RewardRepo repo) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = _adminBloc(repo);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(
              value: _AuthBlocStub(AuthAuthenticated(_admin)),
            ),
            BlocProvider<AdminBloc>.value(value: bloc),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminRewardsPage(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      return bloc;
    }

    Future<void> fill(WidgetTester tester, String title) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await _settle(tester);
      await tester.tap(find.text('أحمد').last);
      await _settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان الجائزة'),
        title,
      );
      await tester.pump();
    }

    testWidgets('an unconfirmed reward pins the exact params; abandon then '
        'allows a new id', (tester) async {
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);
      await fill(tester, 'تميز');

      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(1));
      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      expect(find.text(kAwardGrantRetrySameLabel), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان الجائزة'),
        'عنوان معدل',
      );
      await tester.pump();
      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(2));
      expect(identical(repo.grants.last, repo.grants.first), isTrue);
      expect(repo.grants.last.title, 'تميز');

      repo.results.last.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const Key('award-abandon')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('award-abandon-confirm')));
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsNothing);

      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(3));
      expect(repo.grants.last.awardId, isNot(repo.grants.first.awardId));
      expect(repo.grants.last.title, 'عنوان معدل');
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('an unresolved reward survives an app restart and is resent '
        'with the same id and values', (tester) async {
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);
      await fill(tester, 'تميز');
      await tester.tap(grantButton);
      await tester.pump();
      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      Navigator.of(tester.element(find.byType(AdminRewardsPage))).pop();
      await _settle(tester);

      AwardSubmissionId.clearUnresolvedRegistry();
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(2));
      expect(identical(repo.grants.last, repo.grants.first), isFalse);
      expect(repo.grants.last, repo.grants.first);

      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsNothing);
      expect(
        await sl<UnresolvedAwardStore>().read(
          'awards.unresolved.grantAward.admin.admin1',
        ),
        isNull,
      );
      unawaited(bloc.close());
      await tester.pump();
    });

    const adminKey = 'awards.unresolved.grantAward.admin.admin1';

    IgnorePointer formLock(WidgetTester tester) => tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.widgetWithText(TextField, 'عنوان الجائزة'),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );

    testWidgets('while the reward is being saved the form is locked and '
        'nothing is sent', (tester) async {
      final store = _MemoryStore();
      await sl.reset();
      sl.registerLazySingleton<UnresolvedAwardStore>(() => store);
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);
      await fill(tester, 'تميز');

      store.writeGate = Completer<void>();
      await tester.tap(grantButton);
      await tester.tap(grantButton, warnIfMissed: false);
      await tester.pump();
      expect(store.writes, 1);
      expect(repo.grants, isEmpty);
      expect(tester.widget<AppButton>(grantButton).onPressed, isNull);
      expect(formLock(tester).ignoring, isTrue);

      store.writeGate!.complete();
      await _settle(tester);
      expect(repo.grants, hasLength(1));
      expect(await store.read(adminKey), contains(repo.grants.single.awardId));
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('a failed local save sends nothing; retrying the save sends '
        'exactly one reward', (tester) async {
      final store = _MemoryStore()..failWrites = true;
      await sl.reset();
      sl.registerLazySingleton<UnresolvedAwardStore>(() => store);
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);
      await fill(tester, 'تميز');

      await tester.tap(grantButton);
      await _settle(tester);
      expect(repo.grants, isEmpty);
      expect(store.records, isEmpty);
      expect(find.text(kAwardLocalSaveFailedMessage), findsOneWidget);
      expect(formLock(tester).ignoring, isFalse);

      store.failWrites = false;
      await tester.tap(grantButton);
      await tester.tap(grantButton, warnIfMissed: false);
      await _settle(tester);
      expect(repo.grants, hasLength(1));
      expect(await store.read(adminKey), contains(repo.grants.single.awardId));
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });

    AdminHalaqaSummaryEntity halaqaSummary(String id, String name) =>
        AdminHalaqaSummaryEntity(
          id: id,
          name: name,
          teacherId: 'teacher1',
          supervisorId: 'sup1',
          studentCount: 0,
        );

    Future<void> fillHalaqa(WidgetTester tester, String title) async {
      await tester.tap(find.text('حلقة'));
      await _settle(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await _settle(tester);
      await tester.tap(find.text('حلقة الفجر').last);
      await _settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان الجائزة'),
        title,
      );
      await tester.pump();
    }

    Future<void> unconfirmed(WidgetTester tester, _RewardRepo repo) async {
      repo.results.last.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
    }

    Future<void> reloadRoster(WidgetTester tester, AdminBloc bloc) async {
      bloc.add(const LoadStudentRosterEvent());
      await _settle(tester);
    }

    testWidgets('A: the halaqa and recipients are resolved and saved before '
        'the grant is sent', (tester) async {
      final store = _MemoryStore();
      await sl.reset();
      sl.registerLazySingleton<UnresolvedAwardStore>(() => store);
      final repo = _RewardRepo();
      String? recordAtSend;
      repo.onGrant = (_) => recordAtSend = store.records[adminKey];
      final bloc = await pumpAdmin(tester, repo);
      await fill(tester, 'تميز');

      await tester.tap(grantButton);
      await tester.pump();
      final sent = repo.grants.single;
      expect(sent.halaqaId, 'h1');
      expect(sent.recipientStudentIds, ['s1']);
      expect(recordAtSend, isNotNull);
      expect(recordAtSend, contains(sent.awardId));
      expect(recordAtSend, contains('"halaqaId":"h1"'));
      expect(recordAtSend, contains('"recipientStudentIds":["s1"]'));
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('B: after the roster changes, the retry after a restart sends '
        'the original recipients and halaqa under the same id', (
      tester,
    ) async {
      final repo = _RewardRepo()
        ..roster = [_rosterHalaqa('h1', 'حلقة الفجر', ['s1', 's2'])]
        ..halaqat = [halaqaSummary('h1', 'حلقة الفجر')];
      final bloc = await pumpAdmin(tester, repo);
      await fillHalaqa(tester, 'تميز الحلقة');
      await tester.tap(grantButton);
      await tester.pump();
      final first = repo.grants.single;
      expect(first.recipientStudentIds, ['s1', 's2']);
      await unconfirmed(tester, repo);

      repo.roster = [_rosterHalaqa('h1', 'حلقة الفجر', ['s1', 's3'])];
      await reloadRoster(tester, bloc);
      Navigator.of(tester.element(find.byType(AdminRewardsPage))).pop();
      await _settle(tester);
      AwardSubmissionId.clearUnresolvedRegistry();
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);

      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(2));
      final retry = repo.grants.last;
      expect(identical(retry, first), isFalse);
      expect(retry, first);
      expect(retry.awardId, first.awardId);
      expect(retry.halaqaId, 'h1');
      expect(retry.recipientStudentIds, ['s1', 's2']);
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('C: after the student moves halaqa, the retry keeps the '
        'original halaqa; a server rejection keeps it unresolved', (
      tester,
    ) async {
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);
      await fill(tester, 'تميز');
      await tester.tap(grantButton);
      await tester.pump();
      final first = repo.grants.single;
      await unconfirmed(tester, repo);

      repo.roster = [
        _rosterHalaqa('h1', 'حلقة الفجر', []),
        _rosterHalaqa('h2', 'حلقة العصر', ['s1']),
      ];
      await reloadRoster(tester, bloc);
      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(2));
      expect(identical(repo.grants.last, first), isTrue);
      expect(repo.grants.last.halaqaId, 'h1');

      repo.results.last.complete(
        const Left(ServerFailure('الطالب ليس ضمن الحلقات المختارة')),
      );
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      expect(find.text(kAwardGrantRetrySameLabel), findsOneWidget);
      expect(
        await sl<UnresolvedAwardStore>().read(adminKey),
        contains(first.awardId),
      );
      expect(repo.grants, hasLength(2), reason: 'nothing replaces it');
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('F: after a confirmed grant or an explicit abandon, a new '
        'grant uses the reloaded roster and a new id', (tester) async {
      final repo = _RewardRepo()
        ..roster = [_rosterHalaqa('h1', 'حلقة الفجر', ['s1', 's2'])]
        ..halaqat = [halaqaSummary('h1', 'حلقة الفجر')];
      final bloc = await pumpAdmin(tester, repo);
      await fillHalaqa(tester, 'تميز الحلقة');
      await tester.tap(grantButton);
      await tester.pump();

      repo.roster = [_rosterHalaqa('h1', 'حلقة الفجر', ['s1', 's2', 's4'])];
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان الجائزة'),
        'تميز الحلقة',
      );
      await tester.pump();
      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(2));
      expect(repo.grants[1].recipientStudentIds, ['s1', 's2', 's4']);
      expect(repo.grants[1].awardId, isNot(repo.grants[0].awardId));
      await unconfirmed(tester, repo);

      repo.roster = [_rosterHalaqa('h1', 'حلقة الفجر', ['s5'])];
      await tester.tap(find.byKey(const Key('award-abandon')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('award-abandon-confirm')));
      await _settle(tester);
      expect(find.byKey(const Key('award-unresolved-panel')), findsNothing);

      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(3));
      expect(repo.grants[2].recipientStudentIds, ['s5']);
      expect(repo.grants[2].awardId, isNot(repo.grants[1].awardId));
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });
  });

  group('admin rewards page: student halaqa and legacy records', () {
    setUp(_useDurableStore);
    tearDown(_resetDurableStore);

    const adminKey = 'awards.unresolved.grantAward.admin.admin1';
    final grantButton = find.byKey(const Key('admin-reward-grant'));
    final targetDropdown = find.byWidgetPredicate(
      (w) => w is DropdownButtonFormField<String> && w.key == null,
    );
    final studentHalaqaDropdown = find.byKey(
      const Key('admin-reward-student-halaqa'),
    );
    const chooseHalaqaMessage =
        'الطالب مسجل في أكثر من حلقة. اختر الحلقة التي تُمنح فيها الجائزة.';

    List<AdminHalaqaRosterEntity> twoHalaqat() => [
      _rosterHalaqa('h1', 'حلقة الفجر', ['s1']),
      _rosterHalaqa('h2', 'حلقة العصر', ['s1', 's2']),
    ];

    Future<AdminBloc> pumpAdmin(WidgetTester tester, _RewardRepo repo) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = _adminBloc(repo);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(
              value: _AuthBlocStub(AuthAuthenticated(_admin)),
            ),
            BlocProvider<AdminBloc>.value(value: bloc),
          ],
          child: const MaterialApp(home: AdminRewardsPage()),
        ),
      );
      await _settle(tester);
      return bloc;
    }

    Future<void> pickStudent(WidgetTester tester) async {
      await tester.tap(targetDropdown);
      await _settle(tester);
      expect(
        find.text('أحمد'),
        findsOneWidget,
        reason: 'listed once in the menu, despite several halaqat',
      );
      await tester.tap(find.text('أحمد').last);
      await _settle(tester);
    }

    Future<void> pickStudentHalaqa(WidgetTester tester, String name) async {
      await tester.tap(studentHalaqaDropdown);
      await _settle(tester);
      await tester.tap(find.text(name).last);
      await _settle(tester);
    }

    Future<void> enterTitle(WidgetTester tester, String title) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان الجائزة'),
        title,
      );
      await tester.pump();
    }

    testWidgets('A: a student in one halaqa is resolved automatically', (
      tester,
    ) async {
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);
      await tester.tap(targetDropdown);
      await _settle(tester);
      await tester.tap(find.text('أحمد').last);
      await _settle(tester);
      expect(studentHalaqaDropdown, findsNothing);
      await enterTitle(tester, 'تميز');

      await tester.tap(grantButton);
      await tester.pump();
      final sent = repo.grants.single;
      expect(sent.halaqaId, 'h1');
      expect(sent.halaqaName, 'حلقة الفجر');
      expect(sent.recipientStudentIds, ['s1']);
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('B: a student in several halaqat is never assigned one '
        'implicitly', (tester) async {
      final repo = _RewardRepo()..roster = twoHalaqat();
      final bloc = await pumpAdmin(tester, repo);
      await pickStudent(tester);
      expect(studentHalaqaDropdown, findsOneWidget);
      for (final name in ['حلقة الفجر', 'حلقة العصر']) {
        expect(
          find.descendant(
            of: studentHalaqaDropdown,
            matching: find.text(name),
          ),
          findsNothing,
          reason: 'no halaqa is preselected',
        );
      }
      await enterTitle(tester, 'تميز');

      await tester.tap(grantButton);
      await _settle(tester);
      expect(repo.grants, isEmpty);
      expect(await sl<UnresolvedAwardStore>().read(adminKey), isNull);
      expect(find.text(chooseHalaqaMessage), findsOneWidget);
      expect(find.byKey(const Key('award-unresolved-panel')), findsNothing);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('C: the chosen halaqa and its exact recipients are saved '
        'before the first send', (tester) async {
      final store = _MemoryStore();
      await sl.reset();
      sl.registerLazySingleton<UnresolvedAwardStore>(() => store);
      final repo = _RewardRepo()..roster = twoHalaqat();
      String? recordAtSend;
      repo.onGrant = (_) => recordAtSend = store.records[adminKey];
      final bloc = await pumpAdmin(tester, repo);
      await pickStudent(tester);
      await pickStudentHalaqa(tester, 'حلقة العصر');
      await enterTitle(tester, 'تميز');

      await tester.tap(grantButton);
      await tester.pump();
      final sent = repo.grants.single;
      expect(sent.halaqaId, 'h2');
      expect(sent.halaqaName, 'حلقة العصر');
      expect(sent.recipientStudentIds, ['s1']);
      expect(recordAtSend, contains(sent.awardId));
      expect(recordAtSend, contains('"halaqaId":"h2"'));
      expect(recordAtSend, contains('"recipientStudentIds":["s1"]'));
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('D: roster and selection changes after an unconfirmed result '
        'leave the pinned halaqa and recipients unchanged', (tester) async {
      final repo = _RewardRepo()..roster = twoHalaqat();
      final bloc = await pumpAdmin(tester, repo);
      await pickStudent(tester);
      await pickStudentHalaqa(tester, 'حلقة العصر');
      await enterTitle(tester, 'تميز');
      await tester.tap(grantButton);
      await tester.pump();
      final first = repo.grants.single;
      repo.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      final pinnedRecord = await sl<UnresolvedAwardStore>().read(adminKey);
      expect(pinnedRecord, contains('"halaqaId":"h2"'));

      await tester.tap(studentHalaqaDropdown, warnIfMissed: false);
      await _settle(tester);
      expect(find.text('حلقة الفجر'), findsNothing, reason: 'form is locked');

      repo.roster = [
        _rosterHalaqa('h1', 'حلقة الفجر', ['s1', 's3']),
        _rosterHalaqa('h2', 'حلقة العصر', ['s2']),
      ];
      bloc.add(const LoadStudentRosterEvent());
      await _settle(tester);
      expect(await sl<UnresolvedAwardStore>().read(adminKey), pinnedRecord);

      await tester.tap(grantButton);
      await tester.pump();
      expect(repo.grants, hasLength(2));
      expect(identical(repo.grants.last, first), isTrue);
      expect(repo.grants.last.halaqaId, 'h2');
      expect(repo.grants.last.recipientStudentIds, ['s1']);
      repo.results.last.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });

    Future<String> seedLegacyRecord() async {
      final store = sl<UnresolvedAwardStore>();
      final ids = AwardSubmissionId<AdminGrantRewardParams>.durable(
        scope: const AwardOperationScope(
          operation: AwardOperationScope.grantAward,
          form: 'admin',
          uid: 'admin1',
        ),
        store: store,
        codec: const AdminGrantRewardPayloadCodec(),
      );
      await ids.restore();
      final prepared = await ids.prepare(
        ['legacy'],
        (id) => AdminGrantRewardParams(
          awardId: id,
          targetKind: AdminRewardTargetKind.student,
          targetId: 's1',
          type: 'star',
          title: 'تميز سابق',
          grantedBy: 'admin1',
          halaqaId: 'h1',
          halaqaName: 'حلقة الفجر',
          studentName: 'أحمد',
          recipientStudentIds: const ['s1'],
        ),
      );
      await ids.markUnresolved();
      final legacy = (await store.read(adminKey))!.replaceFirst(
        ',"recipientStudentIds":["s1"]',
        '',
      );
      await store.write(adminKey, legacy);
      AwardSubmissionId.clearUnresolvedRegistry();
      expect(legacy, contains(prepared.payload!.awardId));
      return legacy;
    }

    testWidgets('F: a legacy record without recipients shows the explicit '
        'warning, blocks new grants and cannot be retried', (tester) async {
      final legacy = await seedLegacyRecord();
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);

      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      expect(find.text(kAwardRecordUnreadableSummary), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('award-unresolved-blocked'))).data,
        kAwardRecordUnreadableNotice,
      );
      expect(kAwardRecordUnreadableNotice, contains('ربما يكون قد نُفِّذ'));
      expect(kAwardRecordUnreadableNotice, contains('لا يمكن إعادة إرساله بأمان'));
      expect(kAwardRecordUnreadableNotice, contains('الطلاب المستلمون'));
      expect(kAwardRecordUnreadableNotice, contains('راجع قائمة الجوائز قبل تجاهله'));
      expect(kAwardRecordUnreadableNotice, contains('ولا يلغي جائزة'));
      final awardId = RegExp(r'"awardId":"([^"]+)"').firstMatch(legacy)!.group(1)!;
      expect(find.textContaining(awardId), findsNothing);
      expect(find.textContaining('FormatException'), findsNothing);
      expect(find.text(kAwardGrantRetrySameLabel), findsNothing);
      expect(tester.widget<AppButton>(grantButton).onPressed, isNull);

      await tester.tap(grantButton, warnIfMissed: false);
      await _settle(tester);
      expect(repo.grants, isEmpty);
      expect(await sl<UnresolvedAwardStore>().read(adminKey), legacy);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('G: declining to abandon keeps the legacy record', (
      tester,
    ) async {
      final legacy = await seedLegacyRecord();
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);

      await tester.tap(find.byKey(const Key('award-abandon')));
      await _settle(tester);
      expect(find.text(kAwardGrantAbandonWarning), findsOneWidget);
      await tester.tap(find.text('رجوع'));
      await _settle(tester);

      expect(await sl<UnresolvedAwardStore>().read(adminKey), legacy);
      expect(find.byKey(const Key('award-unresolved-panel')), findsOneWidget);
      expect(tester.widget<AppButton>(grantButton).onPressed, isNull);
      expect(repo.grants, isEmpty);
      unawaited(bloc.close());
      await tester.pump();
    });

    testWidgets('H: a confirmed abandon removes only the local record and '
        'allows a new grant under a new id', (tester) async {
      final legacy = await seedLegacyRecord();
      final legacyId = RegExp(
        r'"awardId":"([^"]+)"',
      ).firstMatch(legacy)!.group(1)!;
      final repo = _RewardRepo();
      final bloc = await pumpAdmin(tester, repo);

      await tester.tap(find.byKey(const Key('award-abandon')));
      await _settle(tester);
      expect(find.text(kAwardGrantAbandonWarning), findsOneWidget);
      await tester.tap(find.byKey(const Key('award-abandon-confirm')));
      await _settle(tester);

      expect(await sl<UnresolvedAwardStore>().read(adminKey), isNull);
      expect(find.byKey(const Key('award-unresolved-panel')), findsNothing);
      expect(repo.grants, isEmpty, reason: 'abandon sends nothing');
      expect(find.text('تم منح الجائزة'), findsNothing);

      await tester.tap(targetDropdown);
      await _settle(tester);
      await tester.tap(find.text('أحمد').last);
      await _settle(tester);
      await enterTitle(tester, 'تميز جديد');
      await tester.tap(grantButton);
      await tester.pump();
      final sent = repo.grants.single;
      expect(sent.awardId, isNot(legacyId));
      expect(sent.recipientStudentIds, ['s1']);
      repo.results.single.complete(const Right(unit));
      await _settle(tester);
      unawaited(bloc.close());
      await tester.pump();
    });
  });
}
