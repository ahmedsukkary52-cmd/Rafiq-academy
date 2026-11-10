import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/awards/data/award_image_storage_path.dart';
import 'package:rafiq_academy/shared/domain/parent_payment_proof.dart';
import 'package:rafiq_academy/features/post/domain/entities/posts_entities.dart';
import 'package:rafiq_academy/features/post/domain/post_attachment_policy.dart';
import 'package:rafiq_academy/shared/domain/upload_file_policy.dart';

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46];
const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D];
const _webp = [
  0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, //
];
const _pdf = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37];
const _wav = [
  0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, 0x57, 0x41, 0x56, 0x45, //
];
const _mp4 = [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32];

void main() {
  const mb = UploadFilePolicy.mb;
  const images = UploadFilePolicy.imageFormats;

  group('UploadFilePolicy content-type mapping', () {
    test('image formats map to exact MIME types', () {
      expect(
        UploadFilePolicy.formatFor('a.jpg', images)?.contentType,
        'image/jpeg',
      );
      expect(
        UploadFilePolicy.formatFor('a.JPEG', images)?.contentType,
        'image/jpeg',
      );
      expect(
        UploadFilePolicy.formatFor('a.png', images)?.contentType,
        'image/png',
      );
      expect(
        UploadFilePolicy.formatFor('a.webp', images)?.contentType,
        'image/webp',
      );
      expect(UploadFilePolicy.extensionsOf(images), [
        'jpg',
        'jpeg',
        'png',
        'webp',
      ]);
    });

    test('unsupported, missing and ambiguous extensions have no format', () {
      for (final name in const [
        'a.gif',
        'a.heic',
        'a.svg',
        'a.pdf',
        'a',
        'a.',
        '.png',
        'a.jpg.exe',
        'dir.png/file',
        '',
      ]) {
        expect(UploadFilePolicy.formatFor(name, images), isNull, reason: name);
      }
    });

    test('extension is taken from the file name, not the directory', () {
      expect(UploadFilePolicy.extensionOf('/tmp/x.y/photo.PNG'), 'png');
      expect(UploadFilePolicy.extensionOf(r'C:\a.b\photo'), '');
    });
  });

  group('UploadFilePolicy.check size boundaries', () {
    test('accepts below the ceiling; rejects at/above it and empty files', () {
      UploadCheck c(int size) => UploadFilePolicy.check(
        fileName: 'shot.jpg',
        sizeBytes: size,
        formats: images,
      );
      expect(c(1).isOk, isTrue);
      expect(c(10 * mb - 1).isOk, isTrue);
      expect(c(10 * mb).isOk, isFalse);
      expect(c(10 * mb + 1).isOk, isFalse);
      expect(c(0).isOk, isFalse);
      expect(c(0).error, 'الملف فارغ');
    });

    test('unsupported type is rejected with the allowed list', () {
      final r = UploadFilePolicy.check(
        fileName: 'anim.gif',
        sizeBytes: 10,
        formats: images,
      );
      expect(r.isOk, isFalse);
      expect(r.error, contains('غير مدعوم'));
      expect(r.error, contains('WEBP'));
    });
  });

  group('UploadFilePolicy.matchesSignature', () {
    test('accepts matching magic bytes', () {
      expect(UploadFilePolicy.matchesSignature(_jpeg, 'image/jpeg'), isTrue);
      expect(UploadFilePolicy.matchesSignature(_png, 'image/png'), isTrue);
      expect(UploadFilePolicy.matchesSignature(_webp, 'image/webp'), isTrue);
      expect(
        UploadFilePolicy.matchesSignature(_pdf, 'application/pdf'),
        isTrue,
      );
      expect(UploadFilePolicy.matchesSignature(_wav, 'audio/wav'), isTrue);
      expect(UploadFilePolicy.matchesSignature(_mp4, 'video/mp4'), isTrue);
      expect(
        UploadFilePolicy.matchesSignature(const [
          0x49,
          0x44,
          0x33,
          4,
        ], 'audio/mpeg'),
        isTrue,
      );
      expect(
        UploadFilePolicy.matchesSignature(const [
          0xFF,
          0xFB,
          0x90,
        ], 'audio/mpeg'),
        isTrue,
      );
    });

    test('rejects mismatched, truncated and unknown types', () {
      expect(UploadFilePolicy.matchesSignature(_png, 'image/jpeg'), isFalse);
      expect(UploadFilePolicy.matchesSignature(_jpeg, 'image/png'), isFalse);
      expect(UploadFilePolicy.matchesSignature(_wav, 'image/webp'), isFalse);
      expect(UploadFilePolicy.matchesSignature(_webp, 'audio/wav'), isFalse);
      expect(
        UploadFilePolicy.matchesSignature(const [0xFF, 0xD8], 'image/jpeg'),
        isFalse,
      );
      expect(UploadFilePolicy.matchesSignature(const [], 'image/png'), isFalse);
      expect(UploadFilePolicy.matchesSignature(_jpeg, 'image/gif'), isFalse);
      expect(
        UploadFilePolicy.matchesSignature(_jpeg, 'application/octet-stream'),
        isFalse,
      );
    });
  });

  group('UploadFilePolicy.checkFile', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('upload_policy_test');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    Future<File> write(String name, List<int> bytes) async {
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      await f.writeAsBytes(bytes);
      return f;
    }

    test(
      'accepts JPEG, PNG and WebP whose bytes match the extension',
      () async {
        for (final (name, bytes, type) in [
          ('a.jpg', _jpeg, 'image/jpeg'),
          ('b.png', _png, 'image/png'),
          ('c.webp', _webp, 'image/webp'),
        ]) {
          final r = await UploadFilePolicy.checkFile(
            await write(name, bytes),
            formats: images,
          );
          expect(r.isOk, isTrue, reason: name);
          expect(r.format!.contentType, type);
        }
      },
    );

    test(
      'rejects renamed files, missing extensions and missing files',
      () async {
        final renamed = await UploadFilePolicy.checkFile(
          await write('fake.png', _jpeg),
          formats: images,
        );
        expect(renamed.isOk, isFalse);
        expect(renamed.error, contains('لا يطابق'));

        final noExt = await UploadFilePolicy.checkFile(
          await write('noext', _jpeg),
          formats: images,
        );
        expect(noExt.isOk, isFalse);

        final missing = await UploadFilePolicy.checkFile(
          File('${dir.path}${Platform.pathSeparator}nope.jpg'),
          formats: images,
        );
        expect(missing.isOk, isFalse);
      },
    );

    test(
      'displayName decides the format when the temp path has none',
      () async {
        final r = await UploadFilePolicy.checkFile(
          await write('picker_tmp', _png),
          formats: images,
          displayName: 'receipt.PNG',
        );
        expect(r.isOk, isTrue);
        expect(r.format!.contentType, 'image/png');
      },
    );
  });

  group('PostAttachmentPolicy', () {
    test('formats, MIME types, attachment types and limits', () {
      expect(PostAttachmentPolicy.allowedExtensions, [
        'pdf', 'jpg', 'jpeg', 'png', 'mp3', 'wav', 'mp4', //
      ]);
      final expected = {
        'a.pdf': ('application/pdf', AttachmentType.pdf, 20 * mb),
        'a.jpg': ('image/jpeg', AttachmentType.image, 10 * mb),
        'a.jpeg': ('image/jpeg', AttachmentType.image, 10 * mb),
        'a.png': ('image/png', AttachmentType.image, 10 * mb),
        'a.mp3': ('audio/mpeg', AttachmentType.audio, 20 * mb),
        'a.wav': ('audio/wav', AttachmentType.audio, 20 * mb),
        'a.mp4': ('video/mp4', AttachmentType.video, 50 * mb),
      };
      expected.forEach((name, e) {
        final f = PostAttachmentPolicy.formatFor(name)!;
        expect(f.contentType, e.$1, reason: name);
        expect(PostAttachmentPolicy.typeFor(f), e.$2, reason: name);
        expect(f.maxBytes, e.$3, reason: name);
      });
      for (final name in const ['a.gif', 'a.webp', 'a.docx', 'a.exe', 'a']) {
        expect(PostAttachmentPolicy.formatFor(name), isNull, reason: name);
      }
    });

    test('per-type size boundaries', () {
      bool ok(String name, int size) => UploadFilePolicy.check(
        fileName: name,
        sizeBytes: size,
        formats: PostAttachmentPolicy.formats,
      ).isOk;
      expect(ok('a.jpg', 10 * mb - 1), isTrue);
      expect(ok('a.jpg', 10 * mb), isFalse);
      expect(ok('a.pdf', 20 * mb - 1), isTrue);
      expect(ok('a.pdf', 20 * mb), isFalse);
      expect(ok('a.mp4', 50 * mb - 1), isTrue);
      expect(ok('a.mp4', 50 * mb), isFalse);
    });

    test('storage path is Halaqa + post scoped with a fixed object name', () {
      const postId = 'AbCdEfGhIjKlMnOpQrSt';
      final path = PostAttachmentPolicy.storagePath(
        halaqaId: 'h1',
        postId: postId,
        index: 3,
        format: PostAttachmentPolicy.formatFor('Lesson Notes.PDF')!,
      );
      expect(path, 'posts/h1/$postId/att_3.pdf');
      expect(
        PostAttachmentPolicy.isTrustedStoragePath(
          path,
          halaqaId: 'h1',
          postId: postId,
        ),
        isTrue,
      );
      expect(
        () => PostAttachmentPolicy.storagePath(
          halaqaId: 'h1',
          postId: 'short',
          index: 0,
          format: UploadFilePolicy.jpg,
        ),
        throwsArgumentError,
      );
      expect(
        () => PostAttachmentPolicy.storageFileName(10, UploadFilePolicy.jpg),
        throwsRangeError,
      );
    });

    test('foreign, malformed and URL-shaped paths are not trusted', () {
      const postId = 'AbCdEfGhIjKlMnOpQrSt';
      for (final path in const [
        'posts/h2/AbCdEfGhIjKlMnOpQrSt/att_0.jpg',
        'posts/h1/OtherPostIdAaaaaaaaa/att_0.jpg',
        'posts/h1/AbCdEfGhIjKlMnOpQrSt/photo.jpg',
        'posts/h1/AbCdEfGhIjKlMnOpQrSt/att_0.gif',
        'posts/h1/AbCdEfGhIjKlMnOpQrSt/sub/att_0.jpg',
        'posts/teacher1/1.jpg',
        'https://evil.example/posts/h1/AbCdEfGhIjKlMnOpQrSt/att_0.jpg',
        '',
      ]) {
        expect(
          PostAttachmentPolicy.isTrustedStoragePath(
            path,
            halaqaId: 'h1',
            postId: postId,
          ),
          isFalse,
          reason: path,
        );
      }
    });

    test('legacy URL accepted only for this bucket + author legacy folder', () {
      const bucket = 'demo.appspot.com';
      String url(
        String b,
        String object, {
        String host = 'firebasestorage.googleapis.com',
      }) =>
          'https://$host/v0/b/$b/o/${Uri.encodeComponent(object)}?alt=media&token=t';
      bool ok(String? u) => PostAttachmentPolicy.isLegacyDownloadUrl(
        u,
        bucket: bucket,
        authorId: 't1',
      );

      expect(ok(url(bucket, 'posts/t1/1.jpg')), isTrue);
      expect(ok(url('other.appspot.com', 'posts/t1/1.jpg')), isFalse);
      expect(ok(url(bucket, 'posts/t2/1.jpg')), isFalse);
      expect(ok(url(bucket, 'payment_proofs/p1/pay1/1.jpg')), isFalse);
      expect(ok(url(bucket, 'posts/t1/a/b.jpg')), isFalse);
      expect(ok(url(bucket, 'posts/t1/..')), isFalse);
      expect(ok(url(bucket, 'posts/t1/1.jpg', host: 'evil.example')), isFalse);
      expect(
        ok(url(bucket, 'posts/t1/1.jpg').replaceFirst('https', 'http')),
        isFalse,
      );
      expect(
        ok(url(bucket, 'posts/t1/1.jpg').replaceFirst('alt=media', 'alt=json')),
        isFalse,
      );
      expect(ok('https://evil.example/a.pdf'), isFalse);
      expect(ok(''), isFalse);
      expect(ok(null), isFalse);
    });
  });

  group('ParentPaymentProofContract', () {
    test('proof file name carries the validated extension', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1760000000000);
      expect(
        ParentPaymentProofContract.proofFileName(
          UploadFilePolicy.png,
          now: now,
        ),
        '1760000000000.png',
      );
      expect(
        ParentPaymentProofContract.proofFileName(
          UploadFilePolicy.webp,
          now: now,
        ),
        '1760000000000.webp',
      );
      expect(ParentPaymentProofContract.maxBytes, 10 * mb);
      expect(ParentPaymentProofContract.formats, images);
    });

    test('trusted path binds parent + payment + image object name', () {
      bool ok(String? p) => ParentPaymentProofContract.isTrustedStoragePath(
        p,
        parentId: 'par1',
        paymentId: 'pay1',
      );
      expect(ok('payment_proofs/par1/pay1/1760000000000.jpg'), isTrue);
      expect(ok('payment_proofs/par1/pay1/a_b-1.webp'), isTrue);
      expect(ok('payment_proofs/par2/pay1/1.jpg'), isFalse);
      expect(ok('payment_proofs/par1/pay2/1.jpg'), isFalse);
      expect(ok('payment_proofs/par1/pay1/1.gif'), isFalse);
      expect(ok('payment_proofs/par1/pay1/a b.jpg'), isFalse);
      expect(ok('payment_proofs/par1/pay1/1'), isFalse);
      expect(ok('payment_proofs/par1/pay1'), isFalse);
      expect(ok('https://x.example/payment_proofs/par1/pay1/1.jpg'), isFalse);
      expect(ok(null), isFalse);
      expect(
        ParentPaymentProofContract.isTrustedStoragePath(
          'payment_proofs//pay1/1.jpg',
          parentId: '',
          paymentId: 'pay1',
        ),
        isFalse,
      );
    });
  });

  group('award image path', () {
    test('keeps the validated extension (JPEG / PNG / WebP)', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1000);
      expect(
        awardImageStoragePath(teacherId: 't1', extension: 'PNG', now: now),
        'awards/t1/1000.png',
      );
      expect(
        awardImageStoragePath(teacherId: 't1', extension: '.webp', now: now),
        'awards/t1/1000.webp',
      );
      expect(
        awardImageStoragePath(teacherId: 't1', extension: 'jpeg', now: now),
        'awards/t1/1000.jpeg',
      );
    });

    test('unsupported or missing extension fails instead of defaulting', () {
      for (final ext in const ['gif', 'heic', 'pdf', '', 'jpg.exe']) {
        expect(
          () => awardImageStoragePath(teacherId: 't1', extension: ext),
          throwsArgumentError,
          reason: ext,
        );
      }
    });
  });
}
