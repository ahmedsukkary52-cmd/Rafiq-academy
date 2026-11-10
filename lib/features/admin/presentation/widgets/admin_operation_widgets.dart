import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/domain/halaqa_entity.dart';
import '../../domain/entities/admin_operations_entities.dart';
import '../bloc/admin_operations_bloc.dart';

/// Page shell for Admin operational subpages: page-scoped
/// [AdminOperationsBloc], directory load, and one snackbar channel for
/// callable outcomes.
class AdminOperationsScaffold extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context, AdminOperationsState state)
  builder;

  const AdminOperationsScaffold({
    super.key,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminOperationsBloc>(
      create: (_) =>
          sl<AdminOperationsBloc>()..add(const LoadAdminDirectoryEvent()),
      child: BlocConsumer<AdminOperationsBloc, AdminOperationsState>(
        listenWhen: (p, c) =>
            p.submissionStatus != c.submissionStatus &&
            (c.submissionStatus == SubmissionStatus.success ||
                c.submissionStatus == SubmissionStatus.error),
        listener: (context, state) {
          final message = state.message;
          if (message != null && message.isNotEmpty) {
            if (state.submissionStatus == SubmissionStatus.success) {
              AppSnackBar.showSuccess(context, message);
            } else {
              AppSnackBar.showError(context, message);
            }
          }
          context.read<AdminOperationsBloc>().add(
            const ClearAdminOperationMessageEvent(),
          );
        },
        builder: (context, state) {
          final Widget body = switch (state.directoryStatus) {
            SectionStatus.initial ||
            SectionStatus.loading => const AppLoadingWidget(),
            SectionStatus.error => AppErrorWidget(
              message: state.directoryError ?? 'تعذر تحميل البيانات',
              onRetry: () => context.read<AdminOperationsBloc>().add(
                const LoadAdminDirectoryEvent(),
              ),
            ),
            SectionStatus.loaded => builder(context, state),
          };
          return AppSubpageScaffold(title: title, body: body);
        },
      ),
    );
  }
}

class AdminSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const AdminSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class AdminUserDropdown extends StatelessWidget {
  final String label;
  final List<AdminDirectoryUser> users;
  final String? value;
  final ValueChanged<String?> onChanged;

  const AdminUserDropdown({
    super.key,
    required this.label,
    required this.users,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = users.any((u) => u.uid == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final u in users)
          DropdownMenuItem(
            value: u.uid,
            child: Text(
              u.isActive ? u.displayName : '${u.displayName} (موقوف)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class AdminHalaqaDropdown extends StatelessWidget {
  final String label;
  final List<HalaqaEntity> halaqat;
  final String? value;
  final ValueChanged<String?> onChanged;

  const AdminHalaqaDropdown({
    super.key,
    required this.label,
    required this.halaqat,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = halaqat.any((h) => h.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final h in halaqat)
          DropdownMenuItem(
            value: h.id,
            child: Text(
              h.name.trim().isEmpty ? h.id : h.name.trim(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class AdminSubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AdminSubmitButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final submitting = context.select<AdminOperationsBloc, bool>(
      (b) => b.state.submissionStatus == SubmissionStatus.submitting,
    );
    return AppButton(
      label: label,
      isLoading: submitting,
      onPressed: submitting ? null : onPressed,
    );
  }
}
