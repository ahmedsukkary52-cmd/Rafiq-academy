import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/router_app.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../teacher_contact_parent.dart';

/// Actions offered on a Class Details student card.
enum StudentCardAction { profile, evaluate, contactParent, award }

/// Teacher surfaces are shared with escalated supervisors (W6). A CTA is only
/// offered when [AppRouteAccess] would let the viewer open its destination, so
/// the router never has to bounce a tap. Contact parent opens on the viewer's
/// own chat surface ([contactStudentParent]).
class TeacherSurfaceNavigation {
  const TeacherSurfaceNavigation._();

  static String viewerRole(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.user.role : '';
  }

  static bool canOpenStudentProfile(String role) => AppRouteAccess.isAllowed(
    path: AppRoutes.teacherStudentProfile('probe'),
    role: role,
  );

  static bool canOpenTeacherChat(String role) =>
      AppRouteAccess.isAllowed(path: '/teacher/chat/probe', role: role);

  static List<StudentCardAction> studentCardActions({
    required String role,
    required bool isAtRisk,
  }) {
    return [
      if (canOpenStudentProfile(role)) StudentCardAction.profile,
      StudentCardAction.evaluate,
      if (!isAtRisk)
        StudentCardAction.award
      else if (staffCanContactStudentParent(role))
        StudentCardAction.contactParent,
    ];
  }
}
