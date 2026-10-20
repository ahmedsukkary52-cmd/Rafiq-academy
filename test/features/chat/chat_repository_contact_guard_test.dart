import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:rafiq_academy/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_media_policy.dart';
import 'package:rafiq_academy/shared/domain/contact_info_policy.dart';

import '../../support/fake_callables.dart';

/// Any datasource call throws, so a rejected write proves it never left the
/// repository.
class _Ds extends Fake implements ChatRemoteDatasource {}

/// UX guard only: `sendChatMessage` / `editChatMessage` enforce the policy.
void main() {
  const phone = 'تواصل معي 0501234567';
  const waLink = 'https://wa.me/966501234567';
  const academic = 'سورة البقرة الآيات 1-20، الدرجة 95/100';
  const rejected = Left<Failure, Unit>(
    ValidationFailure(contactInfoRejectionMessage),
  );
  const offline = Left<Failure, Unit>(NetworkFailure());

  late ChatRepositoryImpl repo;

  setUp(() {
    repo = ChatRepositoryImpl(
      remoteDatasource: _Ds(),
      networkInfo: FakeNetworkInfo(connected: false),
    );
  });

  Future<Either<Failure, Unit>> send(String text, {String? fileName}) =>
      repo.sendMessage(
        conversationId: 'c1',
        messageId: 'msg_abcdefghij',
        type: fileName == null ? ChatMessageType.text : ChatMessageType.file,
        text: text,
        media: fileName == null
            ? null
            : ChatSendMedia(
                storagePath: 'chat_attachments/c1/msg_abcdefghij/file.pdf',
                fileName: fileName,
              ),
      );

  test('send rejects contact info in text and attachment names', () async {
    expect(await send(phone), rejected);
    expect(await send(waLink), rejected);
    expect(await send('', fileName: '0501234567.pdf'), rejected);
  });

  test('send lets academic text and file names through the guard', () async {
    expect(await send(academic), offline);
    expect(await send('', fileName: 'الواجب 2026-10-15.pdf'), offline);
  });

  test('edit rejects contact info and allows academic text', () async {
    Future<Either<Failure, Unit>> edit(String text) => repo.editMessage(
      conversationId: 'c1',
      messageId: 'msg_abcdefghij',
      text: text,
    );
    expect(await edit(phone), rejected);
    expect(await edit('tel:123'), rejected);
    expect(await edit(academic), offline);
  });
}
