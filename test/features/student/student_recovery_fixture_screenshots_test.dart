import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/mushaf/domain/mushaf_reciter.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_audio_bar.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_tokens.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/student_header_widget.dart';
import 'package:rafiq_academy/shared/widgets/student_progress_widget.dart';
import 'package:rafiq_academy/shared/widgets/student_quick_action_widget.dart';

/// TEST FIXTURE ONLY — fake data, no Firebase.
/// PNG capture via toImage hung under this environment; layout assertions kept.
void main() {
  testWidgets('fixture layout: header / progress / quick / options (no PNG)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.locale,
        theme: AppTheme.theme,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'TEST FIXTURE ONLY — not live data',
                  key: Key('fixture-banner'),
                  textAlign: TextAlign.center,
                ),
              ),
              StudentHeaderWidget(
                name: 'طالب',
                avatarEmoji: '🦊',
                coins: 15,
                totalStars: 4,
                streakDays: 3,
                showStreak: false,
                onAvatarTap: () {},
                onNotificationsTap: () {},
                onSearchTap: () {},
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StudentProgressWidget(
                  progressPercent: 40,
                  totalVerses: 0,
                  completedSurahs: 0,
                  totalStars: 4,
                  progressAvailable: false,
                  onTap: () {},
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StudentQuickActionsWidget(
                  onMushafTap: () {},
                  onReviewTap: null,
                  onTeacherTap: () {},
                  onMapTap: null,
                ),
              ),
              MushafAudioOptionsSheet(
                tokens: MushafReaderTokens.paper,
                selectedReciterId: MushafReciters.all.first.id,
                isLooping: false,
                playbackSpeed: 1.25,
                isMuted: false,
                onSelectReciter: (_) {},
                onLoopChanged: (_) {},
                onCycleSpeed: () {},
                onToggleMute: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('fixture-banner')), findsOneWidget);
    expect(find.byKey(const Key('student-header-hijri')), findsOneWidget);
    expect(find.byKey(const Key('student-progress-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey('mushaf-audio-speed')), findsOneWidget);
    expect(find.byKey(const ValueKey('mushaf-audio-mute')), findsOneWidget);
    expect(find.text('x1.25'), findsOneWidget);
  });
}
