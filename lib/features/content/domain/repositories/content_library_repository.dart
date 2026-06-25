import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/content_file_entity.dart';

abstract class ContentLibraryRepository {
  /// جلب ملفات المكتبة (مع فلترة اختيارية بالنوع أو الحلقة)
  Future<Either<Failure, List<ContentFileEntity>>> getFiles({
    String? halaqaId,
    ContentFileType? filterType,
  });

  /// رفع ملف جديد على Firebase Storage وحفظ metadata في Firestore
  /// بيرجع Stream<double> لتتبع نسبة الرفع (0.0 → 1.0)
  Stream<Either<Failure, double>> uploadFile({
    required File file,
    required String title,
    required ContentFileType type,
    required String uploadedBy,
    required String uploaderName,
    String? halaqaId,
  });

  /// حذف ملف من Storage وFirestore معاً
  Future<Either<Failure, Unit>> deleteFile(ContentFileEntity file);
}
