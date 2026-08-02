import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/usecases/get_student_halaqa_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../../student/presentation/bloc/student_bloc.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../bloc/chat_conversations_bloc.dart';
import '../bloc/chat_conversations_event.dart';
import '../bloc/chat_conversations_state.dart';

/// بوابة شات الطالب: تحدد معلم الحلقة → GetOrCreateConversation → تفتح ChatRoom.
///
/// مصدر المعلم: `studentProfiles.halaqaId` → `halaqat.teacherId`
/// (fallback: `assignments.assignedBy` لو الحلقة بدون teacherId).
class StudentChatPage extends StatefulWidget {
  const StudentChatPage({super.key});

  @override
  State<StudentChatPage> createState() => _StudentChatPageState();
}

class _StudentChatPageState extends State<StudentChatPage> {
  String? _error;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() => _error = null);

    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      setState(() => _error = 'يجب تسجيل الدخول أولاً');
      return;
    }

    final studentState = context.read<StudentBloc>().state;
    final profile = studentState.profile;

    String? teacherUid = studentState.halaqa?.teacherId;
    if (teacherUid == null || teacherUid.isEmpty) {
      final halaqaId = profile?.halaqaId;
      if (halaqaId != null && halaqaId.isNotEmpty) {
        final halaqaResult = await sl<GetStudentHalaqaUseCase>()(
          HalaqaIdParams(halaqaId),
        );
        halaqaResult.fold((f) => null, (h) => teacherUid = h.teacherId);
      }
    }

    // Fallback أضعف: آخر تكليف
    if (teacherUid == null || teacherUid!.isEmpty) {
      final assignedBy = studentState.latestAssignment?.assignedBy;
      if (assignedBy != null && assignedBy.isNotEmpty) {
        teacherUid = assignedBy;
      }
    }

    if (teacherUid == null || teacherUid!.isEmpty) {
      setState(() {
        _error = profile?.halaqaId == null || profile!.halaqaId!.isEmpty
            ? 'لم يتم تعيينك لحلقة بعد — تواصل مع الإدارة'
            : 'تعذّر تحديد معلم الحلقة';
      });
      return;
    }

    final teacherResult = await sl<GetChatParticipantUseCase>()(
      ChatUidParams(teacherUid!),
    );
    final teacher = teacherResult.fold<ChatParticipantEntity?>((f) {
      setState(() => _error = f.message);
      return null;
    }, (p) => p);
    if (teacher == null || !mounted) return;

    final currentUser = ChatParticipantEntity(
      uid: auth.user.uid,
      name: auth.user.name,
      role: AppRoles.student,
      profileImageUrl: auth.user.profileImageUrl,
    );

    final bloc = sl<ChatConversationsBloc>();
    bloc.add(const ResetStartConversationEvent());
    bloc.add(
      StartConversationEvent(currentUser: currentUser, otherUser: teacher),
    );
  }

  void _openRoom(ConversationEntity conversation, String currentUid) {
    if (_navigated || !mounted) return;
    _navigated = true;
    final other = conversation.otherParticipant(currentUid);
    context.pushReplacement(
      AppRoutes.studentChatRoom.replaceFirst(
        ':conversationId',
        conversation.id,
      ),
      extra: {'name': other.name, 'image': other.profileImageUrl},
    );
    sl<ChatConversationsBloc>().add(const ResetStartConversationEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatConversationsBloc, ChatConversationsState>(
      bloc: sl<ChatConversationsBloc>(),
      listenWhen: (prev, curr) =>
          prev.startConversationStatus != curr.startConversationStatus,
      listener: (context, state) {
        if (state.startConversationStatus == SubmissionStatus.error) {
          setState(() {
            _error = state.startConversationError ?? 'فشل فتح المحادثة';
          });
          return;
        }
        if (state.startConversationStatus == SubmissionStatus.success &&
            state.startedConversation != null) {
          final auth = context.read<AuthBloc>().state;
          final uid = auth is AuthAuthenticated ? auth.user.uid : '';
          _openRoom(state.startedConversation!, uid);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('محادثة المعلم')),
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingL),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 56,
                        color: AppColors.textHint.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          _navigated = false;
                          _bootstrap();
                        },
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLoadingWidget(),
                    const SizedBox(height: 16),
                    Text(
                      'جاري فتح محادثة معلمك...',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
