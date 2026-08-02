import 'package:equatable/equatable.dart';

import 'teacher_day_agenda.dart';
import 'teacher_recent_activity.dart';

/// Single Home derivation result: W3 agenda + recent activity feed.
class TeacherHomeFeed extends Equatable {
  final TeacherDayAgenda agenda;
  final List<TeacherRecentActivity> recentActivities;

  const TeacherHomeFeed({
    required this.agenda,
    required this.recentActivities,
  });

  static const empty = TeacherHomeFeed(
    agenda: TeacherDayAgenda.empty,
    recentActivities: [],
  );

  @override
  List<Object?> get props => [agenda, recentActivities];
}
