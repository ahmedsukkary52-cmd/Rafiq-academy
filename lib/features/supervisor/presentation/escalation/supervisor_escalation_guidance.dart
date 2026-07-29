import '../../../../core/router/supervisor_escalation_paths.dart';
import '../../../../shared/domain/halaqa_day_readiness.dart';
import '../../domain/read_models/supervisor_day_board.dart';

/// Presentation guidance for one blocked workflow (W6 Rule 6).
///
/// Answers only:
/// - Who owns this action?
/// - Why does it need attention?
/// - Where should the supervisor go?
///
/// Never transfers ownership. Never invents readiness. Navigation eligibility
/// is presentation/router only ([canNavigate]).
class SupervisorEscalationGuidance {
  /// Responsible teacher display (owner of execution).
  final String ownerName;

  /// Classroom name.
  final String halaqaName;

  /// Rule 4 explanation from shared gap facts.
  final String why;

  /// Human label for the teacher-owned workflow destination.
  final String whereLabel;

  /// Existing teacher route (may be non-navigable under permissions).
  final String route;

  /// Whether the client may open [route] (D-W6-1). When false, UI must not
  /// expose a navigation action — facts only (Rule 6 fallback).
  final bool canNavigate;

  const SupervisorEscalationGuidance({
    required this.ownerName,
    required this.halaqaName,
    required this.why,
    required this.whereLabel,
    required this.route,
    required this.canNavigate,
  });

  factory SupervisorEscalationGuidance.fromGap({
    required SupervisorDayBoardItem item,
    required HalaqaDayGap gap,
    bool? navigationAllowed,
  }) {
    final route = supervisorEscalationRoute(gap.kind, item.halaqaId);
    final allowed =
        navigationAllowed ?? SupervisorEscalationPaths.isAllowed(route);
    return SupervisorEscalationGuidance(
      ownerName: escalationOwnerName(item),
      halaqaName: item.halaqaName.trim().isEmpty
          ? 'حلقة'
          : item.halaqaName.trim(),
      why: explainSupervisorGap(gap),
      whereLabel: escalationWhereLabel(gap.kind),
      route: route,
      canNavigate: allowed,
    );
  }
}

/// Rule 4 — presentation wording from shared gap facts.
String explainSupervisorGap(HalaqaDayGap gap) => switch (gap.kind) {
  HalaqaDayGapKind.attendanceIncomplete => 'لم يُسجَّل الحضور بعد.',
  HalaqaDayGapKind.homeworkPending => 'لم يُعيَّن واجب اليوم.',
  HalaqaDayGapKind.reviewsPending =>
    '${gap.quantity ?? 0} تسميعات لا تزال بانتظار المراجعة.',
};

/// Deep-links only to existing teacher-owned workflows (D-W6-1 / Rule 2).
String supervisorEscalationRoute(HalaqaDayGapKind kind, String halaqaId) =>
    switch (kind) {
      HalaqaDayGapKind.attendanceIncomplete =>
        '${SupervisorEscalationPaths.teacherRoot}/attendance/$halaqaId',
      HalaqaDayGapKind.homeworkPending =>
        '${SupervisorEscalationPaths.teacherRoot}/halaqa/$halaqaId?assign=1',
      HalaqaDayGapKind.reviewsPending =>
        '${SupervisorEscalationPaths.teacherRoot}/halaqa/$halaqaId/evaluations',
    };

String escalationOwnerName(SupervisorDayBoardItem item) {
  final name = item.teacherDisplayName.trim();
  if (name.isNotEmpty) return name;
  final id = item.teacherId.trim();
  if (id.isNotEmpty) return id;
  return 'معلم الحلقة';
}

String escalationWhereLabel(HalaqaDayGapKind kind) => switch (kind) {
  HalaqaDayGapKind.attendanceIncomplete => 'سير عمل تسجيل الحضور (المعلم)',
  HalaqaDayGapKind.homeworkPending => 'سير عمل تكليف اليوم (المعلم)',
  HalaqaDayGapKind.reviewsPending => 'سير عمل مراجعة التسميعات (المعلم)',
};
