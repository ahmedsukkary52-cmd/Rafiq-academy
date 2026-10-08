import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/mushaf_position.dart';
import 'package:rafiq_academy/features/mushaf/domain/repositories/mushaf_reading_repository.dart';
import 'package:rafiq_academy/features/mushaf/domain/usecases/resolve_mushaf_open_position_usecase.dart';
import 'package:rafiq_academy/features/mushaf/domain/usecases/save_mushaf_position_usecase.dart';

class _FakeReadingRepo implements MushafReadingRepository {
  MushafPosition? stored;
  Either<Failure, MushafPosition?> getResult = const Right(null);
  Either<Failure, Unit> saveResult = const Right(unit);
  SaveMushafPositionParams? lastSave;
  int saveCalls = 0;

  @override
  Future<Either<Failure, MushafPosition?>> getLastRead(String studentId) async {
    return getResult;
  }

  @override
  Future<Either<Failure, Unit>> saveLastRead({
    required String studentId,
    required MushafPosition position,
  }) async {
    saveCalls++;
    lastSave = SaveMushafPositionParams(
      studentId: studentId,
      position: position,
    );
    stored = position;
    return saveResult;
  }
}

void main() {
  late _FakeReadingRepo repo;
  late ResolveMushafOpenPositionUseCase resolve;
  late SaveMushafPositionUseCase save;

  setUp(() {
    repo = _FakeReadingRepo();
    resolve = ResolveMushafOpenPositionUseCase(repo);
    save = SaveMushafPositionUseCase(repo);
  });

  test('first open (no last-read) resolves Al-Fatihah', () async {
    repo.getResult = const Right(null);
    final result = await resolve(const StudentIdParams('student-1'));
    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected right'), (pos) {
      expect(pos, MushafPosition.alFatihah);
      expect(pos.pageNumber, 1);
      expect(pos.surahNumber, 1);
    });
  });

  test('valid last-read resumes correctly', () async {
    const stored = MushafPosition(
      pageNumber: 100,
      surahNumber: 4,
      ayahNumber: 12,
    );
    repo.getResult = const Right(stored);
    final result = await resolve(const StudentIdParams('student-1'));
    result.fold((_) => fail('expected right'), (pos) {
      expect(pos, stored);
    });
  });

  test('invalid last-read falls back to Al-Fatihah', () async {
    const bad = MushafPosition(pageNumber: 999, surahNumber: 1, ayahNumber: 1);
    repo.getResult = const Right(bad);
    final result = await resolve(const StudentIdParams('student-1'));
    result.fold((_) => fail('expected right'), (pos) {
      expect(pos, MushafPosition.alFatihah);
    });
  });

  test('save last-read calls repository with valid position', () async {
    const position = MushafPosition(
      pageNumber: 50,
      surahNumber: 2,
      ayahNumber: 10,
    );
    final result = await save(
      const SaveMushafPositionParams(
        studentId: 'student-1',
        position: position,
      ),
    );
    expect(result.isRight(), isTrue);
    expect(repo.saveCalls, 1);
    expect(repo.lastSave?.studentId, 'student-1');
    expect(repo.lastSave?.position, position);
  });

  test('save rejects page 0', () async {
    final result = await save(
      const SaveMushafPositionParams(
        studentId: 'student-1',
        position: MushafPosition(pageNumber: 0, surahNumber: 1, ayahNumber: 1),
      ),
    );
    expect(result.isLeft(), isTrue);
    expect(repo.saveCalls, 0);
  });
}
