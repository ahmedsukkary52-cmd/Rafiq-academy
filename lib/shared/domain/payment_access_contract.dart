/// C2 / WA-3 — server-owned payment access (≠ [users.isActive]).
class PaymentAccessContract {
  const PaymentAccessContract._();

  static const String collection = 'paymentAccess';

  static const String parentIdField = 'parentId';
  static const String statusField = 'status';
  static const String reasonField = 'reason';
  static const String primaryInvoiceIdField = 'primaryInvoiceId';
  static const String affectedStudentIdsField = 'affectedStudentIds';
  static const String graceEndsAtField = 'graceEndsAt';
  static const String suspendedAtField = 'suspendedAt';
  static const String warningIssuedAtField = 'warningIssuedAt';
  static const String lastReminderAtField = 'lastReminderAt';
  static const String reinstatedAtField = 'reinstatedAt';
  static const String reinstatedByField = 'reinstatedBy';
  static const String updatedAtField = 'updatedAt';

  static const String statusOk = 'ok';
  static const String statusReminded = 'reminded';
  static const String statusDueWarning = 'due_warning';
  static const String statusInGrace = 'in_grace';
  static const String statusSuspended = 'suspended';

  static const Set<String> allowedStatuses = {
    statusOk,
    statusReminded,
    statusDueWarning,
    statusInGrace,
    statusSuspended,
  };

  static bool isValidStatus(String? raw) {
    final value = raw?.trim() ?? '';
    return allowedStatuses.contains(value);
  }

  static bool isSuspended(String? raw) =>
      (raw?.trim() ?? '') == statusSuspended;
}
