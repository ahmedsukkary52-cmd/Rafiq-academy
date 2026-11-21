import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/presentation/bloc_status.dart';
import '../../../shared/domain/student_parent_links.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../../chat/domain/entities/chat_entities.dart';
import '../../chat/domain/usecases/chat_usecases.dart';
import '../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../chat/presentation/bloc/chat_conversations_event.dart';

/// Staff roles offered "contact parent" on a student surface. UX pre-filter
/// only: `createDirectConversation` enforces the parent relationship (D14).
bool staffCanContactStudentParent(String role) =>
    role == AppRoles.teacher ||
    role == AppRoles.supervisor ||
    role == AppRoles.admin;

/// Router path of a parent conversation for [role], or null when the role has
/// no chat route and opens the room in-feature (supervisor).
String? staffParentChatRoute(String role, String conversationId) =>
    switch (role) {
      AppRoles.teacher => '/teacher/chat/$conversationId',
      AppRoles.admin => '/admin/chat/$conversationId',
      _ => null,
    };

typedef ParentChatRoomBuilder =
    Widget Function(
      ConversationEntity conversation,
      ChatParticipantEntity parent,
    );

/// Supplied by the caller so this module stays outside the DI composition
/// root, which imports every role module.
class StaffParentContactDeps {
  final StudentParentLinkReader parentLinks;
  final GetChatParticipantUseCase getParticipant;
  final ChatConversationsBloc chatBloc;
  final ParentChatRoomBuilder chatRoom;

  const StaffParentContactDeps({
    required this.parentLinks,
    required this.getParticipant,
    required this.chatBloc,
    required this.chatRoom,
  });
}

/// Staff → parent chat for the signed-in role: starts the existing
/// conversation use case, then opens it on the role's own chat surface.
///
/// When multiple parents are linked, the user picks which parent to contact.
Future<void> contactStudentParent({
  required BuildContext context,
  required String studentId,
  required StaffParentContactDeps deps,
}) async {
  try {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }
    final role = auth.user.role;
    if (!staffCanContactStudentParent(role)) {
      AppSnackBar.showInfo(context, 'غير مسموح بفتح هذه المحادثة');
      return;
    }

    final parentsEither = await deps.parentLinks.getParentIdsByStudentIds([
      studentId,
    ]);
    if (!context.mounted) return;

    final parentIds = parentsEither.fold<List<String>?>((_) {
      AppSnackBar.showInfo(
        context,
        'تعذر التحقق من ولي الأمر حالياً. حاول مرة أخرى.',
      );
      return null;
    }, (map) => map[studentId] ?? const <String>[]);
    if (parentIds == null) return;
    final uniqueParentIds = parentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueParentIds.isEmpty) {
      AppSnackBar.showInfo(context, 'لا يوجد ولي أمر مرتبط بهذا الطالب');
      return;
    }

    final parent = await _resolveParentParticipant(
      context: context,
      parentIds: uniqueParentIds,
      deps: deps,
    );
    if (parent == null || !context.mounted) return;

    final chatBloc = deps.chatBloc;
    chatBloc.add(const ResetStartConversationEvent());
    chatBloc.add(
      StartConversationEvent(
        currentUser: ChatParticipantEntity(
          uid: auth.user.uid,
          name: auth.user.name,
          role: role,
          profileImageUrl: auth.user.profileImageUrl,
        ),
        otherUser: parent,
      ),
    );

    final state = await chatBloc.stream.firstWhere(
      (s) =>
          s.startConversationStatus == SubmissionStatus.success ||
          s.startConversationStatus == SubmissionStatus.error,
    );
    if (!context.mounted) return;
    if (state.startConversationStatus == SubmissionStatus.error ||
        state.startedConversation == null) {
      AppSnackBar.showInfo(
        context,
        'تعذر فتح محادثة ولي الأمر حالياً. حاول مرة أخرى.',
      );
      return;
    }

    final conversation = state.startedConversation!;
    final route = staffParentChatRoute(role, conversation.id);
    if (route != null) {
      context.push(
        route,
        extra: {'name': parent.name, 'imageUrl': parent.profileImageUrl},
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => deps.chatRoom(conversation, parent),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    AppSnackBar.showInfo(
      context,
      'تعذر التواصل مع ولي الأمر حالياً. حاول مرة أخرى.',
    );
  }
}

Future<ChatParticipantEntity?> _resolveParentParticipant({
  required BuildContext context,
  required List<String> parentIds,
  required StaffParentContactDeps deps,
}) async {
  if (parentIds.length == 1) {
    final parentEither = await deps.getParticipant(
      ChatUidParams(parentIds.first),
    );
    if (!context.mounted) return null;
    return parentEither.fold<ChatParticipantEntity?>((_) {
      AppSnackBar.showInfo(
        context,
        'تعذر فتح محادثة ولي الأمر حالياً. حاول مرة أخرى.',
      );
      return null;
    }, (p) => p);
  }

  final results = await Future.wait(
    parentIds.map((uid) => deps.getParticipant(ChatUidParams(uid))),
  );
  if (!context.mounted) return null;

  final parents = <ChatParticipantEntity>[];
  for (final either in results) {
    either.fold((_) {}, parents.add);
  }
  if (parents.isEmpty) {
    AppSnackBar.showInfo(
      context,
      'تعذر فتح محادثة ولي الأمر حالياً. حاول مرة أخرى.',
    );
    return null;
  }
  if (parents.length == 1) return parents.first;

  parents.sort((a, b) => a.name.compareTo(b.name));
  return showModalBottomSheet<ChatParticipantEntity>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 12, 8, bottom + 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'اختر ولي الأمر',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final p in parents)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        p.name.isNotEmpty ? p.name[0] : '؟',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: const Text('ولي أمر'),
                    onTap: () => Navigator.of(ctx).pop(p),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
