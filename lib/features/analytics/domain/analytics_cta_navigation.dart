import '../../../core/constants/app_constants.dart';
import '../../../core/router/router_app.dart';
import '../../chat/domain/policies/chat_permission_policy.dart';
import 'entities/analytics_entities.dart';

/// Pure Analytics CTA navigation helpers (Phase 2 — testable without widgets).
class AnalyticsCtaNavigation {
  const AnalyticsCtaNavigation._();

  /// Existing Evaluations route with optional student deep-link.
  static String evaluationsPath({
    required String halaqaId,
    required String studentId,
  }) {
    final base = AppRoutes.teacherEvals.replaceFirst(':halaqaId', halaqaId);
    if (studentId.isEmpty) return base;
    return '$base?studentId=${Uri.encodeQueryComponent(studentId)}';
  }

  /// Teacher ↔ student Chat only — never parent / other roles.
  static bool allowsStudentContact({
    required String teacherRole,
    required String peerRole,
  }) {
    if (peerRole != AppRoles.student) return false;
    return ChatPermissionPolicy.canChat(teacherRole, peerRole);
  }

  /// Figma at-risk row: one primary action matching [reason] (not both).
  static String atRiskActionLabel(RiskReason reason) => switch (reason) {
    RiskReason.noRecentEvaluation => 'تقييم',
    RiskReason.repeatedAbsence => 'تواصل',
    RiskReason.lowPerformance => 'تواصل',
  };

  static bool atRiskActionIsEvaluate(RiskReason reason) =>
      reason == RiskReason.noRecentEvaluation;
}
