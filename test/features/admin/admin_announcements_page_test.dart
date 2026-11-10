import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_directory_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_announcements_page.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_embedded_pages.dart';
import 'package:rafiq_academy/features/admin/presentation/widgets/admin_halaqa_scope.dart';
import 'package:rafiq_academy/features/content/presentation/pages/content_library_page.dart';
import 'package:rafiq_academy/features/post/domain/entities/posts_entities.dart';
import 'package:rafiq_academy/features/post/domain/post_audience_target.dart';
import 'package:rafiq_academy/features/post/presentation/pages/posts_list_page.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

const _h1 = AdminHalaqaSummaryEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: 't1',
  supervisorId: 's1',
  studentCount: 3,
);
const _h2 = AdminHalaqaSummaryEntity(
  id: 'h2',
  name: 'حلقة العصر',
  teacherId: 't2',
  supervisorId: 's1',
  studentCount: 5,
);

Future<List<String>> _pump(
  WidgetTester tester, {
  required List<AdminHalaqaSummaryEntity> halaqat,
  SectionStatus status = SectionStatus.loaded,
  String? error,
  VoidCallback? onRetry,
}) async {
  final fed = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminHalaqaScopedBody(
          halaqat: halaqat,
          status: status,
          error: error,
          onRetry: onRetry ?? () {},
          scopeHint: 'hint',
          emptyMessage: 'no halaqat',
          contentBuilder: (id) {
            fed.add(id);
            return Text('feed:$id');
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return fed;
}

void main() {
  test(
    'academy-wide audience stays unresolvable (posts are Halaqa-scoped)',
    () {
      expect(
        resolvePostAudienceTarget(
          audience: PostAudience.allHalaqat,
          halaqaId: null,
        ),
        isNull,
      );
    },
  );

  test('announcements and content are built for the selected halaqa only', () {
    final feed = AdminAnnouncementsPage.feedFor('h1');
    expect(feed, isA<PostsListPage>());
    expect((feed as PostsListPage).halaqaId, 'h1');

    final library = AdminContentPage.libraryFor('h2');
    expect(library, isA<ContentLibraryPage>());
    expect((library as ContentLibraryPage).halaqaId, 'h2');
    expect(library.embeddedInAdmin, isTrue);
  });

  testWidgets('scopes the content to the first halaqa, never to "all"', (
    tester,
  ) async {
    final fed = await _pump(tester, halaqat: const [_h1, _h2]);

    expect(tester.takeException(), isNull);
    expect(find.text('feed:h1'), findsOneWidget);
    expect(fed.toSet(), {'h1'});
  });

  testWidgets('switching halaqa re-scopes the content', (tester) async {
    final fed = await _pump(tester, halaqat: const [_h1, _h2]);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حلقة العصر').last);
    await tester.pumpAndSettle();

    expect(find.text('feed:h2'), findsOneWidget);
    expect(find.text('feed:h1'), findsNothing);
    expect(fed.last, 'h2');
  });

  testWidgets('loaded with no halaqat shows an honest empty state', (
    tester,
  ) async {
    final fed = await _pump(tester, halaqat: const []);

    expect(find.text('no halaqat'), findsOneWidget);
    expect(fed, isEmpty);
  });

  testWidgets('directory error shows retry and no content', (tester) async {
    var retries = 0;
    final fed = await _pump(
      tester,
      halaqat: const [],
      status: SectionStatus.error,
      error: 'تعذر التحميل',
      onRetry: () => retries++,
    );

    expect(find.text('تعذر التحميل'), findsOneWidget);
    expect(fed, isEmpty);
    await tester.tap(find.byType(AppButton));
    expect(retries, 1);
  });

  testWidgets('loading with no halaqat shows a spinner, no content', (
    tester,
  ) async {
    final fed = await _pump(
      tester,
      halaqat: const [],
      status: SectionStatus.loading,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(fed, isEmpty);
  });
}
