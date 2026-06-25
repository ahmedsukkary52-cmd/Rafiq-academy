import 'package:equatable/equatable.dart';

abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل كل لوحة التحليلات دفعة واحدة (analytics + at-risk + top students)
class LoadHalaqaAnalyticsDashboardEvent extends AnalyticsEvent {
  final String halaqaId;
  final DateTime from;
  final DateTime to;

  const LoadHalaqaAnalyticsDashboardEvent({
    required this.halaqaId,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [halaqaId, from, to];
}

/// إعادة تحميل (pull-to-refresh)
class RefreshAnalyticsEvent extends AnalyticsEvent {
  final String halaqaId;

  const RefreshAnalyticsEvent(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}
