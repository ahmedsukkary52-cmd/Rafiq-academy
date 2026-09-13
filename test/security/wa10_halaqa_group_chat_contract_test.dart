import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/halaqa_group_chat_contract.dart';

void main() {
  group('WA-10 halaqa group chat contract', () {
    test('deterministic conversation id', () {
      expect(
        HalaqaGroupChatContract.conversationIdForHalaqa('h1'),
        'halaqa_group_h1',
      );
      expect(
        HalaqaGroupChatContract.isHalaqaGroupConversationId('halaqa_group_h1'),
        isTrue,
      );
      expect(
        HalaqaGroupChatContract.isHalaqaGroupConversationId('uidA_uidB'),
        isFalse,
      );
    });

    test('empty halaqaId rejected', () {
      expect(
        () => HalaqaGroupChatContract.conversationIdForHalaqa('  '),
        throwsArgumentError,
      );
    });
  });
}
