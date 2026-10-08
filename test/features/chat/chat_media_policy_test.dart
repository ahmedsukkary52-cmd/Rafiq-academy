import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/data/models/chat_models.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_media_policy.dart';

ChatAttachmentDraft draft({
  ChatMessageType type = ChatMessageType.image,
  String fileName = 'a.jpg',
  String? contentType,
  int size = 1000,
  int? durationMs,
}) => ChatAttachmentDraft(
  type: type,
  localPath: '/tmp/$fileName',
  fileName: fileName,
  contentType:
      contentType ?? ChatMediaPolicy.contentTypeFor(type, fileName) ?? '',
  sizeBytes: size,
  durationMs: durationMs,
);

void main() {
  group('ChatMediaPolicy.validate (mirrors sendChatMessage)', () {
    test('accepts allowed image / document / voice drafts', () {
      expect(ChatMediaPolicy.validate(draft()), isNull);
      expect(ChatMediaPolicy.validate(draft(fileName: 'b.PNG')), isNull);
      expect(
        ChatMediaPolicy.validate(
          draft(type: ChatMessageType.file, fileName: 'خطة.pdf'),
        ),
        isNull,
      );
      expect(
        ChatMediaPolicy.validate(
          draft(type: ChatMessageType.file, fileName: 'x.docx'),
        ),
        isNull,
      );
      expect(
        ChatMediaPolicy.validate(
          draft(
            type: ChatMessageType.voice,
            fileName: 'voice.m4a',
            durationMs: 3000,
          ),
        ),
        isNull,
      );
    });

    test('rejects unsupported types and MIME mismatches', () {
      expect(
        ChatMediaPolicy.validate(draft(fileName: 'a.gif')),
        contains('JPG'),
      );
      expect(ChatMediaPolicy.validate(draft(fileName: 'a.heic')), isNotNull);
      expect(
        ChatMediaPolicy.validate(
          draft(type: ChatMessageType.file, fileName: 'a.exe'),
        ),
        contains('PDF'),
      );
      expect(
        ChatMediaPolicy.validate(
          draft(fileName: 'a.jpg', contentType: 'application/pdf'),
        ),
        isNotNull,
      );
      expect(
        ChatMediaPolicy.validate(
          draft(type: ChatMessageType.file, fileName: 'a.jpg'),
        ),
        isNotNull,
      );
    });

    test('size ceilings are strict (server uses <)', () {
      expect(ChatMediaPolicy.validate(draft(size: 0)), isNotNull);
      expect(
        ChatMediaPolicy.validate(draft(size: 10 * 1024 * 1024)),
        contains('10'),
      );
      expect(
        ChatMediaPolicy.validate(draft(size: 10 * 1024 * 1024 - 1)),
        isNull,
      );
      expect(
        ChatMediaPolicy.validate(
          draft(
            type: ChatMessageType.voice,
            fileName: 'v.m4a',
            size: 20 * 1024 * 1024,
            durationMs: 1000,
          ),
        ),
        isNotNull,
      );
    });

    test('voice needs a positive duration within 10 minutes', () {
      ChatAttachmentDraft v({int? ms}) =>
          draft(type: ChatMessageType.voice, fileName: 'v.m4a', durationMs: ms);
      expect(ChatMediaPolicy.validate(v()), isNotNull);
      expect(ChatMediaPolicy.validate(v(ms: 0)), isNotNull);
      expect(ChatMediaPolicy.validate(v(ms: 10 * 60 * 1000 + 1)), isNotNull);
      expect(ChatMediaPolicy.validate(v(ms: 10 * 60 * 1000)), isNull);
    });
  });

  group('paths and names', () {
    test('storage path is the message folder for the type', () {
      const id = 'AbCdEfGhIj0123456789';
      expect(
        ChatMediaPolicy.storagePath(
          conversationId: 'a_b',
          messageId: id,
          draft: draft(),
        ),
        'chat_media/a_b/$id/image.jpg',
      );
      expect(
        ChatMediaPolicy.storagePath(
          conversationId: 'a_b',
          messageId: id,
          draft: draft(
            type: ChatMessageType.voice,
            fileName: 'voice.m4a',
            durationMs: 1,
          ),
        ),
        'chat_voice/a_b/$id/voice.m4a',
      );
      expect(
        ChatMediaPolicy.storagePath(
          conversationId: 'halaqa_group_h1',
          messageId: id,
          draft: draft(type: ChatMessageType.file, fileName: 'خطة الحفظ.pdf'),
        ),
        'chat_attachments/halaqa_group_h1/$id/file.pdf',
      );
    });

    test('display name strips separators and is bounded', () {
      expect(
        ChatMediaPolicy.displayFileName('../../etc/passwd'),
        '.._.._etc_passwd',
      );
      expect(ChatMediaPolicy.displayFileName('  '), 'file');
      final long = '${'ا' * 200}.pdf';
      final shown = ChatMediaPolicy.displayFileName(long);
      expect(shown.length, ChatMediaPolicy.fileNameMaxChars);
      expect(shown, endsWith('.pdf'));
    });

    test('message ids are retry-stable and match the server pattern', () {
      final a = ChatMessageIds.generate(Random(1));
      final b = ChatMessageIds.generate(Random(1));
      expect(a, b);
      expect(ChatMessageIds.isValid(a), isTrue);
      expect(ChatMessageIds.isValid('short'), isFalse);
      expect(ChatMessageIds.isValid('has/slash/inside00'), isFalse);
      expect(ChatMessageIds.generate(), isNot(ChatMessageIds.generate()));
    });
  });

  group('canEdit (UX mirror; server authoritative)', () {
    final sentAt = DateTime(2026, 10, 6, 12);
    MessageEntity m({
      String sender = 'u1',
      ChatMessageType type = ChatMessageType.text,
      bool deleted = false,
    }) => MessageEntity(
      id: 'm',
      conversationId: 'c',
      senderId: sender,
      type: type,
      text: 'x',
      sentAt: sentAt,
      deleted: deleted,
    );

    test('own text within 15 minutes only', () {
      final now = sentAt.add(const Duration(minutes: 10));
      expect(ChatMediaPolicy.canEdit(m(), 'u1', now: now), isTrue);
      expect(ChatMediaPolicy.canEdit(m(), 'u2', now: now), isFalse);
      expect(
        ChatMediaPolicy.canEdit(m(type: ChatMessageType.image), 'u1', now: now),
        isFalse,
      );
      expect(
        ChatMediaPolicy.canEdit(m(deleted: true), 'u1', now: now),
        isFalse,
      );
      expect(
        ChatMediaPolicy.canEdit(
          m(),
          'u1',
          now: sentAt.add(const Duration(minutes: 16)),
        ),
        isFalse,
      );
    });
  });

  group('MessageModel media parsing', () {
    test('reads server-written media metadata', () {
      final model = MessageModel.fromMap('m1', {
        'senderId': 'u1',
        'type': 'voice',
        'text': '',
        'sentAt': Timestamp.fromDate(DateTime(2026, 10, 6)),
        'deleted': false,
        'media': const {
          'storagePath': 'chat_voice/c/m1/voice.m4a',
          'fileName': 'voice.m4a',
          'contentType': 'audio/mp4',
          'sizeBytes': 4096,
          'durationMs': 4200,
        },
      }, conversationId: 'c');
      expect(model.type, ChatMessageType.voice);
      expect(model.media!.durationMs, 4200);
      expect(model.visibleMedia, isNotNull);
    });

    test(
      'deleted messages never expose media; legacy docs default to text',
      () {
        final deleted = MessageModel.fromMap('m1', const {
          'senderId': 'u1',
          'type': 'image',
          'deleted': true,
          'media': {'storagePath': 'chat_media/c/m1/image.jpg'},
        }, conversationId: 'c');
        expect(deleted.media, isNull);
        expect(deleted.visibleMedia, isNull);

        final legacy = MessageModel.fromMap('m2', const {
          'senderId': 'u1',
          'text': 'hi',
        }, conversationId: 'c');
        expect(legacy.type, ChatMessageType.text);
        expect(legacy.media, isNull);
        expect(ChatMessageType.fromWire('video'), ChatMessageType.text);
      },
    );
  });
}
