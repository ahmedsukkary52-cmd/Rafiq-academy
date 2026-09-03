import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../post/presentation/pages/posts_list_page.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

/// Scoped announcements for assigned halaqat — reuses Posts (one halaqa at a time).
/// Does not use academy-wide [PostAudience.allHalaqat].
class SupervisorAnnouncementsPage extends StatefulWidget {
  const SupervisorAnnouncementsPage({super.key});

  @override
  State<SupervisorAnnouncementsPage> createState() =>
      _SupervisorAnnouncementsPageState();
}

class _SupervisorAnnouncementsPageState
    extends State<SupervisorAnnouncementsPage> {
  String? _halaqaId;

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'الإعلانات',
      body: BlocBuilder<SupervisorBloc, SupervisorState>(
        buildWhen: (p, c) => p.halaqat != c.halaqat,
        builder: (context, state) {
          final halaqat = state.halaqat;
          if (halaqat.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: AppCard(
                child: Text(
                  'لا توجد حلقات مسندة لعرض إعلاناتها',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final selectedId = _resolveSelected(halaqat);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('ann-$selectedId'),
                  initialValue: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'الحلقة',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final h in halaqat)
                      DropdownMenuItem(value: h.id, child: Text(h.name)),
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
                  'الإعلانات مرتبطة بحلقة واحدة — لا تُنشر على كل الأكاديمية',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
              Expanded(
                child: PostsListPage(
                  key: ValueKey(selectedId),
                  halaqaId: selectedId,
                  embedded: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _resolveSelected(List<HalaqaEntity> halaqat) {
    final current = _halaqaId;
    if (current != null && halaqat.any((h) => h.id == current)) {
      return current;
    }
    return halaqat.first.id;
  }
}
