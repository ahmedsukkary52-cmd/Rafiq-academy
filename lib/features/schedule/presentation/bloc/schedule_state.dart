part of 'schedule_bloc.dart';

class ScheduleState extends Equatable {
  final SectionStatus status;
  final List<ClassSessionEntity> sessions;
  final String? halaqaId;
  final String? errorMessage;

  const ScheduleState({
    this.status = SectionStatus.initial,
    this.sessions = const [],
    this.halaqaId,
    this.errorMessage,
  });

  ClassSessionEntity? get featuredSession {
    final live = sessions.where((s) => s.status == ClassSessionStatus.live);
    if (live.isNotEmpty) return live.first;
    final upcoming = sessions.where(
      (s) => s.status == ClassSessionStatus.upcoming,
    );
    if (upcoming.isNotEmpty) return upcoming.first;
    return sessions.isNotEmpty ? sessions.first : null;
  }

  ScheduleState copyWith({
    SectionStatus? status,
    List<ClassSessionEntity>? sessions,
    String? halaqaId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScheduleState(
      status: status ?? this.status,
      sessions: sessions ?? this.sessions,
      halaqaId: halaqaId ?? this.halaqaId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, sessions, halaqaId, errorMessage];
}
