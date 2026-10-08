import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/audio_library/data/datasources/audio_library_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/content/domain/content_upload_policy.dart';
import 'package:rafiq_academy/features/content/domain/entities/content_file_entity.dart';

void main() {
  group('ContentUploadPolicy (§8)', () {
    test('allows PDF, audio, images and Word documents only', () {
      expect(ContentUploadPolicy.contentTypeFor('a.PDF'), 'application/pdf');
      expect(ContentUploadPolicy.contentTypeFor('a.mp3'), 'audio/mpeg');
      expect(ContentUploadPolicy.contentTypeFor('a.jpeg'), 'image/jpeg');
      expect(
        ContentUploadPolicy.contentTypeFor('a.docx'),
        startsWith('application/vnd.openxmlformats'),
      );
      expect(ContentUploadPolicy.contentTypeFor('a.exe'), isNull);
      expect(ContentUploadPolicy.contentTypeFor('noext'), isNull);
    });

    test('maps file types for the library grid', () {
      expect(ContentUploadPolicy.fileTypeFor('x.pdf'), ContentFileType.pdf);
      expect(ContentUploadPolicy.fileTypeFor('x.m4a'), ContentFileType.audio);
      expect(ContentUploadPolicy.fileTypeFor('x.png'), ContentFileType.image);
      expect(
        ContentUploadPolicy.fileTypeFor('x.doc'),
        ContentFileType.document,
      );
    });

    test('storage path is halaqa- and uploader-scoped', () {
      expect(
        ContentUploadPolicy.storagePath(
          halaqaId: ' h1 ',
          uploadedBy: 'u1',
          fileName: 'درس.pdf',
          timestampMs: 42,
        ),
        'content_library/h1/u1/42.pdf',
      );
    });
  });

  group('listeningProgressDocId (§5)', () {
    test('is deterministic per user and surah audio', () {
      expect(listeningProgressDocId('u1', 'r7_002'), 'u1_r7_002');
      expect(listeningProgressDocId('u1', 'a/b'), 'u1_a_b');
    });
  });
}
