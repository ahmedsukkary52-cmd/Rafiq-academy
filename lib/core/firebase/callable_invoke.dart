import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../error/exception.dart';
import '../error/user_facing_error.dart';
import 'app_firebase.dart';

/// Invokes a callable by name.
///
/// Emulator builds use raw HTTP to
/// `http://127.0.0.1:5001/<project>/<region>/<name>` with the Auth ID token.
/// The Android Functions SDK rejects our fake API key
/// (`Please set a valid API key`) when using [HttpsCallable]/ production
/// builds keep the normal SDK path.
Future<Map<String, dynamic>> invokeCallable(
  FirebaseFunctions functions,
  String name,
  Map<String, dynamic> payload,
) async {
  if (useFirebaseEmulator) {
    return _invokeEmulatorHttp(name, payload);
  }

  try {
    final result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call(payload);
    return _requireResultMap(result.data);
  } on FirebaseFunctionsException catch (e) {
    throw ServerException(_functionsExceptionMessage(e));
  } on ServerException {
    rethrow;
  } catch (e) {
    if (kDebugMode) debugPrint('callable $name failed: $e');
    throw const ServerException(
      'تعذر إكمال العملية. تحقق من الاتصال ثم أعد المحاولة.',
    );
  }
}

Future<Map<String, dynamic>> _invokeEmulatorHttp(
  String name,
  Map<String, dynamic> payload,
) async {
  final auth = FirebaseAuth.instanceFor(app: firebaseEmulatorApp);
  final user = auth.currentUser;
  if (user == null) {
    throw const ServerException(signedOutErrorText);
  }
  final token = await user.getIdToken();
  if (token == null || token.isEmpty) {
    throw const ServerException(signedOutErrorText);
  }

  final uri = Uri.parse(
    'http://$firebaseEmulatorHost:$functionsEmulatorPort/'
    '$firebaseEmulatorProjectId/$functionsRegion/$name',
  );
  if (kDebugMode) debugPrint('callable http → $uri');

  final client = HttpClient();
  try {
    final request = await client
        .postUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.add(utf8.encode(jsonEncode({'data': payload})));

    final response = await request.close().timeout(const Duration(seconds: 60));
    final body = await response.transform(utf8.decoder).join();
    final decoded = body.isEmpty ? null : jsonDecode(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is! Map) {
        throw const ServerException(
          'تعذر إكمال العملية: رد غير متوقع من الخادم',
        );
      }
      return _requireResultMap(decoded['result'] ?? decoded);
    }

    throw ServerException(_emulatorErrorMessage(decoded, response.statusCode));
  } on ServerException {
    rethrow;
  } on SocketException catch (e) {
    if (kDebugMode) debugPrint('callable socket: $e');
    throw const ServerException(
      'تعذر الاتصال بمحاكي الدوال. تأكد أن emulators شغالة وأن adb reverse '
      'لمنفذ 5001 متصل ثم أعد المحاولة.',
    );
  } on HttpException catch (e) {
    if (kDebugMode) debugPrint('callable http: $e');
    throw const ServerException(
      'تعذر الاتصال بمحاكي الدوال. أعد المحاولة بعد ثوانٍ.',
    );
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('callable format: $e');
    throw const ServerException('تعذر إكمال العملية: رد غير متوقع من الخادم');
  } catch (e) {
    if (kDebugMode) debugPrint('callable $name failed: $e');
    throw const ServerException(
      'تعذر إكمال العملية. تحقق من تشغيل المحاكي ثم أعد المحاولة.',
    );
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic> _requireResultMap(Object? raw) {
  if (raw is! Map) {
    throw const ServerException('تعذر إكمال العملية: رد غير متوقع من الخادم');
  }
  return <String, dynamic>{
    for (final e in raw.entries) e.key.toString(): e.value,
  };
}

String _emulatorErrorMessage(Object? decoded, int statusCode) {
  if (decoded is Map) {
    final error = decoded['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      final status = error['status'];
      if (status is String && status.isNotEmpty) {
        final code = status.toLowerCase().replaceAll('_', '-');
        return _functionsExceptionMessage(
          FirebaseFunctionsException(code: code, message: ''),
        );
      }
    }
  }
  return 'تعذر إكمال العملية (HTTP $statusCode)';
}

String _functionsExceptionMessage(FirebaseFunctionsException e) {
  final msg = e.message?.trim() ?? '';
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(msg)) return msg;
  return switch (e.code) {
    'unavailable' || 'deadline-exceeded' =>
      'تعذر الاتصال بمحاكي الدوال. تأكد أن emulators شغالة وأن adb reverse '
          'لمنفذ 5001 متصل ثم أعد المحاولة.',
    'unknown' =>
      msg.isNotEmpty
          ? 'تعذر إكمال العملية ($msg)'
          : 'تعذر إكمال العملية. أعد المحاولة بعد ثوانٍ.',
    'not-found' =>
      'هذه العملية غير مكتملة: الدالة السحابية غير منشورة أو غير موجودة.',
    'permission-denied' ||
    'unauthenticated' => 'ليست لديك صلاحية لهذا الإجراء.',
    'failed-precondition' =>
      msg.isNotEmpty ? msg : 'تعذر إكمال العملية في الوضع الحالي.',
    'already-exists' => msg.isNotEmpty ? msg : 'العنصر موجود مسبقاً.',
    'invalid-argument' =>
      msg.isNotEmpty ? msg : 'بيانات غير صالحة. راجع الحقول وأعد المحاولة.',
    _ =>
      msg.isNotEmpty
          ? 'تعذر إكمال العملية (${e.code}): $msg'
          : 'تعذر إكمال العملية (${e.code})',
  };
}
