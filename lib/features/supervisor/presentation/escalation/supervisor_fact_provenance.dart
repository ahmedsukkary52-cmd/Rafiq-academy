import '../../../../shared/domain/halaqa_day_readiness.dart';

/// Presentation provenance for one displayed supervisor conclusion (W6 Rule 7).
///
/// Maps **already-derived** readiness / board states to W1–W5 fact sources.
/// Does **not** recompute readiness. Does **not** persist. Does **not** invent
/// supervisor-specific business rules.
class SupervisorFactProvenance {
  /// Which academy facts produced this state (W1–W5).
  final String academyFacts;

  /// Which teacher-owned (or schedule) workflow owns those facts.
  final String owningWorkflow;

  /// Which teacher action would resolve the issue (empty when already healthy
  /// or there is no operational day).
  final String resolvingAction;

  const SupervisorFactProvenance({
    required this.academyFacts,
    required this.owningWorkflow,
    required this.resolvingAction,
  });

  bool get isResolvable => resolvingAction.trim().isNotEmpty;

  /// Provenance for one shared readiness gap — presentation only.
  static SupervisorFactProvenance forGap(HalaqaDayGap gap) =>
      forGapKind(gap.kind, quantity: gap.quantity);

  static SupervisorFactProvenance forGapKind(
    HalaqaDayGapKind kind, {
    int? quantity,
  }) => switch (kind) {
    HalaqaDayGapKind.attendanceIncomplete => SupervisorFactProvenance(
      academyFacts: quantity == null
          ? 'سجلات الحضور لليوم مقابل قائمة طلاب الحلقة (W2 AttendancePolicy)'
          : 'سجلات الحضور لليوم مقابل قائمة طلاب الحلقة — $quantity غير مُعلَّم (W2)',
      owningWorkflow: 'سير عمل حضور المعلم (W2 / W3)',
      resolvingAction: 'يكمل المعلم تسجيل الحضور لكل طلاب الحلقة',
    ),
    HalaqaDayGapKind.homeworkPending => const SupervisorFactProvenance(
      academyFacts:
          'أحدث dueDate للتكليفات على مستوى الحلقة ليس يوم اليوم (W1 D7)',
      owningWorkflow: 'سير عمل تكليف المعلم (W1 / W3)',
      resolvingAction: 'يرسل المعلم تكليف اليوم للحلقة',
    ),
    HalaqaDayGapKind.reviewsPending => SupervisorFactProvenance(
      academyFacts: quantity == null
          ? 'سجلات التسميع ذات reviewStatus = pending (W1)'
          : 'سجلات التسميع ذات reviewStatus = pending — العدد $quantity (W1)',
      owningWorkflow: 'سير عمل مراجعة التسميعات (W1 / W3؛ أحداث W5 للملاحظة)',
      resolvingAction: 'يراجع المعلم التسميعات المعلّقة',
    ),
  };

  /// Healthy session today — zero gaps from the shared projector.
  static const complete = SupervisorFactProvenance(
    academyFacts:
        'سجل حضور مكتمل + تكليف يوم اليوم (W1 D7) + لا تسميعات معلّقة '
        '(نفس HalaqaDayReadinessProjector)',
    owningWorkflow: 'يوم المعلم التشغيلي (W3)',
    resolvingAction: '',
  );

  /// No operational session today (D-W6-6) — schedule derivation only.
  static const noSessionToday = SupervisorFactProvenance(
    academyFacts:
        'لا يوجد slot جدول لليوم عبر HalaqaWeeklySessionsMapper (W3 Pre-Slice)',
    owningWorkflow: 'جدول الحلقة الأسبوعي',
    resolvingAction: '',
  );
}
