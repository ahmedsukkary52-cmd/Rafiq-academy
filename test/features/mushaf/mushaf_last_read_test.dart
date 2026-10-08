import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/mushaf/data/datasources/mushaf_reading_local_mirror.dart';
import 'package:rafiq_academy/features/mushaf/data/datasources/mushaf_reading_remote_datasource.dart';
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
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real Madani juz start pages; surah starts limited to a few anchors.
const _juzStarts = [
  1, 22, 42, 62, 82, 102, 121, 142, 162, 182, //
  201, 222, 242, 262, 282, 302, 322, 342, 362, 382, //
  402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
];
const _surahStarts = {1: 1, 2: 2, 3: 50, 78: 582, 114: 604};

QuranTextBundle _contiguousQuran() {
  int surahFor(int page) =>
      _surahStarts.entries.where((e) => e.value <= page).last.key;
  int juzFor(int page) => _juzStarts.lastIndexWhere((p) => p <= page) + 1;

  final pages = List<List<MushafAyah>>.generate(604, (i) {
    final page = i + 1;
    return [
      MushafAyah(
        globalNumber: page,
        numberInSurah: _surahStarts[surahFor(page)] == page ? 1 : page,
        text: 'ص$page',
        page: page,
        surahNumber: surahFor(page),
        juz: juzFor(page),
      ),
    ];
  });
  return QuranTextBundle(
    ayahs: pages.expand((p) => p).toList(),
    pagesByIndex: pages,
    surahStartPage: _surahStarts,
    juzStartPage: {
      for (var j = 0; j < _juzStarts.length; j++) j + 1: _juzStarts[j],
    },
  );
}

class _FakeQuranRepo implements QuranTextRepository {
  final bundle = _contiguousQuran();

  @override
  Future<Either<Failure, QuranTextBundle>> loadQuranText() async =>
      Right(bundle);
}

class _ScopedReadingRepo implements MushafReadingRepository {
  final Map<String, MushafPosition> stored = {};
  final List<(String, MushafPosition)> saves = [];
  final Map<String, Completer<void>> gates = {};
  bool failReads = false;

  @override
  Future<Either<Failure, MushafPosition?>> getLastRead(String studentId) async {
    final gate = gates[studentId];
    if (gate != null) await gate.future;
    if (failReads) return const Left(ServerFailure('offline'));
    return Right(stored[studentId]);
  }

  @override
  Future<Either<Failure, Unit>> saveLastRead({
    required String studentId,
    required MushafPosition position,
  }) async {
    saves.add((studentId, position));
    stored[studentId] = position;
    return const Right(unit);
  }
}

const _afterDebounce = Duration(milliseconds: 650);

