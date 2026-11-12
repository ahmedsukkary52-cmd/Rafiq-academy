import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/error/exception.dart';
import '../../../shared/domain/arabic_search_normalizer.dart';
import '../domain/onboarding_models.dart';

/// Account provisioning and recovery — all writes go through trusted
/// callables (`functions/src/accounts/onboardingFunctions.ts`).
class AcademyAccountsRepository {
  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;

  static const searchLimit = 20;

  const AcademyAccountsRepository({
    required this.functions,
    required this.firestore,
  });

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await functions.httpsCallable(name).call(payload);
      final data = result.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? 'تعذر إكمال العملية');
    } catch (_) {
      throw const ServerException('تعذر الاتصال بالخادم، أعد المحاولة');
    }
  }

  Future<OnboardingResult> onboardStudent(OnboardStudentRequest request) async =>
      OnboardingResult.fromMap(
        await _call('adminOnboardStudent', request.toPayload()),
      );

  Future<IssuedCredential> resetMemberPassword({
    required String userId,
    required String name,
    required String role,
  }) async {
    final data = await _call('adminResetMemberPassword', {'userId': userId});
    return IssuedCredential(
      role: role,
      uid: userId,
      name: name,
      username: '${data['username'] ?? ''}',
      temporaryPassword: '${data['temporaryPassword'] ?? ''}',
    );
  }

  Future<void> completeFirstLogin(String newPassword) async {
    await _call('completeFirstLogin', {'newPassword': newPassword});
  }

  /// Bounded Arabic-normalized prefix search on `users.nameNormalized`.
  Future<List<MemberSearchHit>> searchMembers({
    required String role,
    required String query,
  }) async {
    final q = ArabicSearchNormalizer.normalize(query);
    if (q.length < 2) return const [];
    final snap = await firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .orderBy('nameNormalized')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(searchLimit)
        .get();
    return [
      for (final d in snap.docs)
        if (d.data()['isActive'] != false)
          MemberSearchHit(uid: d.id, name: '${d.data()['name'] ?? ''}'),
    ];
  }
}
