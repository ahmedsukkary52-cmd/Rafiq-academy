import 'package:equatable/equatable.dart';

/// C13 / WA-14 — one row of the safe student directory projection.
///
/// Deliberately does not surface `visibleTo`: it is a server-maintained
/// authorization key enforced by Rules, not something the client should
/// re-implement decisions on.
class StudentSearchEntry extends Equatable {
  /// Auth uid — also the `users` / `studentProfiles` document id.
  final String studentId;

  final String fullName;

  /// Frozen query key; kept so callers can order/filter without re-normalizing.
  final String fullNameNormalized;

  /// Display primary only — never a membership or authorization statement.
  final String? halaqaId;

  /// Name of [halaqaId]; empty when unassigned or the halaqa is missing.
  final String halaqaName;

  /// Every halaqa whose roster contains the student (bounded, roster-derived).
  final List<String> halaqaIds;

  const StudentSearchEntry({
    required this.studentId,
    required this.fullName,
    required this.fullNameNormalized,
    required this.halaqaId,
    required this.halaqaName,
    required this.halaqaIds,
  });

  bool get hasHalaqa => halaqaIds.isNotEmpty;

  /// Safe disambiguation for duplicate full names: halaqa first, then the id.
  String get disambiguationHint =>
      halaqaName.isNotEmpty ? halaqaName : studentId;

  @override
  List<Object?> get props => [
    studentId,
    fullName,
    fullNameNormalized,
    halaqaId,
    halaqaName,
    halaqaIds,
  ];
}