void main() {
  late _ScopedReadingRepo reading;
  late MushafBloc bloc;

  setUp(() {
    reading = _ScopedReadingRepo();
    bloc = MushafBloc(
      loadQuranText: LoadQuranTextUseCase(_FakeQuranRepo()),
      resolveOpenPosition: ResolveMushafOpenPositionUseCase(reading),
      savePosition: SaveMushafPositionUseCase(reading),
    );
  });

  tearDown(() => bloc.close());

  Future<MushafState> open(String studentId) async {
    bloc.add(InitializeMushafEvent(studentId: studentId));
    return bloc.stream.firstWhere(
      (s) => s.status == SectionStatus.loaded && s.studentId == studentId,
    );
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('D. Last-read open resolution', () {
    test(
      'first open (no C15 doc) resolves Al-Fatihah and writes nothing',
      () async {
        final s = await open('A');
        expect(s.position, MushafPosition.alFatihah);
        expect(s.resumePosition, MushafPosition.alFatihah);
        await Future<void>.delayed(_afterDebounce);
        expect(reading.saves, isEmpty);
      },
    );

    test('valid saved position resumes and is not rewritten', () async {
      const saved = MushafPosition(
        pageNumber: 100,
        surahNumber: 4,
        ayahNumber: 5,
      );
      reading.stored['A'] = saved;
      final s = await open('A');
      expect(s.position, saved);
      expect(s.resumePosition, saved);
      await Future<void>.delayed(_afterDebounce);
      expect(reading.saves, isEmpty);
    });

    test('corrupt saved position falls back to Al-Fatihah', () async {
      reading.stored['A'] = const MushafPosition(
        pageNumber: 0,
        surahNumber: 200,
        ayahNumber: 1,
      );
      final s = await open('A');
      expect(s.position, MushafPosition.alFatihah);
    });

    test('read failure falls back to Al-Fatihah', () async {
      reading.failReads = true;
      final s = await open('A');
      expect(s.position, MushafPosition.alFatihah);
    });
  });

  group('D. Student scoping', () {
    test('student A never resumes student B page', () async {
      reading.stored['A'] = const MushafPosition(
        pageNumber: 100,
        surahNumber: 4,
        ayahNumber: 1,
      );
      reading.stored['B'] = const MushafPosition(
        pageNumber: 300,
        surahNumber: 18,
        ayahNumber: 1,
      );
      expect((await open('A')).position.pageNumber, 100);
      final b = await open('B');
      expect(b.position.pageNumber, 300);
      expect(b.studentId, 'B');

      final c = await open('C');
      expect(c.position, MushafPosition.alFatihah);
    });

    test(
      'pending write on student switch is saved for the old student only',
      () async {
        await open('A');
        bloc.add(const MushafGoToPageEvent(50));
        await settle();
        final b = await open('B');
        expect(b.position, MushafPosition.alFatihah);

        await Future<void>.delayed(_afterDebounce);
        expect(reading.saves.map((s) => s.$1), ['A']);
        expect(reading.saves.single.$2.pageNumber, 50);
        expect(reading.stored.containsKey('B'), isFalse);
      },
    );

    test('a slow earlier open cannot overwrite the newer student', () async {
      reading.stored['A'] = const MushafPosition(
        pageNumber: 100,
        surahNumber: 4,
        ayahNumber: 1,
      );
      reading.stored['B'] = const MushafPosition(
        pageNumber: 300,
        surahNumber: 18,
        ayahNumber: 1,
      );
      reading.gates['A'] = Completer<void>();
      bloc.add(const InitializeMushafEvent(studentId: 'A'));
      await settle();
      await open('B');
      reading.gates['A']!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.studentId, 'B');
      expect(bloc.state.position.pageNumber, 300);
    });

    test('navigation before load is ignored', () async {
      bloc.add(const MushafGoToSurahEvent(2));
      bloc.add(const MushafGoToJuzEvent(30));
      bloc.add(const MushafGoToPageEvent(10));
      await settle();
      expect(bloc.state.status, SectionStatus.initial);
      expect(bloc.state.position, MushafPosition.alFatihah);
      await Future<void>.delayed(_afterDebounce);
      expect(reading.saves, isEmpty);
    });
  });

  group('D. Debounced meaningful writes', () {
    test(
      'rapid page changes collapse into one write of the last page',
      () async {
        await open('A');
        bloc
          ..add(const MushafGoToPageEvent(10))
          ..add(const MushafGoToPageEvent(11))
          ..add(const MushafGoToPageEvent(12));
        await settle();
        expect(reading.saves, isEmpty);
        await Future<void>.delayed(_afterDebounce);
        expect(reading.saves, hasLength(1));
        expect(reading.saves.single.$1, 'A');
        expect(reading.saves.single.$2.pageNumber, 12);
      },
    );

    test('re-selecting the current page neither emits nor writes', () async {
      await open('A');
      final emitted = <MushafState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(const MushafGoToPageEvent(1));
      await Future<void>.delayed(_afterDebounce);
      await sub.cancel();
      expect(emitted, isEmpty);
      expect(reading.saves, isEmpty);
    });

    test('returning to the already-saved position is not rewritten', () async {
      await open('A');
      bloc.add(const MushafGoToPageEvent(20));
      await Future<void>.delayed(_afterDebounce);
      bloc.add(const MushafGoToPageEvent(21));
      await settle();
      bloc.add(const MushafGoToPageEvent(20));
      await Future<void>.delayed(_afterDebounce);
      expect(reading.saves.map((s) => s.$2.pageNumber), [20]);
    });
  });

  group('Navigation events', () {
    test('surah jump opens at ayah 1 of the surah start page', () async {
      await open('A');
      bloc.add(const MushafGoToSurahEvent(3));
      final s = await bloc.stream.firstWhere(
        (s) => s.position.pageNumber == 50,
      );
      expect(s.position.surahNumber, 3);
      expect(s.position.ayahNumber, 1);
    });

    test('juz 1, middle, juz 30 and invalid values', () async {
      await open('A');
      bloc.add(const MushafGoToJuzEvent(30));
      await bloc.stream.firstWhere((s) => s.position.pageNumber == 582);
      bloc.add(const MushafGoToJuzEvent(15));
      await bloc.stream.firstWhere((s) => s.position.pageNumber == 282);
      bloc.add(const MushafGoToJuzEvent(1));
      await bloc.stream.firstWhere((s) => s.position.pageNumber == 1);

      bloc
        ..add(const MushafGoToJuzEvent(0))
        ..add(const MushafGoToJuzEvent(31));
      await settle();
      expect(bloc.state.position.pageNumber, 1);
    });

    test('explicit jumps remember the left position; swipes do not', () async {
      reading.stored['A'] = const MushafPosition(
        pageNumber: 100,
        surahNumber: 4,
        ayahNumber: 5,
      );
      await open('A');

      bloc.add(const MushafGoToPageEvent(101));
      await bloc.stream.firstWhere((s) => s.position.pageNumber == 101);
      expect(bloc.state.resumePosition?.pageNumber, 100);

      bloc.add(const MushafGoToSurahEvent(2));
      await bloc.stream.firstWhere((s) => s.position.pageNumber == 2);
      expect(bloc.state.resumePosition?.pageNumber, 101);

      bloc.add(const MushafResumeLastReadEvent());
      await bloc.stream.firstWhere((s) => s.position.pageNumber == 101);
      expect(bloc.state.resumePosition?.pageNumber, 2);

      bloc.add(const MushafGoToPageEvent(400, fromNavigation: true));
      await bloc.stream.firstWhere((s) => s.position.pageNumber == 400);
      expect(bloc.state.resumePosition?.pageNumber, 101);
    });
  });

  group('Local mirror (per student)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const pos = MushafPosition(pageNumber: 77, surahNumber: 7, ayahNumber: 3);

    test('is scoped per student', () async {
      final mirror = MushafReadingPrefsMirror();
      await mirror.write('A', pos);
      expect(await mirror.read('A'), pos);
      expect(await mirror.read('B'), isNull);
      expect(await mirror.read(''), isNull);
    });

    test('ignores and clears the unscoped legacy page key', () async {
      SharedPreferences.setMockInitialValues({kLegacyLastMushafPageKey: 300});
      final mirror = MushafReadingPrefsMirror();
      expect(await mirror.read('A'), isNull);
      await mirror.write('A', pos);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kLegacyLastMushafPageKey), isFalse);
    });

    test('corrupt or out-of-range values read as null', () async {
      SharedPreferences.setMockInitialValues({
        MushafReadingPrefsMirror.keyFor('A'): 'garbage',
        MushafReadingPrefsMirror.keyFor('B'): '999:1:1',
        MushafReadingPrefsMirror.keyFor('C'): '10:0:1',
      });
      final mirror = MushafReadingPrefsMirror();
      expect(await mirror.read('A'), isNull);
      expect(await mirror.read('B'), isNull);
      expect(await mirror.read('C'), isNull);
    });
  });

  group('C15 document parsing', () {
    test('valid document', () {
      expect(
        MushafReadingRemoteDatasourceImpl.positionFromDoc({
          'pageNumber': 5,
          'surahNumber': 2,
          'ayahNumber': 25,
        }),
        const MushafPosition(pageNumber: 5, surahNumber: 2, ayahNumber: 25),
      );
    });

    test('missing or malformed documents yield null', () {
      final bad = <Map<String, dynamic>?>[
        null,
        {},
        {'pageNumber': 5},
        {'pageNumber': '5', 'surahNumber': 2, 'ayahNumber': 1},
        {'pageNumber': 0, 'surahNumber': 1, 'ayahNumber': 1},
        {'pageNumber': 605, 'surahNumber': 1, 'ayahNumber': 1},
        {'pageNumber': 5, 'surahNumber': 115, 'ayahNumber': 1},
        {'pageNumber': 5, 'surahNumber': 2, 'ayahNumber': 0},
      ];
      for (final doc in bad) {
        expect(
          MushafReadingRemoteDatasourceImpl.positionFromDoc(doc),
          isNull,
          reason: '$doc',
        );
      }
    });

    test('last-read code never reads memorization progress', () {
      final dir = Directory('lib/features/mushaf');
      final sources = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map(
            (f) => f
                .readAsLinesSync()
                .where((l) => !l.trimLeft().startsWith('//'))
                .join('\n'),
          );
      for (final code in sources) {
        expect(code.toLowerCase().contains('memoriz'), isFalse);
        expect(code.contains('overallProgress'), isFalse);
        expect(RegExp(r"import '.*progress.*'").hasMatch(code), isFalse);
      }
    });
  });
}
