import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/content/domain/entities/content_file_entity.dart';
import 'package:rafiq_academy/features/content/domain/repositories/content_library_repository.dart';
import 'package:rafiq_academy/features/content/domain/usecases/content_usecases.dart';
import 'package:rafiq_academy/features/content/presentation/bloc/content_bloc.dart';
import 'package:rafiq_academy/features/content/presentation/pages/content_library_page.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements ContentLibraryRepository {
  Either<Failure, List<ContentFileEntity>> next = const Right([]);
  final requested = <String?>[];

  @override
  Future<Either<Failure, List<ContentFileEntity>>> getFiles({
    String? halaqaId,
    ContentFileType? filterType,
  }) async {
    requested.add(halaqaId);
    return next;
  }

  @override
  Stream<Either<Failure, double>> uploadFile({
    required File file,
    required String title,
    required ContentFileType type,
    required String uploadedBy,
    required String uploaderName,
    String? halaqaId,
  }) => const Stream.empty();

  @override
  Future<Either<Failure, Unit>> deleteFile(ContentFileEntity file) async =>
      const Right(unit);
}

final _student = UserEntity(
  uid: 's1',
  name: 'طالب',
  role: 'student',
  isActive: true,
  createdAt: DateTime(2026),
);

void main() {
  late _Repo repo;

  setUp(() async {
    await sl.reset();
    repo = _Repo();
    sl.registerFactory<ContentLibraryBloc>(
      () => ContentLibraryBloc(
        getFiles: GetFilesUseCase(repo),
        uploadFile: UploadFileUseCase(repo),
        deleteFile: DeleteFileUseCase(repo),
      ),
    );
  });

  tearDown(() async => sl.reset());

  Future<void> pump(WidgetTester tester, {String? halaqaId}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: _AuthBlocStub(AuthAuthenticated(_student)),
          child: ContentLibraryPage(halaqaId: halaqaId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a load failure shows an error with retry, not "no content"', (
    tester,
  ) async {
    repo.next = const Left(ServerFailure('تعذر الاتصال بالخادم'));
    await pump(tester, halaqaId: 'h1');

    expect(find.text('تعذر الاتصال بالخادم'), findsOneWidget);
    expect(find.text('لا يوجد محتوى متاح حالياً'), findsNothing);

    repo.next = const Right([]);
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(repo.requested, ['h1', 'h1']);
    expect(find.text('لا يوجد محتوى متاح حالياً'), findsOneWidget);
  });

  testWidgets('without a halaqa nothing is queried and the reason is shown', (
    tester,
  ) async {
    await pump(tester);

    expect(repo.requested, isEmpty);
    expect(find.text('لا توجد حلقة مرتبطة'), findsOneWidget);
  });
}
