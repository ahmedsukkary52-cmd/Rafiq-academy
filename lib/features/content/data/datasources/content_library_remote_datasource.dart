import 'dart:io';

import '../../domain/entities/content_file_entity.dart';
import '../models/content_file_model.dart';

abstract class ContentLibraryRemoteDatasource {
  Future<List<ContentFileModel>> getFiles({
    String? halaqaId,
    ContentFileType? filterType,
  });

  Stream<double> uploadFile({
    required File file,
    required String title,
    required ContentFileType type,
    required String uploadedBy,
    required String uploaderName,
    String? halaqaId,
  });

  Future<void> deleteFile(ContentFileEntity file);
}
