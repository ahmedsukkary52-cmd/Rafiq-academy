import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/mushaf_ayah.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/mushaf_position.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/quran_text_bundle.dart';
import 'package:rafiq_academy/features/mushaf/domain/repositories/mushaf_reading_repository.dart';
import 'package:rafiq_academy/features/mushaf/domain/repositories/quran_text_repository.dart';
import 'package:rafiq_academy/features/mushaf/domain/usecases/load_quran_text_usecase.dart';
import 'package:rafiq_academy/features/mushaf/domain/usecases/resolve_mushaf_open_position_usecase.dart';
import 'package:rafiq_academy/features/mushaf/domain/usecases/save_mushaf_position_usecase.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_bloc.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_event.dart';

QuranTextBundle _tinyQuran() {
  const a1 = MushafAyah(
    globalNumber: 1,
    numberInSurah: 1,
    text: 'بِسْمِ',
    page: 1,
    surahNumber: 1,
  );
  const a2 = MushafAyah(
    globalNumber: 8,
    numberInSurah: 1,
    text: 'الم',
    page: 2,
    surahNumber: 2,
  );
  // Sparse pages so page 100 / 604 tests use synthetic pages list length.
  final pages = List<List<MushafAyah>>.generate(604, (i) {
    if (i == 0) return const [a1];
    if (i == 1) return const [a2];
    return [
      MushafAyah(
        globalNumber: 1000 + i,
        numberInSurah: 1,
        text: 'ـ',
        page: i + 1,
        surahNumber: 2,
      ),
    ];
  });
  return QuranTextBundle(
    ayahs: [a1, a2, ...pages.skip(2).expand((e) => e)],
    pagesByIndex: pages,
    surahStartPage: const {1: 1, 2: 2},
  );
}

class _FakeQuranRepo implements QuranTextRepository {
  Either<Failure, QuranTextBundle> result = Right(_tinyQuran());

  @override
  Future<Either<Failure, QuranTextBundle>> loadQuranText() async => result;
}

class _FakeReadingRepo implements MushafReadingRepository {
  MushafPosition? stored;
  int saveCalls = 0;
  List<MushafPosition> saved = [];

  @override
  Future<Either<Failure, MushafPosition?>> getLastRead(String studentId) async {
    return Right(stored);
  }

  @override
  Future<Either<Failure, Unit>> saveLastRead({
    required String studentId,
    required MushafPosition position,
  }) async {
    saveCalls++;
    saved.add(position);
    stored = position;
    return const Right(unit);
  }
}

void main() {
  late _FakeQuranRepo quranRepo;
  late _FakeReadingRepo readingRepo;
  late MushafBloc bloc;

  setUp(() {
    quranRepo = _FakeQuranRepo();
    readingRepo = _FakeReadingRepo();
    bloc = MushafBloc(
      loadQuranText: LoadQuranTextUseCase(quranRepo),
      resolveOpenPosition: ResolveMushafOpenPositionUseCase(readingRepo),
      savePosition: SaveMushafPositionUseCase(readingRepo),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  test('first Mushaf initialization opens Al-Fatihah', () async {
    readingRepo.stored = null;
    bloc.add(const InitializeMushafEvent(studentId: 's1'));
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<dynamic>(
          (s) =>
              s.status == SectionStatus.loaded &&
              s.position == MushafPosition.alFatihah,
        ),
      ),
    );
  });

  test('valid last-read position resumes correctly', () async {
    readingRepo.stored = const MushafPosition(
      pageNumber: 100,
      surahNumber: 4,
      ayahNumber: 5,
    );
    bloc.add(const InitializeMushafEvent(studentId: 's1'));
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<dynamic>(
          (s) =>
              s.status == SectionStatus.loaded &&
              s.position.pageNumber == 100 &&
              s.position.surahNumber == 4,
        ),
      ),
    );
  });

  test('invalid last-read falls back to Al-Fatihah', () async {
    readingRepo.stored = const MushafPosition(
      pageNumber: 999,
      surahNumber: 1,
      ayahNumber: 1,
    );
    bloc.add(const InitializeMushafEvent(studentId: 's1'));
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<dynamic>(
          (s) =>
              s.status == SectionStatus.loaded &&
              s.position == MushafPosition.alFatihah,
        ),
      ),
    );
  });

  test('page navigation rejects 0 and >604; accepts 1 and 604', () async {
    readingRepo.stored = null;
    bloc.add(const InitializeMushafEvent(studentId: 's1'));
    await bloc.stream.firstWhere((s) => s.status == SectionStatus.loaded);

    bloc.add(const MushafGoToPageEvent(0));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.position.pageNumber, 1);

    bloc.add(const MushafGoToPageEvent(605));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.position.pageNumber, 1);

    bloc.add(const MushafGoToPageEvent(604));
    await bloc.stream.firstWhere((s) => s.position.pageNumber == 604);
    expect(bloc.state.position.pageNumber, 604);

    bloc.add(const MushafGoToPageEvent(1));
    await bloc.stream.firstWhere((s) => s.position.pageNumber == 1);
    expect(bloc.state.position.pageNumber, 1);
  });

  test('page change schedules persistence via repository', () async {
    readingRepo.stored = null;
    bloc.add(const InitializeMushafEvent(studentId: 's1'));
    await bloc.stream.firstWhere((s) => s.status == SectionStatus.loaded);

    bloc.add(const MushafGoToPageEvent(42));
    await bloc.stream.firstWhere((s) => s.position.pageNumber == 42);

    // Debounce is 500ms
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(readingRepo.saveCalls, greaterThanOrEqualTo(1));
    expect(readingRepo.saved.last.pageNumber, 42);
  });

  test('Mushaf reading does not expose or mutate memorization progress', () {
    // Architectural isolation: MushafBloc/state have no progress fields.
    expect(bloc.state.props.any((p) => p is double), isFalse);
    final names = bloc.state.toString();
    expect(names.contains('overallProgress'), isFalse);
    expect(names.contains('memorization'), isFalse);
  });
}
