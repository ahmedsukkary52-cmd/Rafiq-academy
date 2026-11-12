import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_create_chat_group_page.dart';
import 'package:rafiq_academy/features/chat/data/chat_groups_repository.dart';
import 'package:rafiq_academy/features/chat/data/models/chat_models.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_media_policy.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_event.dart';
import 'package:rafiq_academy/features/chat/presentation/media/chat_media_loader.dart';
import 'package:rafiq_academy/features/chat/presentation/pages/chat_group_info_page.dart';
import 'package:rafiq_academy/features/chat/presentation/pages/chat_room.dart';
import 'package:rafiq_academy/features/chat/presentation/widgets/chat_conversation_tile.dart';

import 'chat_room_bloc_test.dart' show FakeChatRepository, buildBloc;
import 'chat_room_page_test.dart' show FakeRecorder;

const _admin = ChatParticipantEntity(uid: 'a1', name: 'المدير', role: AppRoles.admin);
const _teacher = ChatParticipantEntity(uid: 't1', name: 'أحمد', role: AppRoles.teacher);
const _parent = ChatParticipantEntity(uid: 'p1', name: 'سارة', role: AppRoles.parent);

ConversationEntity _group({
  String kind = ConversationKinds.customGroup,
  List<ChatParticipantEntity> members = const [_admin, _teacher, _parent],
}) => ConversationEntity(
  id: 'group_x',
  participants: members,
  unreadCount: 0,
  kind: kind,
  title: 'أولياء الأمور',
  description: 'متابعة أسبوعية',
  groupAdminIds: const ['a1'],
);

class _FakeGroups extends Fake implements ChatGroupsRepository {
  final meta = StreamController<ConversationEntity?>.broadcast();
  final reactions = <(String, ChatReaction?)>[];
  final memberChanges = <(List<String>, List<String>)>[];

  @override
  Stream<ConversationModel?> watchConversation(
    String conversationId, {
    required String viewerUid,
  }) => meta.stream.map(
    (c) => c == null
        ? null
        : ConversationModel(
            id: c.id,
            participants: c.participants,
            unreadCount: 0,
            kind: c.kind,
            title: c.title,
            description: c.description,
            groupAdminIds: c.groupAdminIds,
          ),
  );

  @override
  Future<void> react({
    required String conversationId,
    required String messageId,
    ChatReaction? reaction,
  }) async => reactions.add((messageId, reaction));

  @override
  Future<void> setMembers({
    required String conversationId,
    List<String> add = const [],
    List<String> remove = const [],
  }) async => memberChanges.add((add, remove));

  @override
  Future<Uint8List?> groupImageBytes(String imagePath) async => null;

  @override
  Future<ChatLibraryPage> libraryPage(
    String conversationId,
    ChatGroupLibraryTab tab, {
    DocumentSnapshot? after,
  }) async => const ChatLibraryPage(items: [], cursor: null, hasMore: false);
}

ChatMediaLoader _loader(FakeChatRepository repo) => ChatMediaLoader(
  DownloadChatMediaUseCase(repo),
  tempDirectory: () async => Directory.systemTemp,
);

