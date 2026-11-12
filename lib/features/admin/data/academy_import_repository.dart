import 'package:cloud_functions/cloud_functions.dart';

import '../domain/academy_import.dart';

enum ImportRowStatus { created, existing, failed }

class ImportRowOutcome {
  final ImportRow row;
  final ImportRowStatus status;
  final String message;
  final bool retryable;

  /// One-time credential for an account created in this call; never stored.
  final String? username;
  final String? temporaryPassword;

  const ImportRowOutcome({
    required this.row,
    required this.status,
    required this.message,
    this.retryable = false,
    this.username,
    this.temporaryPassword,
  });

  bool get hasCredential => username != null && temporaryPassword != null;
}

const _retryableCodes = {
  'unavailable',
  'internal',
  'aborted',
  'deadline-exceeded',
  'resource-exhausted',
};

/// Sends one validated row to `adminImportAcademyRow` (idempotent by ref).
class AcademyImportRepository {
  AcademyImportRepository({required this.functions});

  final FirebaseFunctions functions;

  Future<ImportRowOutcome> importRow(String importId, ImportRow row) async {
    try {
      final res = await functions
          .httpsCallable('adminImportAcademyRow')
          .call<dynamic>({'importId': importId, 'row': row.toPayload()});
      final data = Map<String, dynamic>.from(res.data as Map);
      final credential = data['credential'] is Map
          ? Map<String, dynamic>.from(data['credential'] as Map)
          : null;
      return ImportRowOutcome(
        row: row,
        status: switch (data['status']) {
          'created' => ImportRowStatus.created,
          'existing' => ImportRowStatus.existing,
          _ => ImportRowStatus.failed,
        },
        message: data['message'] as String? ?? '',
        retryable: data['retryable'] == true,
        username: credential?['username'] as String?,
        temporaryPassword: credential?['temporaryPassword'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim() ?? '';
      return ImportRowOutcome(
        row: row,
        status: ImportRowStatus.failed,
        message: message.isEmpty || RegExp('[A-Za-z]{6,}').hasMatch(message)
            ? 'تعذر معالجة السجل'
            : message,
        retryable: _retryableCodes.contains(e.code),
      );
    } catch (_) {
      return ImportRowOutcome(
        row: row,
        status: ImportRowStatus.failed,
        message: 'انقطع الاتصال أثناء المعالجة',
        retryable: true,
      );
    }
  }
}
