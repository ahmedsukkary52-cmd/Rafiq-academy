import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import 'admin_figma_widgets.dart';
import 'admin_subpage_scaffold.dart';

/// Admin view over a Halaqa-scoped feature (posts, shared content).
///
/// These collections have no academy-wide scope (P0 §7 / §8), so the Admin
/// picks one Halaqa from the academy directory; Rules let Admin read and
/// write in any Halaqa.
class AdminHalaqaScopedPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final String scopeHint;
  final String emptyMessage;
  final Widget Function(String halaqaId) contentBuilder;

  const AdminHalaqaScopedPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.scopeHint,
    required this.emptyMessage,
    required this.contentBuilder,
  });

  @override
  State<AdminHalaqaScopedPage> createState() => _AdminHalaqaScopedPageState();
}

class _AdminHalaqaScopedPageState extends State<AdminHalaqaScopedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<AdminBloc>();
      if (bloc.state.halaqatDirectory.isEmpty) {
        bloc.add(const LoadAdminDirectoryEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (p, c) =>
            p.directoryStatus != c.directoryStatus ||
            p.directoryError != c.directoryError ||
            p.halaqatDirectory != c.halaqatDirectory,
        builder: (context, state) => AdminHalaqaScopedBody(
          halaqat: state.halaqatDirectory,
          status: state.directoryStatus,
          error: state.directoryError,
          onRetry: () =>
              context.read<AdminBloc>().add(const LoadAdminDirectoryEvent()),
          scopeHint: widget.scopeHint,
          emptyMessage: widget.emptyMessage,
          contentBuilder: widget.contentBuilder,
        ),
      ),
    );
  }
}

/// Halaqa picker + content scoped to the selected Halaqa.
class AdminHalaqaScopedBody extends StatefulWidget {
  final List<AdminHalaqaSummaryEntity> halaqat;
  final SectionStatus status;
  final String? error;
  final VoidCallback onRetry;
  final String scopeHint;
  final String emptyMessage;
  final Widget Function(String halaqaId) contentBuilder;

  const AdminHalaqaScopedBody({
    super.key,
    required this.halaqat,
    required this.status,
    required this.error,
    required this.onRetry,
    required this.scopeHint,
    required this.emptyMessage,
    required this.contentBuilder,
  });

  @override
  State<AdminHalaqaScopedBody> createState() => _AdminHalaqaScopedBodyState();
}

class _AdminHalaqaScopedBodyState extends State<AdminHalaqaScopedBody> {
  String? _halaqaId;

  @override
  Widget build(BuildContext context) {
    final halaqat = widget.halaqat;
    if (halaqat.isEmpty) {
      if (widget.status == SectionStatus.error) {
        return AppErrorWidget(
          message: widget.error ?? 'تعذر تحميل الحلقات',
          onRetry: widget.onRetry,
        );
      }
      if (widget.status == SectionStatus.loaded) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: AdminPlaceholderCard(
            icon: Icons.groups_outlined,
            title: 'لا حلقات',
            message: widget.emptyMessage,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final selectedId = _resolveSelected(halaqat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DropdownButtonFormField<String>(
            key: ValueKey('admin-halaqa-scope-$selectedId'),
            initialValue: selectedId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الحلقة',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final h in halaqat)
                DropdownMenuItem(
                  value: h.id,
                  child: Text(h.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              setState(() => _halaqaId = id);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            widget.scopeHint,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
          ),
        ),
        Expanded(child: widget.contentBuilder(selectedId)),
      ],
    );
  }

  String _resolveSelected(List<AdminHalaqaSummaryEntity> halaqat) {
    final current = _halaqaId;
    if (current != null && halaqat.any((h) => h.id == current)) {
      return current;
    }
    return halaqat.first.id;
  }
}
