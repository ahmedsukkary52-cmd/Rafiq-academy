import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/student_chat_teacher.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../bloc/chat_conversations_bloc.dart';
import '../bloc/chat_conversations_event.dart';
import '../bloc/chat_conversations_state.dart';

/// بوابة شات الطالب: تحدد معلم الحلقة → GetOrCreateConversation → تفتح ChatRoom.
///
/// The teacher comes from [teacherResolver], supplied by the caller.
class StudentChatPage extends StatefulWidget {
  final StudentChatTeacherResolver teacherResolver;

  const StudentChatPage({super.key, required this.teacherResolver});

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

    final resolved = await widget.teacherResolver.resolveTeacher();
    final teacherUid = resolved.teacherUid;
    if (teacherUid == null || teacherUid.isEmpty) {
      setState(() {
        _error = resolved.hasHalaqa
            ? 'تعذّر تحديد معلم الحلقة'
            : 'لم يتم تعيينك لحلقة بعد — تواصل مع الإدارة';
      });
      return;
    }

    final teacherResult = await sl<GetChatParticipantUseCase>()(
      ChatUidParams(teacherUid),
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
    bloc.add(StartWatchingConversationsEvent(auth.user.uid));
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
      extra: <String, String?>{
        'name': other.name,
        'image': other.profileImageUrl,
      },
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
              : const _StudentChatOpeningSkeleton(),
        ),
      ),
    );
  }
}

class _StudentChatOpeningSkeleton extends StatefulWidget {
  const _StudentChatOpeningSkeleton();

  @override
  State<_StudentChatOpeningSkeleton> createState() =>
      _StudentChatOpeningSkeletonState();
}

class _StudentChatOpeningSkeletonState
    extends State<_StudentChatOpeningSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.35,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final bone = AppColors.border.withValues(alpha: _pulse.value);
        Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: bone,
            borderRadius: BorderRadius.circular(6),
          ),
        );
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 28, backgroundColor: bone),
              const SizedBox(height: 20),
              bar(160, 14),
              const SizedBox(height: 12),
              bar(220, 12),
              const SizedBox(height: 8),
              bar(180, 12),
            ],
          ),
        );
      },
    );
  }
}
