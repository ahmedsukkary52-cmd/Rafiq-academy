import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/post/data/models/post_models.dart';
import 'package:rafiq_academy/features/post/domain/entities/posts_entities.dart';

void main() {
  group('PostModel.fromData createdAt null-safety', () {
    test('does not throw when createdAt is null (serverTimestamp local snap)', () {
      expect(
        () => PostModel.fromData(
          id: 'p1',
          data: {
            'authorId': 't1',
            'authorName': 'معلم',
            'content': 'منشور جديد',
            'halaqaId': 'h1',
            'audience': 'specificHalaqa',
            'createdAt': null,
            'isPinned': false,
            'likedBy': <String>[],
            'commentsCount': 0,
            'attachments': <dynamic>[],
          },
        ),
        returnsNormally,
      );

      final post = PostModel.fromData(
        id: 'p1',
        data: {
          'authorId': 't1',
          'authorName': 'معلم',
          'content': 'منشور جديد',
          'halaqaId': 'h1',
          'audience': 'specificHalaqa',
          'createdAt': null,
          'isPinned': false,
          'likedBy': <String>[],
          'commentsCount': 0,
        },
      );
      expect(post.id, 'p1');
      expect(post.content, 'منشور جديد');
      expect(post.audience, PostAudience.specificHalaqa);
      expect(post.createdAt, isA<DateTime>());
    });

    test('still reads Timestamp / DateTime createdAt when present', () {
      final at = DateTime(2026, 8, 17, 12, 0);
      final fromDateTime = PostModel.fromData(
        id: 'p2',
        data: {
          'authorId': 't1',
          'authorName': 'معلم',
          'content': 'نص',
          'createdAt': at,
        },
      );
      expect(fromDateTime.createdAt, at);
    });
  });
}
