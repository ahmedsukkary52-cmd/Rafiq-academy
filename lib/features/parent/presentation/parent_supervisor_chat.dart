import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/presentation/bloc_status.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../../chat/domain/entities/chat_entities.dart';
import '../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../chat/presentation/bloc/chat_conversations_state.dart';
import '../domain/parent_household.dart';
import 'bloc/parent_bloc.dart';
import 'parent_destinations.dart';

/// Shared helper: open (or create) a 1:1 parent↔supervisor chat for [child].
mixin ParentSupervisorChatMixin<T extends StatefulWidget> on State<T> {
  bool parentSupervisorChatBusy = false;

  Future<void> startParentSupervisorChat(ParentChildSnapshot child) async {
    final auth = context.read<AuthBloc>().state;
    final supervisorId = (child.supervisorId ?? '').trim();
    if (auth is! AuthAuthenticated || parentSupervisorChatBusy) return;
    if (supervisorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مشرف مرتبط بهذا الابن')),
      );
      return;
    }

    final staff = context.read<ParentBloc>().state.staffContacts;
    ParentStaffContact? contact;
    for (final item in staff) {
      if (item.uid == supervisorId) {
        contact = item;
        break;
      }
    }
    contact ??= ParentStaffContact(
      uid: supervisorId,
      name: child.supervisorName.trim().isEmpty
          ? 'المشرف'
          : child.supervisorName.trim(),
      role: AppRoles.supervisor,
    );

    setState(() => parentSupervisorChatBusy = true);
    final conversations = sl<ChatConversationsBloc>().state.conversations;
    for (final conversation in conversations) {
      final other = conversation.otherParticipant(auth.user.uid);
      if (other.uid == contact.uid) {
        setState(() => parentSupervisorChatBusy = false);
        if (!mounted) return;
        await ParentDestinations.chat(
          context,
          conversationId: conversation.id,
          title: other.name.trim().isEmpty ? contact.name : other.name,
          imageUrl: other.profileImageUrl ?? contact.profileImageUrl,
        );
        return;
      }
    }

    sl<ChatConversationsBloc>().add(const ResetStartConversationEvent());
    sl<ChatConversationsBloc>().add(
      StartConversationEvent(
        currentUser: ChatParticipantEntity(
          uid: auth.user.uid,
          name: auth.user.name,
          role: AppRoles.parent,
          profileImageUrl: auth.user.profileImageUrl,
        ),
        otherUser: ChatParticipantEntity(
          uid: contact.uid,
          name: contact.name,
          role: contact.role,
          profileImageUrl: contact.profileImageUrl,
        ),
      ),
    );
  }

  /// Wire once in [build] around the page that starts supervisor chats.
  Widget wrapParentSupervisorChatListener({
    required String currentUid,
    required Widget child,
  }) {
    return BlocListener<ChatConversationsBloc, ChatConversationsState>(
      bloc: sl<ChatConversationsBloc>(),
      listenWhen: (p, c) =>
          p.startConversationStatus != c.startConversationStatus,
      listener: (context, state) async {
        if (!parentSupervisorChatBusy) return;
        if (state.startConversationStatus == SubmissionStatus.error) {
          setState(() => parentSupervisorChatBusy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.startConversationError ?? 'تعذر بدء المحادثة',
              ),
            ),
          );
          return;
        }
        if (state.startConversationStatus == SubmissionStatus.success &&
            state.startedConversation != null) {
          final conversation = state.startedConversation!;
          sl<ChatConversationsBloc>().add(const ResetStartConversationEvent());
          setState(() => parentSupervisorChatBusy = false);
          final other = conversation.otherParticipant(currentUid);
          if (!mounted) return;
          await ParentDestinations.chat(
            context,
            conversationId: conversation.id,
            title: other.name,
            imageUrl: other.profileImageUrl,
          );
        }
      },
      child: child,
    );
  }
}
