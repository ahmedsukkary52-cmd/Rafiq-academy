import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_embedded_pages.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/chat/data/chat_groups_repository.dart';
import 'package:rafiq_academy/features/chat/data/models/chat_models.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Groups extends Fake implements ChatGroupsRepository {
  final requested = <String>[];
  Object result = const <ConversationModel>[];

  @override
  Future<List<ConversationModel>> myGroups(String uid) async {
    requested.add(uid);
    final r = result;
    if (r is ServerException) throw r;
    return r as List<ConversationModel>;
  }
}

ConversationModel _group(String id, String title, String kind, int members) =>
    ConversationModel(
      id: id,
      participants: [
        for (var i = 0; i < members; i++)
          ChatParticipantEntity(uid: 'u$i', name: 'عضو $i', role: 'parent'),
      ],
      unreadCount: 0,
      kind: kind,
      title: title,
    );

void main() {
  Future<void> pump(
    WidgetTester tester,
    _Groups repo, {
    void Function(ConversationModel)? opened,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: _AuthBlocStub(
            AuthAuthenticated(
              UserEntity(
                uid: 'a1',
                name: 'المدير',
                role: 'admin',
                isActive: true,
                createdAt: DateTime(2026),
              ),
            ),
          ),
          child: AdminGroupLibrariesPage(
            repository: repo,
            onOpen: (_, g) => opened?.call(g),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the admin\'s groups and opens a group library', (
    tester,
  ) async {
    final repo = _Groups()
      ..result = [
        _group('g1', 'أولياء أمور الفجر', ConversationKinds.customGroup, 4),
        _group('h1', 'حلقة الفجر', ConversationKinds.halaqaGroup, 12),
      ];
    ConversationModel? opened;
    await pump(tester, repo, opened: (g) => opened = g);

    expect(repo.requested, ['a1']);
    expect(find.text('أولياء أمور الفجر'), findsOneWidget);
    expect(find.text('مجموعة مخصصة · 4 عضو'), findsOneWidget);
    expect(find.text('مجموعة حلقة · 12 عضو'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-library-h1')));
    expect(opened?.id, 'h1');
  });

  testWidgets('a load failure offers retry; no groups explains how to add one', (
    tester,
  ) async {
    final repo = _Groups()
      ..result = const ServerException('تعذر تحميل المجموعات. تحقق من الاتصال.');
    await pump(tester, repo);
    expect(find.text('تعذر تحميل المجموعات. تحقق من الاتصال.'), findsOneWidget);

    repo.result = const <ConversationModel>[];
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(repo.requested, hasLength(2));
    expect(find.text('لا توجد مجموعات'), findsOneWidget);
  });
}
