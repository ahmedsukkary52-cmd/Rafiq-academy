import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/accounts/domain/onboarding_models.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_directory_entity.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_admin_directory_usecases.dart';
import 'package:rafiq_academy/features/admin/presentation/admin_onboarding_halaqat.dart';

class _Repo extends Fake implements AdminRepository {
  _Repo(this.result);

  final Either<Failure, List<AdminHalaqaSummaryEntity>> result;
  int calls = 0;

  @override
  Future<Either<Failure, List<AdminHalaqaSummaryEntity>>> getAllHalaqat() async {
    calls++;
    return result;
  }
}

void main() {
  test('maps Admin halaqa summaries to onboarding options', () async {
    final repo = _Repo(
      const Right([
        AdminHalaqaSummaryEntity(
          id: 'h1',
          name: 'حلقة الفجر',
          teacherId: 't1',
          supervisorId: 's1',
          studentCount: 4,
          teacherName: 'أ. خالد',
          supervisorName: 'أ. سعيد',
        ),
      ]),
    );
    final options = await loadOnboardingHalaqat(
      getAllHalaqat: GetAllHalaqatUseCase(repo),
    );
    expect(repo.calls, 1);
    expect(options, const [
      OnboardingHalaqaOption(
        id: 'h1',
        name: 'حلقة الفجر',
        teacherName: 'أ. خالد',
        supervisorName: 'أ. سعيد',
        studentCount: 4,
      ),
    ]);
  });

  test('a failure throws so the wizard shows its retry state', () async {
    final repo = _Repo(const Left(ServerFailure('تعذر')));
    await expectLater(
      loadOnboardingHalaqat(getAllHalaqat: GetAllHalaqatUseCase(repo)),
      throwsStateError,
    );
  });
}
