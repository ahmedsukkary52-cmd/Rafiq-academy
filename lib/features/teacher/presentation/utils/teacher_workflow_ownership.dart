import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// Presentation gate: who may **execute** teacher-owned writes (W6 Rule 6).
///
/// Escalation may open teacher surfaces for guidance; only the teacher role
/// may perform attendance / assign / review operations.
class TeacherWorkflowOwnership {
  const TeacherWorkflowOwnership._();

  static bool canExecute(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated && auth.user.role == AppRoles.teacher;
  }
}
