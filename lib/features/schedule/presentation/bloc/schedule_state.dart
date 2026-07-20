part of 'schedule_bloc.dart';

class ScheduleState extends Equatable {
  final SectionStatus status;
  final List<ClassSessionEntity> sessions;
  final String? errorMessage;

  const ScheduleState({
    this.status = SectionStatus.initial,
    this.sessions = const [],
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
    String? errorMessage,
  }) {
    return ScheduleState(
      status: status ?? this.status,
      sessions: sessions ?? this.sessions,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, sessions, errorMessage];
}
