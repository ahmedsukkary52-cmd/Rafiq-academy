import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/parent_payment_proof.dart';
import 'package:rafiq_academy/shared/domain/storage_paths_contract.dart';

void main() {
  group('WA-12 StoragePathsContract', () {
    test('payment proof path matches C10', () {
      expect(
        StoragePathsContract.paymentProof(
          parentId: 'p1',
          paymentId: 'pay1',
          fileName: 'a.jpg',
        ),
        'payment_proofs/p1/pay1/a.jpg',
      );
      expect(
        ParentPaymentProofContract.storagePath(
          parentId: 'p1',
          paymentId: 'pay1',
          fileName: 'a.jpg',
        ),
        'payment_proofs/p1/pay1/a.jpg',
      );
    });

    test('profile / chat / voice / recitation path shapes', () {
      expect(
        StoragePathsContract.profileImage(uid: 'u1', fileName: 'x.png'),
        'profile_images/u1/x.png',
      );
      expect(
        StoragePathsContract.chatMedia(
          conversationId: 'a_b',
          messageId: 'm1',
          fileName: 'i.jpg',
        ),
        'chat_media/a_b/m1/i.jpg',
      );
      expect(
        StoragePathsContract.chatVoice(
          conversationId: 'a_b',
          messageId: 'm1',
          fileName: 'v.m4a',
        ),
        'chat_voice/a_b/m1/v.m4a',
      );
      expect(
        StoragePathsContract.chatAttachment(
          conversationId: 'a_b',
          messageId: 'm1',
          fileName: 'file.pdf',
        ),
        'chat_attachments/a_b/m1/file.pdf',
      );
      expect(
        StoragePathsContract.recitation(
          studentId: 's1',
          assignmentId: 'asg1',
          fileName: 't1.m4a',
        ),
        'recitations/s1/asg1/t1.m4a',
      );
    });

    test('rejects empty path segments', () {
      expect(
        () => StoragePathsContract.paymentProof(
          parentId: ' ',
          paymentId: 'pay1',
          fileName: 'a.jpg',
        ),
        throwsArgumentError,
      );
      expect(
        () => StoragePathsContract.chatMedia(
          conversationId: 'c1',
          messageId: '',
          fileName: 'a.jpg',
        ),
        throwsArgumentError,
      );
    });

    test('approved prefix detector', () {
      expect(
        StoragePathsContract.isApprovedPrefix('payment_proofs/p/pay/a.jpg'),
        isTrue,
      );
      expect(
        StoragePathsContract.isApprovedPrefix('posts/u1/1.jpg'),
        isTrue,
      );
      expect(
        StoragePathsContract.isApprovedPrefix('content/u1/1.pdf'),
        isTrue,
      );
      expect(
        StoragePathsContract.isApprovedPrefix(
          'halaqa_activities/a1/s1/images/x.jpg',
        ),
        isTrue,
      );
      expect(
        StoragePathsContract.isApprovedPrefix('orphan_uploads/u1/1.jpg'),
        isFalse,
      );
    });

    test('posts / content / halaqa activity path helpers', () {
      expect(
        StoragePathsContract.postAttachment(
          halaqaId: 'h1',
          postId: 'p1',
          fileName: 'att_0.jpg',
        ),
        'posts/h1/p1/att_0.jpg',
      );
      expect(
        StoragePathsContract.contentFile(
          uploadedBy: 't1',
          fileName: 'a.pdf',
        ),
        'content/t1/a.pdf',
      );
      expect(
        StoragePathsContract.halaqaActivityMedia(
          activityId: 'act1',
          studentId: 's1',
          folder: 'images',
          fileName: 'x.jpg',
        ),
        'halaqa_activities/act1/s1/images/x.jpg',
      );
    });
  });
}
