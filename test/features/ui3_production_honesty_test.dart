import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/parent/presentation/widgets/parent_payment_access_banner.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_event.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_excuses_page.dart';
import 'package:rafiq_academy/shared/domain/payment_access_contract.dart';
import 'package:rafiq_academy/shared/domain/payment_access_entity.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/app_empty_state.dart';
import 'package:rafiq_academy/shared/widgets/app_status_chip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

PaymentAccessEntity _access(String status) {
  return PaymentAccessEntity(parentId: 'p1', status: status);
}

class _Ui3FakeAuthBloc extends Fake implements AuthBloc {
  _Ui3FakeAuthBloc(this._state);

  final AuthState _state;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

class _Ui3FakeTeacherBloc extends Fake implements TeacherBloc {
  _Ui3FakeTeacherBloc(this._state);

  final TeacherState _state;
  final _controller = StreamController<TeacherState>.broadcast();

  @override
  TeacherState get state => _state;

  @override
  Stream<TeacherState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(TeacherEvent event) {}

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  group('UI-3 ParentPaymentAccessLabels', () {
    test('ok / null are not surfaced', () {
      expect(ParentPaymentAccessLabels.shouldSurface(null), isFalse);
      expect(
        ParentPaymentAccessLabels.shouldSurface(
          _access(PaymentAccessContract.statusOk),
        ),
        isFalse,
      );
    });

    test('non-ok Wave A statuses are surfaced with correct tones', () {
      expect(
        ParentPaymentAccessLabels.shouldSurface(
          _access(PaymentAccessContract.statusReminded),
        ),
        isTrue,
      );
      expect(
        ParentPaymentAccessLabels.tone(PaymentAccessContract.statusReminded),
        AppStatusTone.info,
      );
      expect(
        ParentPaymentAccessLabels.tone(PaymentAccessContract.statusDueWarning),
        AppStatusTone.warning,
      );
      expect(
        ParentPaymentAccessLabels.tone(PaymentAccessContract.statusInGrace),
        AppStatusTone.warning,
      );
      expect(
        ParentPaymentAccessLabels.tone(PaymentAccessContract.statusSuspended),
        AppStatusTone.error,
      );
    });

    test('suspended copy does not claim automatic reinstatement', () {
      final message = ParentPaymentAccessLabels.message(
        _access(PaymentAccessContract.statusSuspended),
      );
      expect(message, contains('تعليق'));
      expect(message, contains('الإدارة'));
      expect(message, contains('لا يُستعاد الوصول تلقائياً'));
    });

    test('in_grace copy keeps access available', () {
      final message = ParentPaymentAccessLabels.message(
        _access(PaymentAccessContract.statusInGrace),
      );
      expect(message, contains('متاحاً'));
      expect(message, isNot(contains('معلّق')));
    });
  });

  group('UI-3 ParentPaymentAccessBanner', () {
    testWidgets('shows pay + contact for suspended', (tester) async {
      var pay = false;
      var admin = false;
      await tester.pumpWidget(
        _wrap(
          ParentPaymentAccessBanner(
            access: _access(PaymentAccessContract.statusSuspended),
            onPayNow: () => pay = true,
            onContactAdmin: () => admin = true,
          ),
        ),
      );

      expect(find.text('الوصول معلّق'), findsOneWidget);
      expect(find.text('ادفع الآن'), findsOneWidget);
      expect(find.text('تواصل مع الإدارة'), findsOneWidget);

      await tester.tap(find.text('ادفع الآن'));
      await tester.pump();
      expect(pay, isTrue);

      await tester.tap(find.text('تواصل مع الإدارة'));
      await tester.pump();
      expect(admin, isTrue);
    });

    testWidgets('reminded shows pay without contact admin', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ParentPaymentAccessBanner(
            access: _access(PaymentAccessContract.statusReminded),
            onPayNow: () {},
            onContactAdmin: () {},
          ),
        ),
      );

      expect(find.text('تذكير بالسداد'), findsOneWidget);
      expect(find.text('ادفع الآن'), findsOneWidget);
      expect(find.text('تواصل مع الإدارة'), findsNothing);
    });
  });

  group('UI-3 TeacherExcusesPage honesty', () {
    testWidgets(
      'has no submit affordance and explains self-excuse is unavailable',
      (tester) async {
        final auth = _Ui3FakeAuthBloc(
          AuthAuthenticated(
            UserEntity(
              uid: 't1',
              name: 'محمد',
              role: 'teacher',
              isActive: true,
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        );
        final teacher = _Ui3FakeTeacherBloc(
          TeacherState(
            halaqatStatus: SectionStatus.loaded,
            halaqat: [
              HalaqaEntity(
                id: 'h1',
                name: 'حلقة',
                teacherId: 't1',
                supervisorId: 'sup1',
                studentIds: const [],
                schedule: const [],
                status: 'active',
              ),
            ],
            pendingAbsenceRequestsStatus: SectionStatus.loaded,
            pendingAbsenceRequests: const [],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: AppLocaleConfig.locale,
            supportedLocales: AppLocaleConfig.supportedLocales,
            localizationsDelegates: AppLocaleConfig.localizationsDelegates,
            theme: AppTheme.theme,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: auth),
                BlocProvider<TeacherBloc>.value(value: teacher),
              ],
              child: const TeacherExcusesPage(),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('اعتذار ذاتي'), findsOneWidget);
        expect(find.textContaining('أولياء الأمور'), findsOneWidget);
        expect(find.text('+ طلب جديد'), findsNothing);
        expect(find.text('إرسال'), findsNothing);
        expect(find.byType(AppEmptyState), findsOneWidget);
      },
    );
  });
}
