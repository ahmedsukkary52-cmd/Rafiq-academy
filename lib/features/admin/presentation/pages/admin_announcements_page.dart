import 'package:flutter/material.dart';

import '../../../post/domain/entities/posts_entities.dart';
import '../../../post/domain/post_audience_target.dart';
import '../../../post/presentation/pages/posts_list_page.dart';
import '../widgets/admin_subpage_scaffold.dart';

/// Figma: مركز الإعلانات.
///
/// Uses existing Posts architecture: [PostAudience.allHalaqat] →
/// `audienceTarget: 'all'` via [resolvePostAudienceTarget] (see
/// `posts_remote_datasource_impl.watchPosts` whereIn query).
/// Not an admin-invented contract.
class AdminAnnouncementsPage extends StatelessWidget {
  const AdminAnnouncementsPage({super.key});

  static final String _academyWideTarget = resolvePostAudienceTarget(
    audience: PostAudience.allHalaqat,
    halaqaId: null,
  )!;

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'مركز الإعلانات',
      subtitle: 'منشورات الأكاديمية',
      body: PostsListPage(halaqaId: _academyWideTarget, embedded: true),
    );
  }
}
