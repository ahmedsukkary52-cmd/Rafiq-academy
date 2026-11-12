import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/accounts/domain/onboarding_models.dart';
import 'package:rafiq_academy/features/accounts/presentation/admin_onboard_student_page.dart';

const _halaqa = OnboardingHalaqaOption(
  id: 'h1',
  name: 'حلقة الفجر',
  studentCount: 4,
  teacherName: 'أ. خالد',
  supervisorName: 'أ. سعيد',
);

const _parentCred = IssuedCredential(
  role: 'parent',
  uid: 'p1',
  name: 'أحمد محمود',
  username: 'pr123456',
  temporaryPassword: 'Ab3dEf7hJk',
);
const _studentCred = IssuedCredential(
  role: 'student',
  uid: 's9',
  name: 'عبد الله',
  username: 'st654321',
  temporaryPassword: 'Zx8cVb2nMq',
);

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _tapNext(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('onboard-next')));
  await tester.tap(find.byKey(const Key('onboard-next')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new parent + student + halaqa: review shows relationships, '
      'result shows one-time credentials', (tester) async {
    final requests = <OnboardStudentRequest>[];
    await tester.pumpWidget(
      _app(
        AdminOnboardStudentPage(
          loadHalaqat: () async => [_halaqa],
          searchParents: (_) async => const [],
          submit: (r) async {
            requests.add(r);
            return const OnboardingResult(
              completed: true,
              replayed: false,
              studentId: 's9',
              parentId: 'p1',
              steps: [
                OnboardingStepResult(
                  step: 'parent',
                  status: OnboardingStepStatus.done,
                  message: 'تم إنشاء حساب ولي الأمر',
                ),
                OnboardingStepResult(
                  step: 'halaqa',
                  status: OnboardingStepStatus.done,
                  message: 'تمت إضافة الطالب إلى الحلقة',
                ),
              ],
              credentials: [_parentCred, _studentCred],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: cannot continue without a parent.
    await _tapNext(tester);
    expect(
      find.text('اختر ولي الأمر من نتائج البحث أو أنشئ حساباً جديداً'),
      findsOneWidget,
    );
    await tester.tap(find.text('ولي أمر جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('onboard-parent-name')),
      'أحمد محمود',
    );
    await _tapNext(tester);

    // Step 2: student.
    await tester.enterText(
      find.byKey(const Key('onboard-student-name')),
      'عبد الله',
    );
    await _tapNext(tester);

    // Step 3: halaqa shows teacher + supervisor by name, never ids.
    expect(find.textContaining('أ. خالد'), findsOneWidget);
    expect(find.textContaining('t1'), findsNothing);
    await tester.tap(find.byKey(const Key('onboard-halaqa-h1')));
    await tester.pumpAndSettle();
    await _tapNext(tester);

    // Step 4: review.
    expect(find.text('أحمد محمود (حساب جديد)'), findsOneWidget);
    expect(find.text('أ. سعيد'), findsOneWidget);
    await _tapNext(tester);

    expect(requests, hasLength(1));
    final payload = requests.single.toPayload();
    expect(payload['studentName'], 'عبد الله');
    expect(payload['parent'], {'mode': 'new', 'name': 'أحمد محمود'});
    expect(payload['halaqaId'], 'h1');
    expect(requests.single.requestId, startsWith('onb_'));

    expect(find.text('تم تسجيل الطالب بنجاح'), findsOneWidget);
    expect(find.byKey(const Key('credential-parent')), findsOneWidget);
    expect(find.byKey(const Key('credential-student')), findsOneWidget);
    expect(find.text('اسم المستخدم: st654321'), findsOneWidget);
    expect(find.text('كلمة المرور المؤقتة: Zx8cVb2nMq'), findsOneWidget);
  });

  testWidgets('existing parent via search; partial result retries with the '
      'same request id', (tester) async {
    final requests = <OnboardStudentRequest>[];
    var calls = 0;
    await tester.pumpWidget(
      _app(
        AdminOnboardStudentPage(
          loadHalaqat: () async => const [],
          searchParents: (q) async => [
            const MemberSearchHit(uid: 'p7', name: 'فاطمة علي'),
          ],
          submit: (r) async {
            requests.add(r);
            calls++;
            if (calls == 1) {
              return const OnboardingResult(
                completed: false,
                replayed: false,
                studentId: null,
                parentId: 'p7',
                steps: [
                  OnboardingStepResult(
                    step: 'student',
                    status: OnboardingStepStatus.failed,
                    message: 'تعذر إنشاء الحساب',
                  ),
                ],
                credentials: [],
              );
            }
            return const OnboardingResult(
              completed: true,
              replayed: false,
              studentId: 's9',
              parentId: 'p7',
              steps: [],
              credentials: [_studentCred],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('onboard-parent-search')),
      'فاطمه',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard-parent-p7')));
    await tester.pumpAndSettle();
    expect(find.text('ولي الأمر المختار'), findsOneWidget);
    await _tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboard-student-name')), 'مريم');
    await _tapNext(tester);
    await _tapNext(tester); // no halaqa
    await _tapNext(tester); // submit

    expect(find.textContaining('اكتمل جزء من التسجيل'), findsOneWidget);
    expect(find.text('تعذر إنشاء الحساب'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboard-retry')));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests[1].requestId, requests[0].requestId);
    expect(requests[0].toPayload()['parent'], {
      'mode': 'existing',
      'parentId': 'p7',
    });
    expect(requests[0].toPayload().containsKey('halaqaId'), isFalse);
    expect(find.text('تم تسجيل الطالب بنجاح'), findsOneWidget);
  });

  testWidgets('server rejection stays on review with the message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AdminOnboardStudentPage(
          loadHalaqat: () async => const [],
          searchParents: (_) async => const [],
          submit: (_) async => throw const ServerException('الحلقة غير نشطة'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ولي أمر جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboard-parent-name')), 'خالد');
    await _tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboard-student-name')), 'سارة');
    await _tapNext(tester);
    await _tapNext(tester);
    await _tapNext(tester);
    expect(find.byKey(const Key('onboard-error')), findsOneWidget);
    expect(find.text('الحلقة غير نشطة'), findsOneWidget);
  });

  testWidgets('opened from a parent profile, the parent is preselected and '
      'the new child is linked to that existing account', (tester) async {
    final requests = <OnboardStudentRequest>[];
    var searched = 0;
    await tester.pumpWidget(
      _app(
        AdminOnboardStudentPage(
          initialParent: const MemberSearchHit(uid: 'p1', name: 'محمد أحمد'),
          loadHalaqat: () async => [_halaqa],
          searchParents: (_) async {
            searched++;
            return const [];
          },
          submit: (r) async {
            requests.add(r);
            return const OnboardingResult(
              completed: true,
              replayed: false,
              studentId: 's3',
              parentId: 'p1',
              steps: [],
              credentials: [_studentCred],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ولي الأمر المختار'), findsOneWidget);
    expect(find.text('محمد أحمد'), findsOneWidget);
    await _tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboard-student-name')), 'عمر أحمد');
    await _tapNext(tester);
    await tester.tap(find.byKey(const Key('onboard-halaqa-h1')));
    await tester.pumpAndSettle();
    await _tapNext(tester);
    expect(find.text('محمد أحمد (حساب موجود)'), findsOneWidget);
    await _tapNext(tester);

    expect(searched, 0);
    final payload = requests.single.toPayload();
    expect(payload['parent'], {'mode': 'existing', 'parentId': 'p1'});
    expect(payload['studentName'], 'عمر أحمد');
    expect(payload['halaqaId'], 'h1');
    expect(find.text('تم تسجيل الطالب بنجاح'), findsOneWidget);
  });

  test('request ids are unique and well-formed', () {
    final ids = {for (var i = 0; i < 50; i++) newOnboardingRequestId()};
    expect(ids, hasLength(50));
    for (final id in ids) {
      expect(RegExp(r'^onb_[0-9a-f]{24}$').hasMatch(id), isTrue);
    }
  });
}
