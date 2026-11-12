import '../../../core/di/injection_container.dart';
import '../../../core/usecases/usecases.dart';
import '../../accounts/domain/onboarding_models.dart';
import '../domain/entities/admin_directory_entity.dart';
import '../domain/usecases/get_admin_directory_usecases.dart';

OnboardingHalaqaOption onboardingHalaqaOptionFrom(AdminHalaqaSummaryEntity h) =>
    OnboardingHalaqaOption(
      id: h.id,
      name: h.name,
      teacherName: h.teacherName,
      supervisorName: h.supervisorName,
      studentCount: h.studentCount,
    );

/// Halaqat for the onboarding wizard, read through the Admin directory use
/// case. Throws the failure message so the wizard shows its retry state.
Future<List<OnboardingHalaqaOption>> loadOnboardingHalaqat({
  GetAllHalaqatUseCase? getAllHalaqat,
}) async {
  final result = await (getAllHalaqat ?? sl<GetAllHalaqatUseCase>())(
    const NoParams(),
  );
  return result.fold(
    (f) => throw StateError(f.message),
    (list) => [for (final h in list) onboardingHalaqaOptionFrom(h)],
  );
}
