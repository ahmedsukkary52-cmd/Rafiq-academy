import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/repositories/parent_repository.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

class SupervisorTeachersPage extends StatefulWidget {
  const SupervisorTeachersPage({super.key});

  @override
  State<SupervisorTeachersPage> createState() => _SupervisorTeachersPageState();
}

class _SupervisorTeachersPageState extends State<SupervisorTeachersPage> {
  bool _loading = false;
  String? _error;
  Map<String, String> _names = const {};
  List<_TeacherRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
    final byTeacher = <String, List<String>>{};
    for (final h in halaqat) {
      final tid = h.teacherId.trim();
      if (tid.isEmpty) continue;
      byTeacher.putIfAbsent(tid, () => []).add(h.name);
    }
    final ids = byTeacher.keys.toList()..sort();
    final rows = [
      for (final id in ids)
        _TeacherRow(teacherId: id, halaqaNames: byTeacher[id] ?? const []),
    ];

    if (ids.isEmpty) {
      setState(() {
        _rows = const [];
        _names = const {};
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _rows = rows;
    });

    final result = await sl<SupervisorRepository>().getUserDisplayNames(ids);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (names) => setState(() {
        _loading = false;
        _names = names;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'المعلمون',
      body: BlocListener<SupervisorBloc, SupervisorState>(
        listenWhen: (p, c) => p.halaqat != c.halaqat,
        listener: (_, __) => _resolve(),
        child: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (p, c) => p.halaqat != c.halaqat,
          builder: (context, state) {
            if (state.halaqat.isEmpty) {
              return Center(
                child: Text(
                  'لا توجد حلقات ضمن إشرافك',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              );
            }
            if (_loading && _names.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null && _rows.isEmpty) {
              return AppErrorWidget(message: _error!, onRetry: _resolve);
            }
            if (_rows.isEmpty) {
              return Center(
                child: Text(
                  'لا يوجد معلمون مرتبطون',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final row = _rows[i];
                final name = (_names[row.teacherId] ?? '').trim();
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'معلم' : name,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row.halaqaNames.join(' · '),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TeacherRow {
  final String teacherId;
  final List<String> halaqaNames;

  const _TeacherRow({required this.teacherId, required this.halaqaNames});
}
