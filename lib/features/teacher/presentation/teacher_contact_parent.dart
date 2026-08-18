import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/presentation/bloc_status.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../../chat/domain/entities/chat_entities.dart';
import '../../chat/domain/usecases/chat_usecases.dart';
import '../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../parent/domain/repositories/parent_repositories.dart';

/// Teacher → parent chat, same flow as Class Details.
/// Does not change Chat internals; starts the existing conversation use case.
Future<void> contactStudentParent({
  required BuildContext context,
  required String studentId,
}) async {
  try {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    final parentsEither =
        await sl<ParentRepository>().getParentIdsByStudentIds([studentId]);
    if (!context.mounted) return;

    final parentIds = parentsEither.fold<List<String>?>(
      (_) {
        AppSnackBar.showInfo(
          context,
          'تعذر التحقق من ولي الأمر حالياً. حاول مرة أخرى.',
        );
        return null;
      },
      (map) => map[studentId] ?? const <String>[],
    );
    if (parentIds == null) return;
    if (parentIds.isEmpty) {
      AppSnackBar.showInfo(
        context,
        'لا يوجد ولي أمر مرتبط بهذا الطالب',
      );
      return;
    }

    final parentEither = await sl<GetChatParticipantUseCase>()(
      ChatUidParams(parentIds.first),
    );
    if (!context.mounted) return;
    final parent = parentEither.fold<ChatParticipantEntity?>((_) {
      AppSnackBar.showInfo(
        context,
        'تعذر فتح محادثة ولي الأمر حالياً. حاول مرة أخرى.',
      );
      return null;
    }, (p) => p);
    if (parent == null) return;

    final chatBloc = sl<ChatConversationsBloc>();
    chatBloc.add(const ResetStartConversationEvent());
    chatBloc.add(
      StartConversationEvent(
        currentUser: ChatParticipantEntity(
          uid: auth.user.uid,
          name: auth.user.name,
          role: auth.user.role,
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
    context.push(
      '/teacher/chat/${conversation.id}',
      extra: {
        'name': parent.name,
        'imageUrl': parent.profileImageUrl,
      },
    );
  } catch (_) {
    if (!context.mounted) return;
    AppSnackBar.showInfo(
      context,
      'تعذر التواصل مع ولي الأمر حالياً. حاول مرة أخرى.',
    );
  }
}
