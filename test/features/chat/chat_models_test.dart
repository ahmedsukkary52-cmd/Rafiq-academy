import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/data/models/chat_models.dart';

void main() {
  group('ConversationModel.fromMap', () {
    test('reads unreadCounts stored as num (Firestore increment)', () {
      final model = ConversationModel.fromMap('c1', {
        'participants': [
          {'uid': 't1', 'name': 'معلم', 'role': 'teacher'},
          {'uid': 's1', 'name': 'طالب', 'role': 'student'},
        ],
        'lastMessage': 'مرحبا',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 8, 14, 12)),
        'unreadCounts': {'t1': 2.0, 's1': 0},
      }, currentUid: 't1');

      expect(model.unreadCount, 2);
      expect(model.participants, hasLength(2));
      expect(model.lastMessage, 'مرحبا');
      expect(model.lastMessageAt, DateTime(2026, 8, 14, 12));
    });

    test('otherParticipant works on mapped ChatParticipantModel rows', () {
      final model = ConversationModel.fromMap('c1', {
        'participants': [
          {'uid': 't1', 'name': 'معلم', 'role': 'teacher'},
          {'uid': 's1', 'name': 'طالب', 'role': 'student'},
        ],
        'unreadCounts': {'t1': 0, 's1': 0},
      }, currentUid: 't1');

      expect(model.otherParticipant('t1').uid, 's1');
      expect(model.otherParticipant('s1').uid, 't1');
    });

    test('otherParticipant accepts a runtime List<ChatParticipantModel>', () {
      const teacher = ChatParticipantModel(
        uid: 't1',
        name: 'معلم',
        role: 'teacher',
      );
      const student = ChatParticipantModel(
        uid: 's1',
        name: 'طالب',
        role: 'student',
      );
      const model = ConversationModel(
        id: 'c1',
        participants: [teacher, student],
        unreadCount: 0,
      );
      expect(model.otherParticipant('t1').uid, 's1');
    });

    test('survives pending lastMessageAt and empty participants', () {
      final model = ConversationModel.fromMap('c1', {
        'participants': <dynamic>[],
        'lastMessageAt': null,
        'unreadCounts': <String, dynamic>{},
      }, currentUid: 't1');

      expect(model.unreadCount, 0);
      expect(model.participants, isEmpty);
      expect(model.lastMessageAt, isNull);
    });
  });

  group('MessageModel.fromMap', () {
    test('null sentAt (server timestamp pending) does not throw', () {
      final model = MessageModel.fromMap('m1', {
        'senderId': 't1',
        'text': 'test message',
        'sentAt': null,
      }, conversationId: 'c1');

      expect(model.text, 'test message');
      expect(model.senderId, 't1');
      expect(model.sentAt, isA<DateTime>());
    });

    test('reads Timestamp sentAt', () {
      final sent = DateTime(2026, 8, 14, 15, 30);
      final model = MessageModel.fromMap('m1', {
        'senderId': 's1',
        'text': 'hi',
        'sentAt': Timestamp.fromDate(sent),
      }, conversationId: 'c1');

      expect(model.sentAt, sent);
    });
  });
}
