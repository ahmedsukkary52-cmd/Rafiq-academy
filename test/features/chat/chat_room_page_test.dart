import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_media_policy.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/media/chat_media_loader.dart';
import 'package:rafiq_academy/features/chat/presentation/media/chat_voice_recorder.dart';
import 'package:rafiq_academy/features/chat/presentation/pages/chat_room.dart';
import 'package:rafiq_academy/features/chat/presentation/widgets/chat_media_views.dart';

import 'chat_room_bloc_test.dart' show FakeChatRepository, buildBloc;

class FakeRecorder implements ChatVoiceRecorder {
  bool permission = true;
  String? stopPath;
  int starts = 0;
  int cancels = 0;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start() async => starts++;

  @override
  Future<String?> stop() async => stopPath;

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> dispose() async {}
}

void main() {
  late FakeChatRepository repo;
  late ChatRoomBloc bloc;
  late FakeRecorder recorder;
  ChatAttachmentDraft? nextPick;

  setUp(() {
    repo = FakeChatRepository();
    recorder = FakeRecorder();
    nextPick = null;
  });

  tearDown(() async {
    await repo.messages.close();
  });

  Future<void> pumpRoom(
    WidgetTester tester,
    List<MessageEntity> messages,
  ) async {
    // Built inside the test body so stream callbacks run in the fake-async zone.
    bloc = buildBloc(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomPage(
          conversationId: 'c1',
          otherUserName: 'أ. أحمد',
          bloc: bloc,
          mediaLoader: ChatMediaLoader(
            DownloadChatMediaUseCase(repo),
            tempDirectory: () async => Directory.systemTemp,
          ),
          recorderFactory: () => recorder,
          pickAttachment: (_) async => nextPick,
        ),
      ),
    );
    await tester.pump();
    repo.messages.add(Right(messages));
    await tester.pump();
    await tester.pump();
  }

  MessageEntity message(
    String id, {
    String sender = 's1',
    ChatMessageType type = ChatMessageType.text,
    String text = 'رسالة',
    bool deleted = false,
    ChatMediaEntity? media,
  }) => MessageEntity(
    id: id,
    conversationId: 'c1',
    senderId: sender,
    type: type,
    text: text,
    media: media,
    deleted: deleted,
    sentAt: DateTime.now().subtract(const Duration(minutes: 1)),
  );

  testWidgets(
    'composer: mic when empty, send when typed; no placeholder controls',
    (tester) async {
      await pumpRoom(tester, const []);
      expect(find.text('ابدأ المحادثة'), findsOneWidget);
      expect(find.byTooltip('تسجيل رسالة صوتية'), findsOneWidget);
      expect(find.byTooltip('إرسال'), findsNothing);
      expect(find.byTooltip('قريباً'), findsNothing);
      expect(find.text('قريباً'), findsNothing);

      await tester.enterText(find.byType(TextField), 'السلام عليكم');
      await tester.pump();
      expect(find.byTooltip('إرسال'), findsOneWidget);

      await tester.tap(find.byTooltip('إرسال'));
      await tester.pump();
      await tester.pump();
      expect(repo.sends.single.text, 'السلام عليكم');
      expect(find.text('السلام عليكم'), findsOneWidget);
      expect(find.text('جارٍ الإرسال…'), findsOneWidget);

      final id = repo.sends.single.messageId;
      repo.messages.add(
        Right([message(id, sender: 't1', text: 'السلام عليكم')]),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text('السلام عليكم'),
        findsOneWidget,
        reason: 'deduped, not doubled',
      );
      expect(find.text('جارٍ الإرسال…'), findsNothing);
    },
  );

  testWidgets('failed send shows the server reason with retry', (tester) async {
    repo.sendResults.add(const Left(ServerFailure('لست مشاركاً في المحادثة')));
    await pumpRoom(tester, const []);
    await tester.enterText(find.byType(TextField), 'مرحبا');
    await tester.pump();
    await tester.tap(find.byTooltip('إرسال'));
    await tester.pump();
    await tester.pump();
    expect(find.text('لست مشاركاً في المحادثة'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pump();
    expect(repo.sends, hasLength(2));
    expect(repo.sends[0].messageId, repo.sends[1].messageId);
  });

  testWidgets('deleted media message shows the deleted label and no media', (
    tester,
  ) async {
    await pumpRoom(tester, [
      message('d1', type: ChatMessageType.image, text: '', deleted: true),
      message(
        'v1',
        type: ChatMessageType.voice,
        text: '',
        media: const ChatMediaEntity(
          storagePath: 'chat_voice/c1/v1/voice.m4a',
          fileName: 'voice.m4a',
          contentType: 'audio/mp4',
          sizeBytes: 100,
          durationMs: 65000,
        ),
      ),
    ]);
    expect(find.text('تم حذف هذه الرسالة'), findsOneWidget);
    expect(find.byType(ChatImageView), findsNothing);
    expect(find.byType(ChatVoiceView), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
  });

  testWidgets(
    'long-press: own recent text offers edit + delete; others only copy',
    (tester) async {
      await pumpRoom(tester, [
        message('mine', sender: 't1', text: 'رسالتي'),
        message('theirs', text: 'رسالته'),
      ]);
      await tester.longPress(find.text('رسالتي'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل'), findsOneWidget);
      expect(find.text('حذف'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('رسالته'));
      await tester.pumpAndSettle();
      expect(find.text('نسخ النص'), findsOneWidget);
      expect(find.text('تعديل'), findsNothing);
      expect(find.text('حذف'), findsNothing);
    },
  );

  testWidgets('picked attachment shows upload progress and can be cancelled', (
    tester,
  ) async {
    nextPick = const ChatAttachmentDraft(
      type: ChatMessageType.file,
      localPath: '/tmp/plan.pdf',
      fileName: 'خطة.pdf',
      contentType: 'application/pdf',
      sizeBytes: 2048,
    );
    await pumpRoom(tester, const []);
    await tester.tap(find.byTooltip('إرفاق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملف'));
    await tester.pumpAndSettle();
    expect(find.textContaining('جارٍ الرفع'), findsOneWidget);
    expect(find.textContaining('خطة.pdf'), findsOneWidget);

    await tester.tap(find.text('إلغاء الرفع'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('جارٍ الرفع'), findsNothing);
    expect(repo.uploads.single.cancelled, isTrue);
    expect(repo.sends, isEmpty);
  });

  testWidgets(
    'voice: denied microphone permission explains instead of recording',
    (tester) async {
      recorder.permission = false;
      await pumpRoom(tester, const []);
      await tester.tap(find.byTooltip('تسجيل رسالة صوتية'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('يلزم السماح بالوصول إلى الميكروفون لتسجيل رسالة صوتية'),
        findsOneWidget,
      );
      expect(recorder.starts, 0);
    },
  );

  testWidgets(
    'voice: recording bar with cancel; too-short clips are not sent',
    (tester) async {
      await pumpRoom(tester, const []);
      await tester.tap(find.byTooltip('تسجيل رسالة صوتية'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('جارٍ التسجيل'), findsOneWidget);
      await tester.tap(find.byTooltip('إلغاء التسجيل'));
      await tester.pump();
      expect(recorder.cancels, 1);
      expect(find.textContaining('جارٍ التسجيل'), findsNothing);

      recorder.stopPath = '${Directory.systemTemp.path}/missing_clip.m4a';
      await tester.tap(find.byTooltip('تسجيل رسالة صوتية'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('إرسال التسجيل'));
      await tester.pump();
      await tester.pump();
      expect(find.text('التسجيل قصير جداً'), findsOneWidget);
      expect(repo.uploads, isEmpty);
    },
  );

  testWidgets('voice: a real recording becomes a voice attachment upload', (
    tester,
  ) async {
    final file = File(
      '${Directory.systemTemp.path}/chat_voice_test_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    await tester.runAsync(() => file.writeAsBytes(List.filled(64, 1)));
    recorder.stopPath = file.path;
    await pumpRoom(tester, const []);
    await tester.tap(find.byTooltip('تسجيل رسالة صوتية'));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('إرسال التسجيل'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump();
    expect(repo.uploads, hasLength(1));
    expect(repo.uploads.single.storagePath, startsWith('chat_voice/c1/'));
    expect(
      repo.uploads.single.storagePath,
      endsWith('/voice.${ChatMediaPolicy.voiceExtension}'),
    );
    expect(find.textContaining('رسالة صوتية'), findsOneWidget);
    await tester.runAsync(() => file.delete());
  });
}
