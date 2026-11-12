import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../accounts/domain/onboarding_models.dart';
import '../domain/directory_models.dart';

/// Navigation between directory profiles. Ids travel in the route only;
/// screens show names, roles and academy codes.
class DirectoryNavigator {
  const DirectoryNavigator();

  void openPerson(BuildContext context, String uid) =>
      context.push(AppRoutes.adminPersonProfile(uid));

  void openHalaqa(BuildContext context, String halaqaId) =>
      context.push(AppRoutes.adminHalaqaProfile(halaqaId));

  /// Student onboarding wizard with [parent] already selected.
  void addChild(BuildContext context, DirectoryPerson parent) => context.push(
    AppRoutes.adminOnboardStudent,
    extra: MemberSearchHit(uid: parent.uid, name: parent.name),
  );

  void addStudent(BuildContext context) => context.push(AppRoutes.adminOnboardStudent);

  void addMember(BuildContext context, DirectoryRole role) =>
      context.push(AppRoutes.adminAddMemberFor(role.wire));

  void addAdmin(BuildContext context) => context.push(AppRoutes.adminAccounts);
}
