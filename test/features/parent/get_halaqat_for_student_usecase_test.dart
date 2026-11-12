import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/schedule/domain/entities/halaqa_schedule_source.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_halaqat_for_student_usecase.dart';
import 'package:rafiq_academy/shared/domain/achievement_entity.dart';
import 'package:rafiq_academy/shared/domain/academy_billing_entities.dart';
import 'package:rafiq_academy/shared/domain/payment_access_entity.dart';

class _FakeParentRepository implements ParentRepository {
  final List<String> children;
  final List<ParentHalaqaOption> halaqat = const [
    ParentHalaqaOption(id: 'h1', name: 'حلقة'),
  ];
  int halaqatCalls = 0;

  _FakeParentRepository({this.children = const ['s1']});

  @override
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId) async =>
      Right(children);

  @override
  Future<Either<Failure, List<ParentHalaqaOption>>> getHalaqatForStudent(
    String studentId,
  ) async {
    halaqatCalls++;
    return Right(halaqat);
  }

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, WeeklyReportEntity>> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<PaymentEntity>>> getPayments(String parentId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, PaymentPublicSettingsEntity>>
  getPaymentPublicSettings() => throw UnimplementedError();
  @override
  Future<Either<Failure, PaymentAccessEntity?>> getPaymentAccess(
    String parentId,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> submitAbsenceRequest(
    AbsenceRequestEntity request,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForParent(String parentId) => throw UnimplementedError();
  @override
  Stream<Either<Failure, List<String>>> watchChildrenAssignments(
    String parentId,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> submitPaymentProof({
    required String parentId,
    required String paymentId,
    required String localFilePath,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, Uint8List>> downloadPaymentProof({
    required String parentId,
    required String paymentId,
    required String storagePath,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, ParentHousehold>> getHousehold({
    required String parentId,
    required List<String> childrenIds,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<ParentAttendanceMark>>> getAttendanceMarks({
    required String studentId,
    required DateTime start,
    required DateTime endExclusive,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<AchievementEntity>>> getChildAchievements(
    String studentId,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, HalaqaScheduleSource>> getChildHalaqaSchedule({
    required String studentId,
    required String halaqaId,
  }) => throw UnimplementedError();
}

void main() {
  group('GetHalaqatForStudentUseCase (W7 Slice 1)', () {
    test('returns halaqat when parent owns student', () async {
      final repo = _FakeParentRepository();
      final useCase = GetHalaqatForStudentUseCase(repo);

      final result = await useCase(
        const StudentHalaqatParams(parentId: 'p1', studentId: 's1'),
      );

      expect(result.isRight(), isTrue);
      expect(repo.halaqatCalls, 1);
      expect(result.getOrElse((_) => const []), repo.halaqat);
    });

    test('rejects student not linked to parent (no halaqa leak)', () async {
      final repo = _FakeParentRepository(children: const ['other']);
      final useCase = GetHalaqatForStudentUseCase(repo);

      final result = await useCase(
        const StudentHalaqatParams(parentId: 'p1', studentId: 's1'),
      );

      expect(result.isLeft(), isTrue);
      expect(repo.halaqatCalls, 0);
    });
  });
}
