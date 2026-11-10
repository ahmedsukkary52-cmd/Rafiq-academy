import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/content/domain/content_upload_policy.dart';
import 'package:rafiq_academy/features/content/domain/entities/content_file_entity.dart';
import 'package:rafiq_academy/features/content/domain/repositories/content_library_repository.dart';
import 'package:rafiq_academy/features/content/domain/usecases/content_usecases.dart';
import 'package:rafiq_academy/features/content/presentation/bloc/content_bloc.dart';
import 'package:rafiq_academy/features/content/presentation/bloc/content_event.dart';
import 'package:rafiq_academy/features/content/presentation/pages/content_library_page.dart';

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements ContentLibraryRepository {
  List<ContentFileEntity> files = [];
  final uploads = <List<Either<Failure, double>>>[];
  final uploadTitles = <String>[];
  Either<Failure, Unit> deleteResult = const Right(unit);
  int loads = 0;

  @override
  Future<Either<Failure, List<ContentFileEntity>>> getFiles({
    String? halaqaId,
    ContentFileType? filterType,
  }) async {
    loads++;
    return Right(List.of(files));
  }

  @override
  Stream<Either<Failure, double>> uploadFile({
    required File file,
    required String title,
    required ContentFileType type,
    required String uploadedBy,
    required String uploaderName,
    String? halaqaId,
  }) {
    uploadTitles.add(title);
    final script = uploads.isEmpty
        ? const <Either<Failure, double>>[]
        : uploads.removeAt(0);
    return Stream.fromIterable(script);
  }

  @override
  Future<Either<Failure, Unit>> deleteFile(ContentFileEntity file) async =>
      deleteResult;
}

ContentFileEntity _file(String id, String title, ContentFileType type) =>
    ContentFileEntity(
      id: id,
      title: title,
      type: type,
      downloadUrl: 'https://example.invalid/$id',
      storagePath: 'content_library/h1/t1/$id.pdf',
      fileSizeMb: 1.2,
      uploadedBy: 't1',
      uploaderName: 'الأستاذ خالد',
      uploadedAt: DateTime(2026, 10, 1),
      halaqaId: 'h1',
    );

final _upload = UploadFileEvent(
  file: File('lesson.pdf'),
  title: 'درس التجويد',
  type: ContentFileType.pdf,
  uploadedBy: 't1',
  uploaderName: 'الأستاذ خالد',
  halaqaId: 'h1',
);

