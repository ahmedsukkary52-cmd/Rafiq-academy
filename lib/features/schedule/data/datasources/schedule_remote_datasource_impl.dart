import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/halaqa_schedule_source_model.dart';
import 'schedule_remote_datasource.dart';

@LazySingleton(as: ScheduleRemoteDatasource)
class ScheduleRemoteDatasourceImpl implements ScheduleRemoteDatasource {
  final FirebaseFirestore firestore;

  ScheduleRemoteDatasourceImpl(this.firestore);

  @override
  Future<HalaqaScheduleSourceModel?> getHalaqaScheduleSource(
      String halaqaId,) async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data() ?? <String, dynamic>{};
      final rawSchedule = data['schedule'] as List<dynamic>? ?? const [];

      return HalaqaScheduleSourceModel(
        halaqaId: doc.id,
        name: (data['name'] as String?)?.trim() ?? '',
        meetingLink: (data['meetingLink'] as String?)?.trim() ?? '',
        schedule: rawSchedule
            .whereType<Map>()
            .map(
              (e) =>
              HalaqaScheduleSlotModel.fromMap(
                Map<String, dynamic>.from(e),
              ),
        )
            .toList(),
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
