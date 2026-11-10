import 'package:flutter/material.dart';

import '../../../post/presentation/pages/posts_list_page.dart';
import '../widgets/admin_halaqa_scope.dart';

/// Figma: مركز الإعلانات.
///
/// Posts are Halaqa-scoped (P0 §7, `firestore.rules` `/posts`): there is no
/// academy-wide feed, so the Admin reviews and posts one Halaqa at a time.
class AdminAnnouncementsPage extends StatelessWidget {
  const AdminAnnouncementsPage({super.key});

  static Widget feedFor(String halaqaId) => PostsListPage(
    key: ValueKey(halaqaId),
    halaqaId: halaqaId,
    embedded: true,
  );

  @override
  Widget build(BuildContext context) {
    return const AdminHalaqaScopedPage(
      title: 'مركز الإعلانات',
      subtitle: 'منشورات الحلقات',
      scopeHint: 'الإعلانات مرتبطة بحلقة واحدة — لا تُنشر على كل الأكاديمية',
      emptyMessage: 'الإعلانات مرتبطة بالحلقات، ولا توجد حلقات في الأكاديمية.',
      contentBuilder: feedFor,
    );
  }
}
