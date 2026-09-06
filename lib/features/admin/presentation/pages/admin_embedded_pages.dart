import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../content/presentation/pages/content_library_page.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../../notifications/presentation/pages/notification_page.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_figma_widgets.dart';

/// Admin chrome wrapper for shared content library.
class AdminContentPage extends StatelessWidget {
  const AdminContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'مكتبة المحتوى',
      subtitle: 'ملفات ومواد الأكاديمية',
      body: const ContentLibraryPage(embeddedInAdmin: true),
    );
  }
}

class _AdminMarkAllReadAction extends StatelessWidget {
  const _AdminMarkAllReadAction();

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<NotificationsBloc>(),
      child: BlocSelector<NotificationsBloc, NotificationsState, bool>(
        selector: (state) => state.unreadCount > 0,
        builder: (context, hasUnread) {
          return AdminIconButton(
            icon: Icons.done_all_rounded,
            onTap: hasUnread
                ? () => context.read<NotificationsBloc>().add(
                    const MarkAllNotificationsAsReadEvent(),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// Admin chrome wrapper for shared notifications inbox.
class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'صندوق الإشعارات',
      subtitle: 'تنبيهات الأكاديمية',
      actions: const [_AdminMarkAllReadAction()],
      body: const NotificationsPage(embeddedInAdmin: true),
    );
  }
}