ContentLibraryBloc _bloc(_Repo repo) => ContentLibraryBloc(
  getFiles: GetFilesUseCase(repo),
  uploadFile: UploadFileUseCase(repo),
  deleteFile: DeleteFileUseCase(repo),
);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('ContentLibraryBloc upload', () {
    test('a transfer that ends without success is a retryable failure', () async {
      final repo = _Repo()..uploads.add(const [Right(0.0), Right(0.4)]);
      final bloc = _bloc(repo)..add(_upload);
      await _settle();

      expect(bloc.state.uploadStatus, SubmissionStatus.error);
      expect(bloc.state.uploadError, ContentUploadErrors.incomplete);
      expect(bloc.state.uploadProgress, isNull);
      expect(bloc.state.canRetryUpload, isTrue);
      await bloc.close();
    });

    test('retry re-sends the same upload and succeeds', () async {
      final repo = _Repo()
        ..uploads.add(const [Right(0.0), Left(ServerFailure(ContentUploadErrors.network))])
        ..uploads.add(const [Right(0.0), Right(0.5), Right(1.0)]);
      final bloc = _bloc(repo)..add(_upload);
      await _settle();
      expect(bloc.state.uploadError, ContentUploadErrors.network);
      expect(bloc.state.canRetryUpload, isTrue);

      bloc.add(const RetryUploadEvent());
      await _settle();

      expect(repo.uploadTitles, ['درس التجويد', 'درس التجويد']);
      expect(bloc.state.uploadStatus, SubmissionStatus.success);
      expect(bloc.state.uploadError, isNull);
      await bloc.close();
    });

    test('a permission refusal is shown but not offered as a retry', () async {
      final repo = _Repo()
        ..uploads.add(const [Left(ServerFailure(ContentUploadErrors.denied))]);
      final bloc = _bloc(repo)..add(_upload);
      await _settle();

      expect(bloc.state.uploadError, ContentUploadErrors.denied);
      expect(bloc.state.canRetryUpload, isFalse);
      bloc.add(const RetryUploadEvent());
      await _settle();
      expect(repo.uploadTitles, hasLength(1));
      await bloc.close();
    });

    test('a failed delete restores the file and reports why', () async {
      final repo = _Repo()
        ..files = [_file('f1', 'درس', ContentFileType.pdf)]
        ..deleteResult = const Left(ServerFailure('لا تملك صلاحية حذف هذا الملف'));
      final bloc = _bloc(repo)..add(const LoadFilesEvent(halaqaId: 'h1'));
      await _settle();

      bloc.add(DeleteFileEvent(repo.files.single));
      await _settle();

      expect(bloc.state.allFiles.map((f) => f.id), ['f1']);
      expect(bloc.state.deleteError, 'لا تملك صلاحية حذف هذا الملف');
      await bloc.close();
    });
  });

  test('Firebase storage codes map to Arabic messages', () {
    expect(ContentUploadErrors.forCode('unauthorized'), ContentUploadErrors.denied);
    expect(
      ContentUploadErrors.forCode('retry-limit-exceeded'),
      ContentUploadErrors.network,
    );
    expect(ContentUploadErrors.forCode('canceled'), ContentUploadErrors.canceled);
    expect(
      ContentUploadErrors.forCode('quota-exceeded'),
      ContentUploadErrors.unavailable,
    );
    expect(ContentUploadErrors.forCode('weird'), ContentUploadErrors.generic);
  });

  group('ContentLibraryPage', () {
    late _Repo repo;
    ContentLibraryBloc? created;

    setUp(() async {
      await sl.reset();
      repo = _Repo();
      sl.registerFactory<ContentLibraryBloc>(() => created = _bloc(repo));
    });

    tearDown(() async => sl.reset());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: BlocProvider<AuthBloc>.value(
            value: _AuthBlocStub(
              AuthAuthenticated(
                UserEntity(
                  uid: 't1',
                  name: 'الأستاذ خالد',
                  role: 'teacher',
                  isActive: true,
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            child: const ContentLibraryPage(halaqaId: 'h1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('"All" is the first tab in RTL; video only for existing items', (
      tester,
    ) async {
      repo.files = [_file('f1', 'درس', ContentFileType.pdf)];
      await pump(tester);

      final all = tester.getCenter(find.byKey(const Key('content-tab-all')));
      final pdf = tester.getCenter(find.byKey(const Key('content-tab-pdf')));
      expect(all.dx, greaterThan(pdf.dx), reason: 'RTL starts on the right');
      expect(find.byKey(const Key('content-tab-video')), findsNothing);

      repo.files = [
        _file('f1', 'درس', ContentFileType.pdf),
        _file('v1', 'تسجيل قديم', ContentFileType.video),
      ];
      created!.add(const LoadFilesEvent(halaqaId: 'h1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-tab-video')), findsOneWidget);
    });

    testWidgets('search filters by title and explains an empty result', (
      tester,
    ) async {
      repo.files = [
        _file('f1', 'أحكام النون الساكنة', ContentFileType.pdf),
        _file('f2', 'تلاوة سورة الملك', ContentFileType.audio),
      ];
      await pump(tester);

      await tester.enterText(find.byKey(const Key('content-search')), 'الملك');
      await tester.pumpAndSettle();
      expect(find.text('تلاوة سورة الملك'), findsWidgets);
      expect(find.text('أحكام النون الساكنة'), findsOneWidget,
          reason: 'only in the recent-uploads strip');

      await tester.enterText(find.byKey(const Key('content-search')), 'غير موجود');
      await tester.pumpAndSettle();
      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
    });

    testWidgets('a failed upload stays visible with retry until it succeeds', (
      tester,
    ) async {
      repo
        ..uploads.add(const [Right(0.0), Right(0.3)])
        ..uploads.add(const [Right(0.0), Right(1.0)]);
      await pump(tester);

      created!.add(_upload);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-upload-failed')), findsOneWidget);
      expect(find.textContaining(ContentUploadErrors.incomplete), findsOneWidget);

      final loadsBefore = repo.loads;
      await tester.tap(find.byKey(const Key('content-upload-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('content-upload-failed')), findsNothing);
      expect(find.text('تم رفع الملف'), findsOneWidget);
      expect(repo.loads, loadsBefore + 1, reason: 'list refreshed after success');
    });

    testWidgets('delete asks first and restores the file when refused', (
      tester,
    ) async {
      repo
        ..files = [_file('f1', 'درس التجويد', ContentFileType.pdf)]
        ..deleteResult = const Left(ServerFailure('لا تملك صلاحية حذف هذا الملف'));
      await pump(tester);

      await tester.tap(find.byKey(const Key('content-delete-f1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('لا تملك صلاحية حذف هذا الملف'), findsOneWidget);
      expect(find.byKey(const Key('content-delete-f1')), findsOneWidget);
    });
  });
}
