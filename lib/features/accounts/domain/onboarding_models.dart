import 'package:equatable/equatable.dart';

import '../../../core/constants/academy_branding.dart';

/// A Halaqa the onboarding wizard can admit the new student into.
class OnboardingHalaqaOption extends Equatable {
  final String id;
  final String name;
  final String teacherName;
  final String supervisorName;
  final int studentCount;

  const OnboardingHalaqaOption({
    required this.id,
    required this.name,
    this.teacherName = '',
    this.supervisorName = '',
    this.studentCount = 0,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    teacherName,
    supervisorName,
    studentCount,
  ];
}

/// One-time credentials returned by the server; never persisted on device.
class IssuedCredential extends Equatable {
  final String role;
  final String uid;
  final String name;
  final String username;
  final String temporaryPassword;

  /// Stable academy code (S-003, P-002, …); empty for accounts without one.
  final String academyRef;

  const IssuedCredential({
    required this.role,
    required this.uid,
    required this.name,
    required this.username,
    required this.temporaryPassword,
    this.academyRef = '',
  });

  factory IssuedCredential.fromMap(Map<String, dynamic> m) => IssuedCredential(
    role: '${m['role'] ?? ''}',
    uid: '${m['uid'] ?? ''}',
    name: '${m['name'] ?? ''}',
    username: '${m['username'] ?? ''}',
    temporaryPassword: '${m['temporaryPassword'] ?? ''}',
    academyRef: '${m['academyRef'] ?? ''}',
  );

  String get roleLabel => switch (role) {
    'student' => 'الطالب',
    'parent' => 'ولي الأمر',
    'teacher' => 'المعلم',
    'supervisor' => 'المشرف',
    'assistant_teacher' => 'مساعد المدرس',
    _ => 'الحساب',
  };

  /// Text the Admin copies or shares with the family.
  String get shareText =>
      '${AcademyBranding.displayName} — بيانات دخول $roleLabel ($name)\n'
      'اسم المستخدم: $username\n'
      'كلمة المرور المؤقتة: $temporaryPassword\n'
      'سيُطلب منك تغيير كلمة المرور عند أول تسجيل دخول.';

  @override
  List<Object?> get props => [role, uid, name, username, temporaryPassword, academyRef];
}

enum OnboardingStepStatus { done, skipped, failed }

class OnboardingStepResult extends Equatable {
  final String step;
  final OnboardingStepStatus status;
  final String message;

  const OnboardingStepResult({
    required this.step,
    required this.status,
    required this.message,
  });

  factory OnboardingStepResult.fromMap(Map<String, dynamic> m) =>
      OnboardingStepResult(
        step: '${m['step'] ?? ''}',
        status: switch (m['status']) {
          'done' => OnboardingStepStatus.done,
          'skipped' => OnboardingStepStatus.skipped,
          _ => OnboardingStepStatus.failed,
        },
        message: '${m['message'] ?? ''}',
      );

  String get label => switch (step) {
    'parent' => 'حساب ولي الأمر',
    'student' => 'حساب الطالب',
    'link' => 'ربط الطالب بولي الأمر',
    'halaqa' => 'الإضافة إلى الحلقة',
    _ => step,
  };

  @override
  List<Object?> get props => [step, status, message];
}

class OnboardingResult extends Equatable {
  final bool completed;
  final bool replayed;
  final String? studentId;
  final String? parentId;
  final List<OnboardingStepResult> steps;
  final List<IssuedCredential> credentials;

  const OnboardingResult({
    required this.completed,
    required this.replayed,
    required this.studentId,
    required this.parentId,
    required this.steps,
    required this.credentials,
  });

  factory OnboardingResult.fromMap(Map<String, dynamic> m) => OnboardingResult(
    completed: m['status'] == 'completed',
    replayed: m['replayed'] == true,
    studentId: m['studentId'] as String?,
    parentId: m['parentId'] as String?,
    steps: [
      for (final s in (m['steps'] as List? ?? const []))
        if (s is Map) OnboardingStepResult.fromMap(Map<String, dynamic>.from(s)),
    ],
    credentials: [
      for (final c in (m['credentials'] as List? ?? const []))
        if (c is Map) IssuedCredential.fromMap(Map<String, dynamic>.from(c)),
    ],
  );

  @override
  List<Object?> get props => [
    completed,
    replayed,
    studentId,
    parentId,
    steps,
    credentials,
  ];
}

class OnboardStudentRequest extends Equatable {
  /// Stable across retries of the same wizard submission (idempotency key).
  final String requestId;
  final String studentName;
  final String? existingParentId;
  final String? newParentName;
  final String? halaqaId;

  const OnboardStudentRequest({
    required this.requestId,
    required this.studentName,
    this.existingParentId,
    this.newParentName,
    this.halaqaId,
  });

  Map<String, dynamic> toPayload() => {
    'requestId': requestId,
    'studentName': studentName.trim(),
    'parent': existingParentId != null
        ? {'mode': 'existing', 'parentId': existingParentId}
        : {'mode': 'new', 'name': (newParentName ?? '').trim()},
    if (halaqaId != null && halaqaId!.isNotEmpty) 'halaqaId': halaqaId,
  };

  @override
  List<Object?> get props => [
    requestId,
    studentName,
    existingParentId,
    newParentName,
    halaqaId,
  ];
}

class MemberSearchHit extends Equatable {
  final String uid;
  final String name;

  const MemberSearchHit({required this.uid, required this.name});

  @override
  List<Object?> get props => [uid, name];
}
