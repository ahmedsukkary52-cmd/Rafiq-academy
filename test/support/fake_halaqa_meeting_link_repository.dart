import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/shared/domain/halaqa_meeting_link.dart';

/// In-memory `halaqaMeetingLinks` source: a halaqa id absent from [links]
/// behaves like a missing document; [failure] fails every read.
class FakeHalaqaMeetingLinkRepository implements HalaqaMeetingLinkRepository {
  final Map<String, String> links;
  Failure? failure;
  final reads = <String>[];

  FakeHalaqaMeetingLinkRepository([Map<String, String>? links])
    : links = links ?? {};

  @override
  Future<Either<Failure, HalaqaMeetingLink?>> getMeetingLink(
    String halaqaId,
  ) async {
    reads.add(halaqaId);
    if (failure != null) return Left(failure!);
    final link = links[halaqaId];
    if (link == null) return const Right(null);
    return Right(HalaqaMeetingLink(halaqaId: halaqaId, meetingLink: link));
  }
}

/// Registers [repo] behind [GetHalaqaMeetingLinkUseCase] in `sl`.
void registerFakeMeetingLinks(FakeHalaqaMeetingLinkRepository repo) {
  if (sl.isRegistered<GetHalaqaMeetingLinkUseCase>()) {
    sl.unregister<GetHalaqaMeetingLinkUseCase>();
  }
  sl.registerFactory<GetHalaqaMeetingLinkUseCase>(
    () => GetHalaqaMeetingLinkUseCase(repo),
  );
}
