import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/usecases/content_usecases.dart';
import 'content_event.dart';
import 'content_state.dart';

/// @injectable لأنه ممكن يتفتح لحلقات مختلفة بـ halaqaId مختلف
@injectable
class ContentLibraryBloc
    extends Bloc<ContentLibraryEvent, ContentLibraryState> {
  final GetFilesUseCase getFiles;
  final UploadFileUseCase uploadFile;
  final DeleteFileUseCase deleteFile;

  ContentLibraryBloc({
    required this.getFiles,
    required this.uploadFile,
    required this.deleteFile,
  }) : super(ContentLibraryState.initial()) {
    on<LoadFilesEvent>(_onLoadFiles);
    on<FilterFilesEvent>(_onFilterFiles);
    on<UploadFileEvent>(
      _onUploadFile,
      // droppable: لو في رفع جاري، نتجاهل أي طلب رفع تاني
      transformer: droppable(),
    );
    on<ResetUploadEvent>(_onResetUpload);
    on<DeleteFileEvent>(_onDeleteFile);
  }

  Future<void> _onLoadFiles(
    LoadFilesEvent event,
    Emitter<ContentLibraryState> emit,
  ) async {
    emit(state.copyWith(filesStatus: SectionStatus.loading, filesError: null));

    final result = await getFiles(
      GetFilesParams(
        halaqaId: event.halaqaId,
        filterType: null, // نجيب الكل وبنفلتر محلياً عشان الفلتر يكون فوري
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          filesStatus: SectionStatus.error,
          filesError: failure.message,
        ),
      ),
      (files) => emit(
        state.copyWith(filesStatus: SectionStatus.loaded, allFiles: files),
      ),
    );
  }

  void _onFilterFiles(
    FilterFilesEvent event,
    Emitter<ContentLibraryState> emit,
  ) {
    emit(state.copyWith(activeFilter: event.type));
  }

  Future<void> _onUploadFile(
    UploadFileEvent event,
    Emitter<ContentLibraryState> emit,
  ) async {
    emit(
      state.copyWith(
        uploadStatus: SubmissionStatus.submitting,
        uploadProgress: 0.0,
        uploadError: null,
      ),
    );

    await emit.forEach(
      uploadFile(
        UploadFileParams(
          file: event.file,
          title: event.title,
          type: event.type,
          uploadedBy: event.uploadedBy,
          uploaderName: event.uploaderName,
          halaqaId: event.halaqaId,
        ),
      ),
      onData: (either) => either.fold(
        (failure) => state.copyWith(
          uploadStatus: SubmissionStatus.error,
          uploadError: failure.message,
          uploadProgress: null,
        ),
        (progress) {
          if (progress >= 1.0) {
            // الرفع اكتمل - نضيف الملف الجديد للقائمة بعد reload
            return state.copyWith(
              uploadStatus: SubmissionStatus.success,
              uploadProgress: null,
            );
          }
          return state.copyWith(uploadProgress: progress);
        },
      ),
    );
  }

  void _onResetUpload(
    ResetUploadEvent event,
    Emitter<ContentLibraryState> emit,
  ) {
    emit(
      state.copyWith(
        uploadStatus: SubmissionStatus.idle,
        uploadProgress: null,
        uploadError: null,
      ),
    );
  }

  Future<void> _onDeleteFile(
    DeleteFileEvent event,
    Emitter<ContentLibraryState> emit,
  ) async {
    // Optimistic: نشيل الملف من القائمة فوراً
    final updated = state.allFiles.where((f) => f.id != event.file.id).toList();
    emit(state.copyWith(allFiles: updated));

    await deleteFile(event.file);
  }
}
