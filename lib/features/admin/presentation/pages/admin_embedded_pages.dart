import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/data/chat_groups_repository.dart';
import '../../../chat/data/models/chat_models.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/presentation/chat_groups_provider.dart';
import '../../../chat/presentation/media/chat_media_loader.dart';
import '../../../chat/presentation/pages/chat_group_info_page.dart';
import '../../../content/presentation/pages/content_library_page.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../../notifications/presentation/pages/notification_page.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_halaqa_scope.dart';
import '../widgets/admin_subpage_scaffold.dart';

/// Admin chrome wrapper for shared content library.
///
/// Shared content is Halaqa-scoped (P0 §8), so the Admin picks a Halaqa.
class AdminContentPage extends StatelessWidget {
  const AdminContentPage({super.key});

  static Widget libraryFor(String halaqaId) => ContentLibraryPage(
    key: ValueKey(halaqaId),
    halaqaId: halaqaId,
    embeddedInAdmin: true,
  );

  @override
  Widget build(BuildContext context) {
    return AdminHalaqaScopedPage(
      title: 'مكتبة المحتوى',
      subtitle: 'المحتوى المشترك للحلقات',
      scopeHint: 'المحتوى مرتبط بحلقة واحدة ويظهر لأعضائها فقط',
      emptyMessage: 'المحتوى مرتبط بالحلقات، ولا توجد حلقات في الأكاديمية.',
      contentBuilder: libraryFor,
      actions: [
        AdminIconButton(
          key: const Key('open-group-libraries'),
          icon: Icons.groups_2_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminGroupLibrariesPage(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Media, documents and links shared in the Admin's chat groups. Files stay
/// in their messages (by reference); each group's library is members-only.
class AdminGroupLibrariesPage extends StatefulWidget {
  final ChatGroupsRepository? repository;

  /// Opens one group's library; defaults to the group info page.
  final void Function(BuildContext context, ConversationModel group)? onOpen;

  const AdminGroupLibrariesPage({super.key, this.repository, this.onOpen});

  @override
  State<AdminGroupLibrariesPage> createState() =>
      _AdminGroupLibrariesPageState();
}

class _AdminGroupLibrariesPageState extends State<AdminGroupLibrariesPage> {
  late final ChatGroupsRepository _repo =
      widget.repository ?? resolveChatGroupsRepository();
  List<ConversationModel>? _groups;
  String? _error;
  String _uid = '';
  String _role = AppRoles.admin;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      _uid = auth.user.uid;
      _role = auth.user.role;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _groups = null;
      _error = null;
    });
    try {
      final groups = await _repo.myGroups(_uid);
      if (mounted) setState(() => _groups = groups);
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _open(ConversationModel group) {
    final custom = widget.onOpen;
    if (custom != null) return custom(context, group);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatGroupInfoPage(
          conversationId: group.id,
          viewerUid: _uid,
          viewerRole: _role,
          repository: _repo,
          loader: sl<ChatMediaLoader>(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return AdminSubpageScaffold(
      title: 'مكتبات المجموعات',
      subtitle: 'الوسائط والمستندات والروابط داخل كل مجموعة',
      body: _error != null
          ? AppErrorWidget(message: _error!, onRetry: _load)
          : groups == null
          ? const AppLoadingWidget()
          : groups.isEmpty
          ? const AppEmptyState(
              icon: Icons.groups_2_outlined,
              title: 'لا توجد مجموعات',
              message: 'أنشئ مجموعة من صندوق المحادثات لتظهر مكتبتها هنا',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final g = groups[i];
                  final halaqa = g.kind == ConversationKinds.halaqaGroup;
                  return AppCard(
                    key: Key('group-library-${g.id}'),
                    onTap: () => _open(g),
                    child: ListTile(
                      leading: Icon(
                        halaqa ? Icons.menu_book_rounded : Icons.groups_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        g.displayTitle(_uid),
                        style: AppTextStyles.titleMedium,
                      ),
                      subtitle: Text(
                        '${halaqa ? 'مجموعة حلقة' : 'مجموعة مخصصة'} · '
                        '${g.participants.length} عضو',
                        style: AppTextStyles.labelSmall,
                      ),
                      trailing: const Icon(Icons.chevron_left_rounded),
                    ),
                  );
                },
              ),
            ),
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
