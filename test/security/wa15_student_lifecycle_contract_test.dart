import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/student/data/models/student_profile_model.dart';
import 'package:rafiq_academy/shared/domain/student_lifecycle_contract.dart';
import 'package:rafiq_academy/shared/domain/student_search_contract.dart';
import 'package:rafiq_academy/shared/domain/student_status_composition.dart';

/// WA-15 / C14 — lifecycle contract, status composition truth table, and the
/// WA-14 non-regression guard.
void main() {
  group('WA-15 lifecycle contract', () {
    test('exposes exactly the two frozen values', () {
      expect(StudentLifecycleContract.allowedValues, {'active', 'archived'});
      expect(StudentLifecycle.values, [
        StudentLifecycle.active,
        StudentLifecycle.archived,
      ]);
      expect(StudentLifecycle.active.wireValue, 'active');
      expect(StudentLifecycle.archived.wireValue, 'archived');
    });

    test('missing or malformed lifecycle reads as active', () {
      for (final raw in <Object?>[
        null,
        '',
        '   ',
        42,
        <String>[],
        'ACTIVE',
        'deleted',
        'suspended',
      ]) {
        expect(
          StudentLifecycleContract.parse(raw),
          StudentLifecycle.active,
          reason: 'input $raw must degrade to active',
        );
      }
      expect(
        StudentLifecycleContract.parse('archived'),
        StudentLifecycle.archived,
      );
      expect(
        StudentLifecycleContract.parse('  archived  '),
        StudentLifecycle.archived,
      );
    });

    test('matches the backend wire values byte for byte', () {
      // functions/src/lifecycle/studentLifecycleContract.ts
      expect(StudentLifecycleContract.field, 'lifecycle');
      expect(StudentLifecycleContract.active, 'active');
      expect(StudentLifecycleContract.archived, 'archived');
    });
  });

  group('WA-15 StudentProfile mapping', () {
    StudentProfileModel model(Map<String, dynamic> profile) =>
        StudentProfileModel.fromMaps(
          uid: 'student1',
          user: const {'name': 'أحمد'},
          profile: profile,
        );

    test(
      'a profile without lifecycle maps to active (no migration needed)',
      () {
        expect(model(const {}).lifecycle, StudentLifecycle.active);
      },
    );

    test('a stored archived profile maps to archived', () {
      expect(
        model(const {'lifecycle': 'archived'}).lifecycle,
        StudentLifecycle.archived,
      );
    });

    test('an unknown stored value degrades to active rather than throwing', () {
      expect(
        model(const {'lifecycle': 'deactivated'}).lifecycle,
        StudentLifecycle.active,
      );
    });
  });

  group('WA-15 composition truth table', () {
    StudentStatusFacts facts({
      StudentLifecycle lifecycle = StudentLifecycle.active,
      bool isActive = true,
      String? payment = 'ok',
      List<String> halaqaIds = const ['h1'],
      String? pointer = 'h1',
    }) => StudentStatusFacts(
      lifecycle: lifecycle,
      isActive: isActive,
      paymentStatus: payment,
      halaqaIds: halaqaIds,
      primaryHalaqaPointer: pointer,
    );

    void expectLabel(StudentStatusFacts f, StudentStatusLabel expected) {
      expect(StudentStatusComposition.compose(f), expected);
    }

    test('A: everything nominal => نشط', () {
      expectLabel(facts(), StudentStatusLabel.active);
      expect(StudentStatusLabel.active.labelAr, 'نشط');
    });

    test('B: no membership => بانتظار حلقة', () {
      expectLabel(
        facts(halaqaIds: const [], pointer: null),
        StudentStatusLabel.awaitingHalaqa,
      );
      expect(StudentStatusLabel.awaitingHalaqa.labelAr, 'بانتظار حلقة');
    });

    test('C: payment suspended => موقوف دفع', () {
      expectLabel(
        facts(payment: 'suspended'),
        StudentStatusLabel.paymentSuspended,
      );
      expect(StudentStatusLabel.paymentSuspended.labelAr, 'موقوف دفع');
    });

    test('D: archived outranks an otherwise healthy student => مؤرشف', () {
      expectLabel(
        facts(lifecycle: StudentLifecycle.archived),
        StudentStatusLabel.archived,
      );
      expect(StudentStatusLabel.archived.labelAr, 'مؤرشف');
    });

    test('E: login disabled => معطّل, and it is not archived', () {
      expectLabel(facts(isActive: false), StudentStatusLabel.loginDisabled);
      expect(StudentStatusLabel.loginDisabled.labelAr, 'معطّل');
      expect(
        StudentStatusLabel.loginDisabled,
        isNot(StudentStatusLabel.archived),
      );
    });

    test('F: login disabled outranks payment suspension => معطّل', () {
      expectLabel(
        facts(isActive: false, payment: 'suspended'),
        StudentStatusLabel.loginDisabled,
      );
    });

    test(
      'G: archived outranks both disabled login and suspension => مؤرشف',
      () {
        expectLabel(
          facts(
            lifecycle: StudentLifecycle.archived,
            isActive: false,
            payment: 'suspended',
          ),
          StudentStatusLabel.archived,
        );
      },
    );

    test('H: a stale primary pointer never overrides real membership', () {
      // Pointer names a halaqa the student is no longer rostered into, but
      // halaqat.studentIds still lists h9 → the student IS assigned.
      expectLabel(
        facts(halaqaIds: const ['h9'], pointer: 'staleHalaqa'),
        StudentStatusLabel.active,
      );
    });

    test('a stale pointer cannot fabricate a membership either', () {
      expectLabel(
        facts(halaqaIds: const [], pointer: 'staleHalaqa'),
        StudentStatusLabel.awaitingHalaqa,
      );
    });

    test('every non-suspended payment state is treated as unblocked', () {
      for (final status in ['ok', 'reminded', 'due_warning', 'in_grace']) {
        expectLabel(facts(payment: status), StudentStatusLabel.active);
      }
    });

    test('the five labels are distinct', () {
      final labels = StudentStatusLabel.values
          .map((value) => value.labelAr)
          .toSet();
      expect(labels.length, StudentStatusLabel.values.length);
    });
  });

  group('WA-15 role-scoped composition', () {
    const suspendedFacts = StudentStatusFacts(
      lifecycle: StudentLifecycle.active,
      isActive: true,
      paymentStatus: 'suspended',
      halaqaIds: ['h1'],
    );

    test('Admin and Parent may compose payment', () {
      for (final role in [AppRoles.admin, AppRoles.parent]) {
        expect(
          StudentStatusComposition.composeForRole(
            viewerRole: role,
            facts: suspendedFacts,
          ),
          StudentStatusLabel.paymentSuspended,
          reason: '$role composes the payment dimension',
        );
      }
    });

    test('Teacher and Supervisor never surface the payment dimension', () {
      // Rules deny paymentAccess reads to both roles (PH-01).
      for (final role in [AppRoles.teacher, AppRoles.supervisor]) {
        expect(
          StudentStatusVisibility.forRole(role).canSeePayment,
          isFalse,
          reason: role,
        );
        expect(
          StudentStatusComposition.composeForRole(
            viewerRole: role,
            facts: suspendedFacts,
          ),
          StudentStatusLabel.active,
          reason: role,
        );
      }
    });

    test('Teacher still sees archived and awaiting-halaqa states', () {
      expect(
        StudentStatusComposition.composeForRole(
          viewerRole: AppRoles.teacher,
          facts: const StudentStatusFacts(
            lifecycle: StudentLifecycle.archived,
            isActive: true,
          ),
        ),
        StudentStatusLabel.archived,
      );
      expect(
        StudentStatusComposition.composeForRole(
          viewerRole: AppRoles.teacher,
          facts: const StudentStatusFacts(
            lifecycle: StudentLifecycle.active,
            isActive: true,
            halaqaIds: [],
          ),
        ),
        StudentStatusLabel.awaitingHalaqa,
      );
    });

    test('Student receives no composed label at all', () {
      expect(
        StudentStatusComposition.composeForRole(
          viewerRole: AppRoles.student,
          facts: suspendedFacts,
        ),
        isNull,
      );
      expect(
        StudentStatusComposition.composeForRole(
          viewerRole: null,
          facts: suspendedFacts,
        ),
        isNull,
      );
    });

    test('an unreadable payment fact is skipped, never assumed suspended', () {
      expect(
        StudentStatusComposition.compose(
          const StudentStatusFacts(
            lifecycle: StudentLifecycle.active,
            isActive: true,
            paymentStatus: null,
            halaqaIds: ['h1'],
          ),
        ),
        StudentStatusLabel.active,
      );
    });
  });

  group('WA-15 primary halaqa resolution (reuses the WA-14 rule)', () {
    test('the pointer wins when it is a real membership', () {
      expect(
        StudentStatusComposition.resolvePrimaryHalaqaId(
          pointer: 'h2',
          halaqaIds: const ['h2', 'h1'],
        ),
        'h2',
      );
    });

    test('a stale pointer falls back to the lowest-sorted membership', () {
      expect(
        StudentStatusComposition.resolvePrimaryHalaqaId(
          pointer: 'stale',
          halaqaIds: const ['h2', 'h1'],
        ),
        'h1',
      );
    });

    test('no membership resolves to null regardless of the pointer', () {
      expect(
        StudentStatusComposition.resolvePrimaryHalaqaId(
          pointer: 'stale',
          halaqaIds: const [],
        ),
        isNull,
      );
    });
  });

  group('WA-15 does not weaken WA-14', () {
    test('lifecycle stays forbidden from the studentSearch projection', () {
      expect(
        StudentSearchContract.forbiddenFields,
        contains(StudentLifecycleContract.field),
      );
      expect(
        StudentSearchContract.fields,
        isNot(contains(StudentLifecycleContract.field)),
      );
    });

    test('no composed status label leaks into the projection field set', () {
      for (final field in StudentSearchContract.fields) {
        expect(field.toLowerCase().contains('status'), isFalse);
        expect(field.toLowerCase().contains('lifecycle'), isFalse);
      }
    });
  });
}
