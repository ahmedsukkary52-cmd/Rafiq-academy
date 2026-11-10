import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/parent_payment_proof.dart';
import 'package:rafiq_academy/shared/domain/academy_payment_settings_contract.dart';
import 'package:rafiq_academy/shared/domain/billing_report_status.dart';
import 'package:rafiq_academy/shared/domain/family_bill_contract.dart';

void main() {
  BillingReportStatus of(String? status, [String? review]) =>
      billingReportStatus(
        hasRecord: true,
        status: status,
        reviewStatus: review,
      );

  group('billingReportStatus', () {
    test('only a server-written paid status is paid', () {
      expect(of('paid'), BillingReportStatus.paid);
      expect(of('paid', 'approved'), BillingReportStatus.paid);
    });

    test('a submitted or pending proof is never paid', () {
      expect(
        of('due', 'pending_review'),
        BillingReportStatus.awaitingVerification,
      );
      expect(
        of('overdue', 'pending_review'),
        BillingReportStatus.awaitingVerification,
      );
      for (final review in [
        'pending_review',
        'approved',
        'rejected',
        'partial',
        '',
        'weird',
      ]) {
        for (final status in ['due', 'overdue', null, '', 'bogus']) {
          expect(
            of(status, review).isPaid,
            isFalse,
            reason: '$status / $review',
          );
        }
      }
    });

    test('issued bill without proof: awaiting proof or overdue', () {
      expect(of('due'), BillingReportStatus.awaitingProof);
      expect(of('due', ''), BillingReportStatus.awaitingProof);
      expect(of('overdue'), BillingReportStatus.overdue);
    });

    test('rejected and legacy partial reviews', () {
      expect(of('due', 'rejected'), BillingReportStatus.rejected);
      expect(of('overdue', 'rejected'), BillingReportStatus.rejected);
      expect(of('due', 'partial'), BillingReportStatus.partiallyPaid);
    });

    test('no bill: not yet due or fee needs configuration', () {
      expect(
        billingReportStatus(hasRecord: false),
        BillingReportStatus.notYetDue,
      );
      expect(
        billingReportStatus(hasRecord: false, feeConfigured: false),
        BillingReportStatus.feeNotConfigured,
      );
    });

    test('cancelled and inconsistent data are surfaced, not guessed', () {
      expect(of('cancelled', 'pending_review'), BillingReportStatus.cancelled);
      expect(of('due', 'approved'), BillingReportStatus.unknown);
      expect(of('due', 'weird'), BillingReportStatus.unknown);
      expect(of(null), BillingReportStatus.unknown);
      expect(of('refunded'), BillingReportStatus.unknown);
    });

    test('values are trimmed', () {
      expect(
        of(' due ', ' pending_review '),
        BillingReportStatus.awaitingVerification,
      );
    });

    test('every status has an Arabic label', () {
      for (final s in BillingReportStatus.values) {
        expect(s.arabicLabel, isNotEmpty);
      }
    });
  });

  group('billingReportDimensions', () {
    BillingReportDimensions dims(
      String? status, [
      String? review,
      String? reason,
    ]) => billingReportDimensions(
      hasRecord: true,
      status: status,
      reviewStatus: review,
      latestRejectionReason: reason,
    );

    test('overdue and rejected are both represented', () {
      final d = dims('overdue', 'rejected', 'صورة غير واضحة');
      expect(d.dueState, BillingDueState.overdue);
      expect(d.proofState, BillingProofState.rejected);
      expect(d.latestRejectionReason, 'صورة غير واضحة');
      expect(d.isPaid, isFalse);
    });

    test('latest rejection reason survives a resubmission', () {
      final d = dims('overdue', 'pending_review', ' سبب سابق ');
      expect(d.proofState, BillingProofState.awaitingVerification);
      expect(d.latestRejectionReason, 'سبب سابق');
      expect(dims('due', 'rejected', '  ').latestRejectionReason, isNull);
    });

    test('only a server-written paid status is paid', () {
      expect(dims('paid', 'approved').isPaid, isTrue);
      for (final review in [
        'pending_review',
        'approved',
        'rejected',
        'partial',
        '',
        'weird',
      ]) {
        for (final status in ['due', 'overdue', null, '', 'cancelled', 'x']) {
          expect(
            dims(status, review).isPaid,
            isFalse,
            reason: '$status / $review',
          );
        }
      }
    });

    test('approved without paid needs attention and is not paid', () {
      final d = dims('due', 'approved');
      expect(d.proofState, BillingProofState.approved);
      expect(d.isPaid, isFalse);
      expect(d.needsAttention, isTrue);
      expect(dims('paid', 'approved').needsAttention, isFalse);
      expect(dims('refunded').needsAttention, isTrue);
      expect(dims('due', 'weird').needsAttention, isTrue);
    });

    test('exemption is distinct from a missing fee', () {
      expect(
        billingReportDimensions(hasRecord: false, exempt: true).dueState,
        BillingDueState.exempt,
      );
      expect(
        billingReportDimensions(
          hasRecord: false,
          feeConfigured: false,
        ).dueState,
        BillingDueState.feeNotConfigured,
      );
      expect(
        billingReportDimensions(hasRecord: false).dueState,
        BillingDueState.notYetIssued,
      );
    });

    test('legacy partial and cancelled are kept per dimension', () {
      expect(dims('due', 'partial').proofState, BillingProofState.partial);
      final c = dims('cancelled', 'rejected', 'r');
      expect(c.dueState, BillingDueState.cancelled);
      expect(c.proofState, BillingProofState.rejected);
    });

    test('every dimension value has an Arabic label', () {
      for (final s in BillingDueState.values) {
        expect(s.arabicLabel, isNotEmpty);
      }
      for (final s in BillingProofState.values) {
        expect(s.arabicLabel, isNotEmpty);
      }
    });
  });

  group('FamilyBillContract', () {
    test('collection, doc id and field names are frozen', () {
      expect(FamilyBillContract.collection, 'familyBills');
      expect(
        FamilyBillContract.docId(parentId: ' p1 ', periodKey: '2026-11'),
        'p1_2026-11',
      );
      expect(FamilyBillContract.totalMinorField, 'totalMinor');
      expect(FamilyBillContract.lineAmountMinorField, 'amountMinor');
      expect(FamilyBillContract.methodInstapay, 'instapay');
    });

    test('lifecycle values match the existing payments contract', () {
      expect(
        FamilyBillContract.reviewPending,
        ParentPaymentProofContract.pendingReview,
      );
      expect(
        FamilyBillContract.reviewApproved,
        ParentPaymentProofContract.approved,
      );
      expect(
        FamilyBillContract.reviewRejected,
        ParentPaymentProofContract.rejected,
      );
      expect(
        FamilyBillContract.reviewPartial,
        ParentPaymentProofContract.partial,
      );
      expect(
        FamilyBillContract.methodVodafoneCash,
        ParentPaymentProofContract.externalMethod,
      );
      expect(
        FamilyBillContract.reviewStatusField,
        ParentPaymentProofContract.reviewStatusField,
      );
      expect(
        FamilyBillContract.proofCycleIdField,
        ParentPaymentProofContract.proofCycleIdField,
      );
    });

    test('policy constants match the backend calculation and defaults', () {
      expect(
        FamilyBillContract.gracePeriodDays,
        AcademyPaymentSettingsContract.defaultGracePeriodDays,
      );
      final ts = File(
        'functions/src/billing/familyBillCalculation.ts',
      ).readAsStringSync();
      expect(
        ts,
        contains(
          'FAMILY_DISCOUNT_MIN_DUE_CHILDREN = '
          '${FamilyBillContract.familyDiscountMinDueChildren};',
        ),
      );
      expect(ts, contains('BASIS_POINTS_PER_WHOLE = 10_000;'));
      expect(FamilyBillContract.basisPointsPerWhole, 10000);
    });
  });
}
