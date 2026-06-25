import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/analytics_entities.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class AnalyticsState extends Equatable {
  final SectionStatus analyticsStatus;
  final HalaqaAnalyticsEntity? analytics;
  final String? analyticsError;

  final SectionStatus atRiskStatus;
  final List<AtRiskStudentEntity> atRiskStudents;
  final String? atRiskError;

  final SectionStatus topStudentsStatus;
  final List<TopStudentEntity> topStudents;
  final String? topStudentsError;

  const AnalyticsState({
    this.analyticsStatus = SectionStatus.initial,
    this.analytics,
    this.analyticsError,
    this.atRiskStatus = SectionStatus.initial,
    this.atRiskStudents = const [],
    this.atRiskError,
    this.topStudentsStatus = SectionStatus.initial,
    this.topStudents = const [],
    this.topStudentsError,
  });

  factory AnalyticsState.initial() => const AnalyticsState();

  bool get isFullyLoaded =>
      analyticsStatus == SectionStatus.loaded &&
      atRiskStatus == SectionStatus.loaded &&
      topStudentsStatus == SectionStatus.loaded;

  AnalyticsState copyWith({
    SectionStatus? analyticsStatus,
    Object? analytics = _unset,
    Object? analyticsError = _unset,
    SectionStatus? atRiskStatus,
    List<AtRiskStudentEntity>? atRiskStudents,
    Object? atRiskError = _unset,
    SectionStatus? topStudentsStatus,
    List<TopStudentEntity>? topStudents,
    Object? topStudentsError = _unset,
  }) {
    return AnalyticsState(
      analyticsStatus: analyticsStatus ?? this.analyticsStatus,
      analytics: identical(analytics, _unset)
          ? this.analytics
          : analytics as HalaqaAnalyticsEntity?,
      analyticsError: identical(analyticsError, _unset)
          ? this.analyticsError
          : analyticsError as String?,
      atRiskStatus: atRiskStatus ?? this.atRiskStatus,
      atRiskStudents: atRiskStudents ?? this.atRiskStudents,
      atRiskError: identical(atRiskError, _unset)
          ? this.atRiskError
          : atRiskError as String?,
      topStudentsStatus: topStudentsStatus ?? this.topStudentsStatus,
      topStudents: topStudents ?? this.topStudents,
      topStudentsError: identical(topStudentsError, _unset)
          ? this.topStudentsError
          : topStudentsError as String?,
    );
  }

  @override
  List<Object?> get props => [
    analyticsStatus,
    analytics,
    analyticsError,
    atRiskStatus,
    atRiskStudents,
    atRiskError,
    topStudentsStatus,
    topStudents,
    topStudentsError,
  ];
}
