import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/award_entities.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class AwardsState extends Equatable {
  // ── لوحة الجوائز ──────────────────────────────────────────────────────
  final SectionStatus statsStatus;
  final AwardsStatsEntity? stats;
  final String? statsError;

  final SectionStatus awardsStatus;
  final List<GrantedAwardEntity> grantedAwards;
  final String? awardsError;

  // ── منح جائزة ─────────────────────────────────────────────────────────
  final SubmissionStatus grantStatus;
  final String? grantError;

  // ── توليد شهادة PDF ───────────────────────────────────────────────────
  final SubmissionStatus certificateStatus;

  /// الـ PDF bytes جاهزة للمشاركة/الطباعة من الـ UI
  final List<int>? certificateBytes;
  final String? certificateError;

  const AwardsState({
    this.statsStatus = SectionStatus.initial,
    this.stats,
    this.statsError,
    this.awardsStatus = SectionStatus.initial,
    this.grantedAwards = const [],
    this.awardsError,
    this.grantStatus = SubmissionStatus.idle,
    this.grantError,
    this.certificateStatus = SubmissionStatus.idle,
    this.certificateBytes,
    this.certificateError,
  });

  factory AwardsState.initial() => const AwardsState();

  AwardsState copyWith({
    SectionStatus? statsStatus,
    Object? stats = _unset,
    Object? statsError = _unset,
    SectionStatus? awardsStatus,
    List<GrantedAwardEntity>? grantedAwards,
    Object? awardsError = _unset,
    SubmissionStatus? grantStatus,
    Object? grantError = _unset,
    SubmissionStatus? certificateStatus,
    Object? certificateBytes = _unset,
    Object? certificateError = _unset,
  }) {
    return AwardsState(
      statsStatus: statsStatus ?? this.statsStatus,
      stats: identical(stats, _unset)
          ? this.stats
          : stats as AwardsStatsEntity?,
      statsError: identical(statsError, _unset)
          ? this.statsError
          : statsError as String?,
      awardsStatus: awardsStatus ?? this.awardsStatus,
      grantedAwards: grantedAwards ?? this.grantedAwards,
      awardsError: identical(awardsError, _unset)
          ? this.awardsError
          : awardsError as String?,
      grantStatus: grantStatus ?? this.grantStatus,
      grantError: identical(grantError, _unset)
          ? this.grantError
          : grantError as String?,
      certificateStatus: certificateStatus ?? this.certificateStatus,
      certificateBytes: identical(certificateBytes, _unset)
          ? this.certificateBytes
          : certificateBytes as List<int>?,
      certificateError: identical(certificateError, _unset)
          ? this.certificateError
          : certificateError as String?,
    );
  }

  @override
  List<Object?> get props => [
    statsStatus,
    stats,
    statsError,
    awardsStatus,
    grantedAwards,
    awardsError,
    grantStatus,
    grantError,
    certificateStatus,
    certificateBytes,
    certificateError,
  ];
}
