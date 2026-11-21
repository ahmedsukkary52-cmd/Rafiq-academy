import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/error/user_facing_error.dart';
import 'package:rafiq_academy/features/homework/domain/entities/homework_entity.dart';
import 'package:rafiq_academy/features/homework/domain/repositories/homework_repository.dart';
import 'package:rafiq_academy/features/homework/domain/usecases/homework_usecases.dart';
import 'package:rafiq_academy/shared/domain/id_params.dart';

class _FakeHomeworkRepo implements HomeworkRepository {
  _FakeHomeworkRepo(this._onGetLatest);

  final Future<HomeworkEntity?> Function() _onGetLatest;

  @override
  Future<HomeworkEntity?> getLatestHomework(String studentId) => _onGetLatest();

  @override
  Stream<HomeworkEntity?> watchLatestHomework(String studentId) =>
      const Stream.empty();

  @override
  Future<HomeworkEntity> toggleTask({
    required String homeworkId,
    required String taskId,
  }) => throw UnimplementedError();

  @override
  Future<int> completeHomework(String homeworkId) => throw UnimplementedError();

  @override
  Future<HomeworkEntity> submitRecitation(SubmitRecitationParams params) =>
      throw UnimplementedError();
}

void main() {
  test('GetLatestHomeworkUseCase sanitizes technical dumps', () async {
    final result = await GetLatestHomeworkUseCase(
      _FakeHomeworkRepo(() => throw StateError('Bad state: field missing')),
    )(const StudentUidParams('u1'));
    expect(result, isA<Left>());
    result.fold((f) {
      expect(f, isA<ServerFailure>());
      expect(f.message, genericErrorText);
      expect(f.message.contains('Bad state'), isFalse);
    }, (_) => fail('expected failure'));
  });

  test('GetLatestHomeworkUseCase keeps ServerException Arabic copy', () async {
    final result = await GetLatestHomeworkUseCase(
      _FakeHomeworkRepo(() => throw const ServerException('تعذر تحميل الواجب')),
    )(const StudentUidParams('u1'));
    result.fold(
      (f) => expect(f.message, 'تعذر تحميل الواجب'),
      (_) => fail('expected failure'),
    );
  });
}
