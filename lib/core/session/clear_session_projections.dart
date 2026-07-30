import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/admin/presentation/bloc/admin_bloc.dart';
import '../../features/admin/presentation/bloc/admin_event.dart';
import '../../features/chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../features/chat/presentation/bloc/chat_conversations_event.dart';
import '../../features/notifications/presentation/bloc/notifications_bloc.dart';
import '../../features/notifications/presentation/bloc/notifications_event.dart';
import '../../features/parent/presentation/bloc/parent_bloc.dart';
import '../../features/parent/presentation/bloc/parent_event.dart';
import '../../features/post/presentation/bloc/posts_bloc.dart';
import '../../features/post/presentation/bloc/posts_event.dart';
import '../../features/student/presentation/bloc/student_bloc.dart';
import '../../features/student/presentation/bloc/student_event.dart';
import '../../features/supervisor/presentation/bloc/supervisor_bloc.dart';
import '../../features/supervisor/presentation/bloc/supervisor_event.dart';
import '../../features/teacher/presentation/bloc/teacher_bloc.dart';
import '../../features/teacher/presentation/bloc/teacher_event.dart';

/// Clears all `@singleton` role/capability projections on logout (H1 / A-H1).
///
/// Auth identity is owned by [AuthBloc]; this only resets in-memory
/// projections so the next account never inherits prior role state.
void clearSessionProjections(BuildContext context) {
  context.read<NotificationsBloc>().add(
    const StopWatchingNotificationsEvent(),
  );
  context.read<StudentBloc>().add(const ClearStudentSessionEvent());
  context.read<TeacherBloc>().add(const ClearTeacherSessionEvent());
  context.read<ParentBloc>().add(const ClearParentSessionEvent());
  context.read<SupervisorBloc>().add(const ClearSupervisorSessionEvent());
  context.read<AdminBloc>().add(const ClearAdminSessionEvent());
  context.read<ChatConversationsBloc>().add(
    const ClearChatConversationsSessionEvent(),
  );
  context.read<PostsBloc>().add(const ClearPostsSessionEvent());
}
