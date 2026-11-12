import 'package:equatable/equatable.dart';

/// Server-owned complaint lifecycle (`submitComplaint` / `respondToComplaint`).
enum ComplaintStatus {
  open('open', 'جديدة'),
  inProgress('in_progress', 'قيد المعالجة'),
  resolved('resolved', 'تم الحل'),
  archived('archived', 'مؤرشفة');

  const ComplaintStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ComplaintStatus fromWire(Object? raw) {
    for (final s in values) {
      if (s.wire == raw) return s;
    }
    return ComplaintStatus.open;
  }

  bool get isClosed =>
      this == ComplaintStatus.resolved || this == ComplaintStatus.archived;
}

String complaintSenderRoleLabel(String role) => switch (role) {
  'parent' => 'ولي أمر',
  'teacher' => 'معلم',
  'supervisor' => 'مشرف',
  'admin' => 'الإدارة',
  _ => 'مستخدم',
};

class Complaint extends Equatable {
  const Complaint({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.studentId,
    this.studentName = '',
    this.halaqaId,
    this.halaqaName = '',
    this.historyCount = 0,
    this.legacyResponse,
  });

  final String id;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String subject;
  final String message;
  final ComplaintStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? studentId;
  final String studentName;
  final String? halaqaId;
  final String halaqaName;
  final int historyCount;

  /// Single overwritten reply written before history entries existed.
  final String? legacyResponse;

  /// "ولي أمر أحمد · حلقة النور" style context line; empty when none.
  String get contextLine {
    final parts = <String>[
      if (studentName.isNotEmpty) 'الطالب: $studentName',
      if (halaqaName.isNotEmpty) 'الحلقة: $halaqaName',
    ];
    return parts.join(' · ');
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderRole,
    senderName,
    subject,
    message,
    status,
    createdAt,
    updatedAt,
    studentId,
    studentName,
    halaqaId,
    halaqaName,
    historyCount,
    legacyResponse,
  ];
}

class ComplaintHistoryEntry extends Equatable {
  const ComplaintHistoryEntry({
    required this.id,
    required this.authorId,
    required this.authorRole,
    required this.authorName,
    required this.message,
    required this.statusFrom,
    required this.statusTo,
    this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorRole;
  final String authorName;
  final String message;
  final ComplaintStatus statusFrom;
  final ComplaintStatus statusTo;
  final DateTime? createdAt;

  bool get changedStatus => statusFrom != statusTo;
  bool get isAdmin => authorRole == 'admin';

  @override
  List<Object?> get props => [
    id,
    authorId,
    authorRole,
    authorName,
    message,
    statusFrom,
    statusTo,
    createdAt,
  ];
}

/// One page of complaints plus the opaque cursor for the next page.
class ComplaintPage {
  const ComplaintPage({required this.items, required this.cursor});

  final List<Complaint> items;

  /// `null` when there are no more pages.
  final Object? cursor;
}

/// Optional context the complainant may attach (child or halaqa).
class ComplaintContextOption extends Equatable {
  const ComplaintContextOption.student(this.id, this.name) : isStudent = true;
  const ComplaintContextOption.halaqa(this.id, this.name) : isStudent = false;

  final String id;
  final String name;
  final bool isStudent;

  @override
  List<Object?> get props => [id, name, isStudent];
}

class ComplaintFormValidation {
  const ComplaintFormValidation._();

  static const subjectMax = 120;
  static const messageMax = 2000;

  static String? subject(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'اكتب عنوان الشكوى';
    if (v.length > subjectMax) return 'العنوان أطول من $subjectMax حرفاً';
    return null;
  }

  static String? message(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'اكتب تفاصيل الشكوى';
    if (v.length > messageMax) return 'النص أطول من $messageMax حرف';
    return null;
  }
}
