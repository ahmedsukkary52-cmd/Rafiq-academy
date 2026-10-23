import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/post/data/models/post_models.dart';
import 'package:rafiq_academy/features/post/domain/entities/posts_entities.dart';

void main() {
  group('PostAttachmentModel', () {
    test('persists the private Storage path, never a download URL', () {
      const model = PostAttachmentModel(
        url:
            'https://firebasestorage.googleapis.com/v0/b/b/o/x?alt=media&token=t',
        storagePath: 'posts/h1/AbCdEfGhIjKlMnOpQrSt/att_0.pdf',
        contentType: 'application/pdf',
        type: AttachmentType.pdf,
        fileName: 'notes.pdf',
        fileSizeMb: 1.5,
      );

      final map = model.toMap();

      expect(map.containsKey('url'), isFalse);
      expect(map['storagePath'], 'posts/h1/AbCdEfGhIjKlMnOpQrSt/att_0.pdf');
      expect(map['contentType'], 'application/pdf');
      expect(map['type'], 'pdf');
      expect(map['fileName'], 'notes.pdf');
    });

    test('reads new path-based and legacy URL-only attachments', () {
      final modern = PostAttachmentModel.fromMap(const {
        'storagePath': ' posts/h1/AbCdEfGhIjKlMnOpQrSt/att_1.mp4 ',
        'contentType': 'video/mp4',
        'type': 'video',
        'fileName': 'clip.mp4',
      });
      expect(modern.storagePath, 'posts/h1/AbCdEfGhIjKlMnOpQrSt/att_1.mp4');
      expect(modern.url, isEmpty);
      expect(modern.type, AttachmentType.video);

      final legacy = PostAttachmentModel.fromMap(const {
        'url':
            'https://firebasestorage.googleapis.com/v0/b/b/o/posts%2Ft1%2F1.jpg?alt=media',
        'type': 'image',
        'fileName': '1.jpg',
      });
      expect(legacy.storagePath, isEmpty);
      expect(legacy.url, startsWith('https://firebasestorage.googleapis.com/'));

      final malformed = PostAttachmentModel.fromMap(const {
        'url': 42,
        'storagePath': ['x'],
        'type': 'image',
        'fileName': 'x',
      });
      expect(malformed.url, isEmpty);
      expect(malformed.storagePath, isEmpty);
    });

    test('withoutLegacyUrl drops only the URL', () {
      const model = PostAttachmentModel(
        url: 'https://evil.example/a.pdf',
        type: AttachmentType.pdf,
        fileName: 'a.pdf',
        fileSizeMb: 2,
      );

      final stripped = model.withoutLegacyUrl();

      expect(stripped.url, isEmpty);
      expect(stripped.fileName, 'a.pdf');
      expect(stripped.type, AttachmentType.pdf);
      expect(stripped.fileSizeMb, 2);
    });
  });
}