void main() {
  group('group chat room', () {
    late FakeChatRepository repo;
    late _FakeGroups groups;

    setUp(() {
      repo = FakeChatRepository();
      groups = _FakeGroups();
    });

    tearDown(() async {
      await repo.messages.close();
      await groups.meta.close();
    });

    Future<void> pump(WidgetTester tester, List<MessageEntity> messages) async {
      final bloc = buildBloc(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatRoomPage(
            conversationId: 'c1',
            otherUserName: 'مجموعة',
            bloc: bloc,
            groups: groups,
            viewerRole: AppRoles.teacher,
            mediaLoader: _loader(repo),
            recorderFactory: FakeRecorder.new,
            pickAttachment: (_) async => null,
          ),
        ),
      );
      await tester.pump();
      groups.meta.add(_group());
      repo.messages.add(Right(messages));
      await tester.pump();
      await tester.pump();
    }

    MessageEntity message(String id, String sender, String text) => MessageEntity(
      id: id,
      conversationId: 'c1',
      senderId: sender,
      text: text,
      sentAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    testWidgets('header shows group title and members; sender names on incoming', (
      tester,
    ) async {
      await pump(tester, [message('m1', 'p1', 'السلام عليكم')]);
      expect(find.text('أولياء الأمور'), findsOneWidget);
      expect(find.textContaining('3 عضو'), findsOneWidget);
      expect(find.text('سارة'), findsOneWidget);
    });

    testWidgets('react and reply through the long-press sheet', (tester) async {
      await pump(tester, [message('m1', 'p1', 'موعد الدرس؟')]);
      await tester.longPress(find.text('موعد الدرس؟'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('react-heart')));
      await tester.pumpAndSettle();
      expect(groups.reactions.single, ('m1', ChatReaction.heart));

      await tester.longPress(find.text('موعد الدرس؟'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action-reply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reply-bar')), findsOneWidget);
      expect(find.text('رد على سارة'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'بعد العصر');
      await tester.pump();
      await tester.tap(find.byTooltip('إرسال'));
      await tester.pump();
      await tester.pump();
      expect(repo.replyIds.single, 'm1');
      expect(find.byKey(const Key('reply-bar')), findsNothing);
    });

    testWidgets('reactions and quoted replies render on the bubble', (tester) async {
      final quoted = MessageEntity(
        id: 'm2',
        conversationId: 'c1',
        senderId: 't1',
        text: 'بعد العصر',
        sentAt: DateTime.now(),
        replyTo: const ChatReplyEntity(
          messageId: 'm1',
          senderId: 'p1',
          type: ChatMessageType.text,
          preview: 'موعد الدرس؟',
        ),
        reactions: const {'p1': ChatReaction.like, 'a1': ChatReaction.like},
      );
      await pump(tester, [quoted]);
      expect(find.text('موعد الدرس؟'), findsOneWidget);
      expect(find.text('👍 2'), findsOneWidget);
    });
  });

  group('delete window policy', () {
    MessageEntity sent(Duration ago, {String sender = 'u1'}) => MessageEntity(
      id: 'm',
      conversationId: 'c',
      senderId: sender,
      text: 'x',
      sentAt: DateTime(2026, 1, 1, 12).subtract(ago),
    );
    final now = DateTime(2026, 1, 1, 12);

    test('sender within an hour; Admin any time; never others', () {
      expect(ChatMediaPolicy.canDelete(sent(const Duration(minutes: 59)), 'u1', isAdmin: false, now: now), isTrue);
      expect(ChatMediaPolicy.canDelete(sent(const Duration(minutes: 61)), 'u1', isAdmin: false, now: now), isFalse);
      expect(ChatMediaPolicy.canDelete(sent(const Duration(days: 3)), 'a1', isAdmin: true, now: now), isTrue);
      expect(ChatMediaPolicy.canDelete(sent(Duration.zero), 'u2', isAdmin: false, now: now), isFalse);
    });
  });

  group('group info page', () {
    late _FakeGroups groups;
    late FakeChatRepository repo;

    setUp(() {
      groups = _FakeGroups();
      repo = FakeChatRepository();
    });

    tearDown(() async {
      await groups.meta.close();
      await repo.messages.close();
    });

    Future<void> pump(WidgetTester tester, String role, ConversationEntity c) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatGroupInfoPage(
            conversationId: 'group_x',
            viewerUid: role == AppRoles.admin ? 'a1' : 'p1',
            viewerRole: role,
            repository: groups,
            loader: _loader(repo),
          ),
        ),
      );
      await tester.pump();
      groups.meta.add(c);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('Admin manages a custom group; removal is confirmed', (tester) async {
      await pump(tester, AppRoles.admin, _group());
      expect(find.byKey(const Key('group-info-title')), findsOneWidget);
      expect(find.text('متابعة أسبوعية'), findsOneWidget);
      expect(find.byKey(const Key('group-add-members')), findsOneWidget);
      expect(find.byKey(const Key('remove-member-a1')), findsNothing);
      await tester.tap(find.byKey(const Key('remove-member-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-remove-member')));
      await tester.pumpAndSettle();
      expect(groups.memberChanges.single.$2, ['p1']);
      await tester.scrollUntilVisible(
        find.text('لا توجد صور مشتركة بعد'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('لا توجد صور مشتركة بعد'), findsOneWidget);
    });

    testWidgets('members see details but no management', (tester) async {
      await pump(tester, AppRoles.parent, _group());
      expect(find.text('أنت'), findsOneWidget);
      expect(find.byKey(const Key('group-add-members')), findsNothing);
      expect(find.byKey(const Key('remove-member-t1')), findsNothing);
    });

    testWidgets('halaqa groups are roster-managed, even for Admin', (tester) async {
      await pump(tester, AppRoles.admin, _group(kind: ConversationKinds.halaqaGroup));
      expect(find.byKey(const Key('group-add-members')), findsNothing);
      expect(find.textContaining('قائمة الحلقة'), findsOneWidget);
    });

    testWidgets('removed member sees loss of access', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatGroupInfoPage(
            conversationId: 'group_x',
            viewerUid: 'p1',
            viewerRole: AppRoles.parent,
            repository: groups,
            loader: _loader(repo),
          ),
        ),
      );
      await tester.pump();
      groups.meta.add(null);
      await tester.pump();
      expect(find.text('لم يعد لديك وصول إلى هذه المجموعة'), findsOneWidget);
    });
  });

  group('create group page', () {
    testWidgets('requires a member; a retry reuses the same request id', (tester) async {
      final requestIds = <String>[];
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminCreateChatGroupPage(
            search: (q) async => [
              const ChatPersonHit(uid: 't1', name: 'أحمد', role: AppRoles.teacher),
            ],
            create: ({
              required requestId,
              required title,
              required description,
              required memberIds,
            }) async {
              requestIds.add(requestId);
              expect(memberIds, ['t1']);
              if (fail) {
                fail = false;
                throw const ServerException('تعذر إنشاء المجموعة');
              }
              return 'group_$requestId';
            },
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('group-title')), 'فريق المعلمين');
      await tester.tap(find.byKey(const Key('group-create')));
      await tester.pump();
      expect(find.text('أضف عضواً واحداً على الأقل'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('chat-person-search')), 'أح');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-person-t1')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('group-create')));
      await tester.tap(find.byKey(const Key('group-create')));
      await tester.pump();
      await tester.pump();
      expect(find.text('تعذر إنشاء المجموعة'), findsOneWidget);
      await tester.tap(find.byKey(const Key('group-create')));
      await tester.pumpAndSettle();
      expect(requestIds, hasLength(2));
      expect(requestIds.toSet(), hasLength(1));
      expect(requestIds.first, matches(RegExp(r'^grp_[0-9a-f]{24}$')));
    });
  });

  group('admin inbox paging', () {
    test('live window + cursor page; threads pushed out of the window stay listed', () async {
      final repo = _PagingRepo();
      final bloc = ChatConversationsBloc(
        watchConversations: WatchConversationsUseCase(repo),
        watchAllConversations: WatchAllConversationsUseCase(repo),
        getOrCreateConversation: GetOrCreateConversationUseCase(repo),
      );
      addTearDown(bloc.close);
      bloc.add(const StartWatchingAllConversationsEvent('a1', pageSize: 2));
      await Future<void>.delayed(Duration.zero);
      expect(repo.limits, [2]);
      repo.live.add(Right([_conv('c3', 3), _conv('c2', 2)]));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.conversations.map((c) => c.id), ['c3', 'c2']);
      expect(bloc.state.hasMoreConversations, isTrue);

      bloc.add(const LoadMoreConversationsEvent());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.cursors, ['c2']);
      expect(bloc.state.conversations.map((c) => c.id), ['c3', 'c2', 'c1']);
      expect(bloc.state.hasMoreConversations, isFalse, reason: 'short page');

      // c4 arrives; c2 leaves the live window but must not disappear.
      repo.live.add(Right([_conv('c4', 4), _conv('c3', 3)]));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.conversations.map((c) => c.id), ['c4', 'c3', 'c2', 'c1']);
    });
  });

  group('wire parsing and list previews', () {
    test('messages carry reply, reactions and link flag; deleted drop reactions', () {
      final m = MessageModel.fromMap('m2', {
        'senderId': 't1',
        'text': 'انظر https://example.org',
        'hasLink': true,
        'replyTo': {'messageId': 'm1', 'senderId': 'p1', 'type': 'image', 'preview': 'صورة'},
        'reactions': {'p1': 'heart', 'x': 'angry'},
      }, conversationId: 'c');
      expect(m.replyTo?.type, ChatMessageType.image);
      expect(m.reactions, {'p1': ChatReaction.heart});
      expect(m.hasLink, isTrue);
      final deleted = MessageModel.fromMap('m3', {
        'deleted': true,
        'reactions': {'p1': 'like'},
      }, conversationId: 'c');
      expect(deleted.reactions, isEmpty);
    });

    test('group conversations parse kind, title and admins', () {
      final c = ConversationModel.fromMap('group_x', {
        'kind': 'custom_group',
        'title': ' أولياء الأمور ',
        'groupAdminIds': ['a1', 3],
        'participants': [
          {'uid': 'p1', 'name': 'سارة', 'role': 'parent'},
        ],
        'lastMessage': 'شكراً',
        'lastMessageSenderId': 'p1',
      }, currentUid: 'a1');
      expect(c.isCustomGroup, isTrue);
      expect(c.displayTitle('a1'), 'أولياء الأمور');
      expect(c.displayTitleForObserver('zz'), 'أولياء الأمور');
      expect(c.groupAdminIds, ['a1']);
      expect(chatListPreview(c, 'a1'), 'سارة: شكراً');
    });

    test('list preview marks own messages and empty threads', () {
      const direct = ConversationEntity(
        id: 'a1_t1',
        participants: [_admin, _teacher],
        unreadCount: 0,
        lastMessage: 'تم',
        lastMessageSenderId: 'a1',
      );
      expect(chatListPreview(direct, 'a1'), 'أنت: تم');
      expect(
        chatListPreview(_group(), 'a1'),
        '3 عضو',
      );
      final now = DateTime(2026, 5, 10, 15);
      expect(chatListTimeLabel(DateTime(2026, 5, 9, 9), now: now), 'أمس');
      expect(chatListTimeLabel(DateTime(2026, 4, 1), now: now), '1/4/2026');
    });
  });
}

ConversationEntity _conv(String id, int minute) => ConversationEntity(
  id: id,
  participants: const [_teacher],
  unreadCount: 0,
  lastMessageAt: DateTime(2026, 1, 1, 0, minute),
);

class _PagingRepo extends Fake implements ChatRepository {
  final live = StreamController<Either<Failure, List<ConversationEntity>>>();
  final limits = <int?>[];
  final cursors = <String>[];

  @override
  Stream<Either<Failure, List<ConversationEntity>>> watchAllConversations({
    required String observerUid,
    int? limit,
  }) {
    limits.add(limit);
    return live.stream;
  }

  @override
  Future<Either<Failure, List<ConversationEntity>>> fetchConversationsAfter({
    String? participantUid,
    required String viewerUid,
    required String afterConversationId,
    required int limit,
  }) async {
    cursors.add(afterConversationId);
    expect(participantUid, isNull, reason: 'academy-wide oversight');
    return Right([_conv('c1', 1)]);
  }
}
