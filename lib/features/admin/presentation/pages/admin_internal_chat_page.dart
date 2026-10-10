import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/chat_route_extra.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

/// Admin internal group chat — replaces standalone internal notes (Q5).
class AdminInternalChatPage extends StatefulWidget {
  const AdminInternalChatPage({super.key});

  @override
  State<AdminInternalChatPage> createState() => _AdminInternalChatPageState();
}

class _AdminInternalChatPageState extends State<AdminInternalChatPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        context.read<AdminBloc>().add(
          EnsureAdminInternalChatEvent(adminUid: auth.user.uid),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (p, c) =>
          p.adminInternalChatStatus != c.adminInternalChatStatus,
      listener: (context, state) {
        if (state.adminInternalChatStatus == SubmissionStatus.success &&
            state.adminInternalChatId != null) {
          context.pushReplacement(
            '${AppRoutes.admin}/chat/${state.adminInternalChatId}',
            extra: {ChatRouteExtra.nameKey: 'مجموعة الإدارة'},
          );
        } else if (state.adminInternalChatStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.adminInternalChatError ?? 'تعذر فتح المجموعة',
          );
        }
      },
      child: const AdminSubpageScaffold(
        title: 'مجموعة الإدارة',
        subtitle: 'تواصل داخلي بين فريق الإدارة',
        body: AdminFlowBootstrapSkeleton(),
      ),
    );
  }
}

/// Legacy route alias — redirects to group chat flow.
class AdminInternalNotesPage extends AdminInternalChatPage {
  const AdminInternalNotesPage({super.key});
}
