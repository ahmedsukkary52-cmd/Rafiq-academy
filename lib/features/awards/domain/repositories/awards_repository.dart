import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/award_entities.dart';

abstract class AwardsRepository {
  /// جلب إحصائيات الجوائز للحلقة
  Future<Either<Failure, AwardsStatsEntity>> getAwardsStats(String halaqaId);

  /// جلب سجل الجوائز الممنوحة للحلقة (مرتبة بالأحدث)
  Future<Either<Failure, List<GrantedAwardEntity>>> getGrantedAwards(
    String halaqaId,
  );

  /// منح جائزة لطالب
  Future<Either<Failure, Unit>> grantAward(GrantedAwardEntity award);

  /// توليد ملف PDF لشهادة تقدير وإرجاعه كـ bytes
  /// (الحفظ أو المشاركة مسؤولية الـ UI باستخدام printing package)
  Future<Either<Failure, List<int>>> generateCertificatePdf(
    CertificateDataEntity data,
  );
}
