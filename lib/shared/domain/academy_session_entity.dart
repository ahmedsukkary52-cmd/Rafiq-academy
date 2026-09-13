import 'package:equatable/equatable.dart';

import 'session_contract.dart';

/// Domain read model for `sessions/{sessionId}` (C6 / WA-8).
///
/// Historical occurrence — times and staff assignment are snapshots from
/// materialization, not live schedule lookups.
class AcademySessionEntity extends Equatable {
  final String id;
  final String halaqaId;
  final String slotId;

  /// Cairo calendar date `YYYY-MM-DD`.
  final String date;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final String teacherId;
  final String? supervisorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const AcademySessionEntity({
    required this.id,
    required this.halaqaId,
    required this.slotId,
    required this.date,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.teacherId,
    this.supervisorId,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  bool get isValidStatus => SessionContract.isValidStatus(status);

  @override
  List<Object?> get props => [
    id,
    halaqaId,
    slotId,
    date,
    startAt,
    endAt,
    status,
    teacherId,
    supervisorId,
    createdAt,
    updatedAt,
    createdBy,
  ];
}
