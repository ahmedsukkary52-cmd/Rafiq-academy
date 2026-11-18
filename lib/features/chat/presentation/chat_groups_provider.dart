import '../../../core/di/injection_container.dart';
import '../data/chat_groups_repository.dart';

/// Composition-root default for group/oversight chat surfaces.
///
/// Resolves the GetIt-registered [ChatGroupsRepository] so presentation never
/// constructs Firebase Storage/Functions clients itself.
ChatGroupsRepository resolveChatGroupsRepository() =>
    sl<ChatGroupsRepository>();
