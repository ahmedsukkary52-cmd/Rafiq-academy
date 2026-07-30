import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';

/// Shared logout confirmation used by role shells that expose logout (P-E1).
Future<void> confirmAndLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تسجيل الخروج'),
      content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('تسجيل الخروج'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    context.read<AuthBloc>().add(const LogoutEvent());
  }
}
