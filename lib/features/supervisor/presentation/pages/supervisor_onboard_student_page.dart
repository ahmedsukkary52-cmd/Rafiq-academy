import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../accounts/data/academy_accounts_repository.dart';
import '../../../accounts/domain/onboarding_models.dart';
import '../../../accounts/presentation/admin_onboard_student_page.dart';
import '../bloc/supervisor_bloc.dart';

/// Supervisor-scoped student/parent onboarding into a supervised halaqa.
class SupervisorOnboardStudentPage extends StatelessWidget {
  const SupervisorOnboardStudentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = sl<AcademyAccountsRepository>();

    return AdminOnboardStudentPage(
      title: 'إضافة طالب وولي أمر',
      requireHalaqa: true,
      submit: repo.supervisorOnboardStudent,
      loadHalaqat: () async {
        var state = context.read<SupervisorBloc>().state;
        if (state.halaqat.isEmpty &&
            (state.halaqatStatus == SectionStatus.initial ||
                state.halaqatStatus == SectionStatus.loading)) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!context.mounted) return const <OnboardingHalaqaOption>[];
          state = context.read<SupervisorBloc>().state;
        }
        return [
          for (final h in state.halaqat)
            OnboardingHalaqaOption(
              id: h.id,
              name: h.name,
              studentCount: h.studentIds.length,
            ),
        ];
      },
    );
  }
}
