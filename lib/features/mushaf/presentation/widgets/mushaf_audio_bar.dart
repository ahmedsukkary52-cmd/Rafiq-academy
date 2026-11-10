import 'package:flutter/material.dart';

import '../../domain/mushaf_reciter.dart';
import '../bloc/mushaf_audio_state.dart';
import 'mushaf_reader_tokens.dart';

String _digits(int n) => MushafReaderTokens.arabicDigits(n);

/// Status line under the ayah title — always truthful to [state].
String mushafAudioStatusLabel(MushafAudioState state) {
  final loop = state.isLooping ? ' · تكرار الآية' : '';
  return switch (state.status) {
    MushafAudioStatus.loading => 'جارٍ تحميل التلاوة…',
    MushafAudioStatus.error => state.errorMessage ?? 'تعذر تشغيل التلاوة',
    MushafAudioStatus.paused => 'متوقفة مؤقتاً · ${state.reciter.name}',
    MushafAudioStatus.playing ||
    MushafAudioStatus.idle => '${state.reciter.name}$loop',
  };
}

/// Compact reader audio strip: ayah + status, then options / previous /
/// play / next / close. Visually subordinate to the Quran canvas.
class MushafAudioBar extends StatelessWidget {
  const MushafAudioBar({
    super.key,
    required this.tokens,
    required this.state,
    required this.surahName,
    required this.ayahNumber,
    required this.positionStream,
    required this.durationStream,
    required this.onPrimary,
    required this.onOptions,
    required this.onClose,
    this.onPrevious,
    this.onNext,
  });

  final MushafReaderTokens tokens;
  final MushafAudioState state;
  final String surahName;
  final int ayahNumber;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;

  /// Play / pause / cancel loading / retry, depending on [state].
  final VoidCallback onPrimary;
  final VoidCallback onOptions;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Below this width the ayah / status line gets its own row so error
  /// messages and long surah names are never truncated.
  static const double stackedBreakpoint = 420;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.chrome,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MushafAudioProgressLine(
                tokens: tokens,
                status: state.status,
                positionStream: positionStream,
                durationStream: durationStream,
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < stackedBreakpoint) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _info(),
                          ),
                          SizedBox(
                            height: 54,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: _controls(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox(
                    height: 60,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 16,
                        end: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _info()),
                          ..._controls(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _controls() => [
    _BarIconButton(
      tokens: tokens,
      icon: Icons.tune_rounded,
      tooltip: 'خيارات التلاوة',
      onPressed: onOptions,
    ),
    // Previous points to the reading start (right in RTL); media icons are
    // not auto-mirrored by Flutter.
    _BarIconButton(
      tokens: tokens,
      icon: Icons.skip_next_rounded,
      tooltip: 'الآية السابقة',
      onPressed: onPrevious,
    ),
    MushafAudioPrimaryButton(
      tokens: tokens,
      status: state.status,
      onPressed: onPrimary,
    ),
    _BarIconButton(
      tokens: tokens,
      icon: Icons.skip_previous_rounded,
      tooltip: 'الآية التالية',
      onPressed: onNext,
    ),
    _BarIconButton(
      tokens: tokens,
      icon: Icons.close_rounded,
      tooltip: 'إغلاق التلاوة',
      onPressed: onClose,
    ),
  ];

  Widget _info() {
    final isError = state.hasError;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سورة $surahName · الآية ${_digits(ayahNumber)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tokens.chromeLabelStyle(size: 13, weight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Semantics(
          liveRegion: true,
          child: Text(
            mushafAudioStatusLabel(state),
            key: const ValueKey('mushaf-audio-status'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens
                .chromeLabelStyle(size: 11, weight: FontWeight.w500)
                .copyWith(color: isError ? tokens.error : tokens.chromeMuted),
          ),
        ),
      ],
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.tokens,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final MushafReaderTokens tokens;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(icon, size: 21),
      color: tokens.chromeInk,
      disabledColor: tokens.chromeMuted.withValues(alpha: 0.45),
    );
  }
}

/// Circular primary control. Shows a thin ring while loading.
class MushafAudioPrimaryButton extends StatelessWidget {
  const MushafAudioPrimaryButton({
    super.key,
    required this.tokens,
    required this.status,
    required this.onPressed,
  });

  final MushafReaderTokens tokens;
  final MushafAudioStatus status;
  final VoidCallback onPressed;

  static String tooltipFor(MushafAudioStatus status) => switch (status) {
    MushafAudioStatus.loading => 'إلغاء التحميل',
    MushafAudioStatus.playing => 'إيقاف مؤقت',
    MushafAudioStatus.error => 'إعادة المحاولة',
    MushafAudioStatus.paused => 'متابعة التلاوة',
    MushafAudioStatus.idle => 'تشغيل التلاوة',
  };

  @override
  Widget build(BuildContext context) {
    final loading = status == MushafAudioStatus.loading;
    final icon = switch (status) {
      MushafAudioStatus.playing => Icons.pause_rounded,
      MushafAudioStatus.error => Icons.refresh_rounded,
      _ => Icons.play_arrow_rounded,
    };
    return Tooltip(
      message: tooltipFor(status),
      child: Semantics(
        button: true,
        label: tooltipFor(status),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            key: const ValueKey('mushaf-audio-primary'),
            color: tokens.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: tokens.onAccent,
                          ),
                        )
                      : Icon(icon, size: 26, color: tokens.onAccent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2 px line at the top of the bar. Fills in reading direction (RTL).
class MushafAudioProgressLine extends StatelessWidget {
  const MushafAudioProgressLine({
    super.key,
    required this.tokens,
    required this.status,
    required this.positionStream,
    required this.durationStream,
  });

  final MushafReaderTokens tokens;
  final MushafAudioStatus status;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;

  @override
  Widget build(BuildContext context) {
    final showProgress =
        status == MushafAudioStatus.playing ||
        status == MushafAudioStatus.paused;
    return SizedBox(
      height: 2,
      child: !showProgress
          ? ColoredBox(color: tokens.divider)
          : StreamBuilder<Duration?>(
              stream: durationStream,
              builder: (context, durationSnap) => StreamBuilder<Duration>(
                stream: positionStream,
                builder: (context, positionSnap) {
                  final total = durationSnap.data?.inMilliseconds ?? 0;
                  final pos = positionSnap.data?.inMilliseconds ?? 0;
                  final fraction = total <= 0
                      ? 0.0
                      : (pos / total).clamp(0.0, 1.0);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: tokens.divider),
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: fraction,
                        child: ColoredBox(color: tokens.accent),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

/// "خيارات التلاوة": reciter choice + repeat-ayah. Auto-advance stays off.
class MushafAudioOptionsSheet extends StatefulWidget {
  const MushafAudioOptionsSheet({
    super.key,
    required this.tokens,
    required this.selectedReciterId,
    required this.isLooping,
    required this.playbackSpeed,
    required this.isMuted,
    required this.onSelectReciter,
    required this.onLoopChanged,
    required this.onCycleSpeed,
    required this.onToggleMute,
  });

  static const double maxWidth = 640;

  final MushafReaderTokens tokens;
  final String selectedReciterId;
  final bool isLooping;
  final double playbackSpeed;
  final bool isMuted;
  final ValueChanged<String> onSelectReciter;
  final ValueChanged<bool> onLoopChanged;
  final VoidCallback onCycleSpeed;
  final VoidCallback onToggleMute;

  @override
  State<MushafAudioOptionsSheet> createState() =>
      _MushafAudioOptionsSheetState();
}

class _MushafAudioOptionsSheetState extends State<MushafAudioOptionsSheet> {
  late bool _looping = widget.isLooping;
  late double _playbackSpeed = widget.playbackSpeed;
  late bool _muted = widget.isMuted;
  static const List<double> _speeds = [1.0, 1.25, 1.5, 2.0];

  @override
  void didUpdateWidget(covariant MushafAudioOptionsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackSpeed != widget.playbackSpeed) {
      _playbackSpeed = widget.playbackSpeed;
    }
    if (oldWidget.isMuted != widget.isMuted) {
      _muted = widget.isMuted;
    }
    if (oldWidget.isLooping != widget.isLooping) {
      _looping = widget.isLooping;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final muted = tokens
        .chromeLabelStyle(size: 11.5, weight: FontWeight.w500)
        .copyWith(color: tokens.chromeMuted);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.chrome,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: tokens.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.chromeMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'خيارات التلاوة',
                  style: tokens.chromeLabelStyle(
                    size: 16,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text('القارئ', style: muted),
                const SizedBox(height: 4),
                for (final reciter in MushafReciters.all)
                  _ReciterRow(
                    tokens: tokens,
                    reciter: reciter,
                    selected: reciter.id == widget.selectedReciterId,
                    onTap: () => widget.onSelectReciter(reciter.id),
                  ),
                Divider(height: 20, color: tokens.divider),
                Semantics(
                  toggled: _muted,
                  label: '\u0643\u062a\u0645 \u0627\u0644\u0635\u0648\u062a',
                  excludeSemantics: true,
                  child: InkWell(
                    key: const ValueKey('mushaf-audio-mute'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _muted = !_muted);
                      widget.onToggleMute();
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Row(
                        children: [
                          Icon(
                            _muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 20,
                            color: _muted
                                ? tokens.accent
                                : tokens.chromeMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '\u0643\u062a\u0645 \u0627\u0644\u0635\u0648\u062a',
                              style: tokens.chromeLabelStyle(size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: '\u0633\u0631\u0639\u0629 \u0627\u0644\u062a\u0634\u063a\u064a\u0644',
                  excludeSemantics: true,
                  child: InkWell(
                    key: const ValueKey('mushaf-audio-speed'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final idx = _speeds.indexOf(_playbackSpeed);
                      final next =
                          _speeds[((idx < 0 ? 0 : idx) + 1) % _speeds.length];
                      setState(() => _playbackSpeed = next);
                      widget.onCycleSpeed();
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Row(
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            size: 20,
                            color: tokens.chromeMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '\u0633\u0631\u0639\u0629 \u0627\u0644\u062a\u0634\u063a\u064a\u0644',
                              style: tokens.chromeLabelStyle(size: 14),
                            ),
                          ),
                          Text(
                            _speedChipLabel(_playbackSpeed),
                            key: const ValueKey('mushaf-audio-speed-chip'),
                            style: tokens.chromeLabelStyle(size: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(height: 20, color: tokens.divider),
                Semantics(
                  toggled: _looping,
                  label: '\u062a\u0643\u0631\u0627\u0631 \u0627\u0644\u0622\u064a\u0629',
                  excludeSemantics: true,
                  child: InkWell(
                    key: const ValueKey('mushaf-audio-loop'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _looping = !_looping);
                      widget.onLoopChanged(_looping);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat_one_rounded,
                            size: 20,
                            color: _looping
                                ? tokens.accent
                                : tokens.chromeMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'تكرار الآية',
                                  style: tokens.chromeLabelStyle(size: 14),
                                ),
                                Text(
                                  'تُعاد الآية نفسها، ولا تنتقل التلاوة '
                                  'إلى الآية التالية تلقائياً',
                                  style: muted,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Toggle(tokens: tokens, on: _looping),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReciterRow extends StatelessWidget {
  const _ReciterRow({
    required this.tokens,
    required this.reciter,
    required this.selected,
    required this.onTap,
  });

  final MushafReaderTokens tokens;
  final MushafReciter reciter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'القارئ ${reciter.name}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('mushaf-reciter-${reciter.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  reciter.name,
                  style: tokens
                      .chromeLabelStyle(
                        size: 14,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                      )
                      .copyWith(
                        color: selected ? tokens.accent : tokens.chromeInk,
                      ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: tokens.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.tokens, required this.on});

  final MushafReaderTokens tokens;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 38,
      height: 22,
      padding: const EdgeInsets.all(3),
      alignment: on
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: on ? tokens.accent : tokens.divider,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: on ? tokens.onAccent : tokens.chrome,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}


String _speedChipLabel(double speed) {
  if ((speed - 1.0).abs() < 0.001) return 'x1';
  if ((speed - 1.25).abs() < 0.001) return 'x1.25';
  if ((speed - 1.5).abs() < 0.001) return 'x1.5';
  if ((speed - 2.0).abs() < 0.001) return 'x2';
  return 'x${speed.toStringAsFixed(2)}';
}
Future<void> showMushafAudioOptionsSheet({
  required BuildContext context,
  required MushafReaderTokens tokens,
  required String selectedReciterId,
  required bool isLooping,
  required double playbackSpeed,
  required bool isMuted,
  required ValueChanged<String> onSelectReciter,
  required ValueChanged<bool> onLoopChanged,
  required VoidCallback onCycleSpeed,
  required VoidCallback onToggleMute,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: tokens.isNight ? 0.5 : 0.28),
    constraints: const BoxConstraints(
      maxWidth: MushafAudioOptionsSheet.maxWidth,
    ),
    builder: (sheetContext) => MushafAudioOptionsSheet(
      tokens: tokens,
      selectedReciterId: selectedReciterId,
      isLooping: isLooping,
      playbackSpeed: playbackSpeed,
      isMuted: isMuted,
      onSelectReciter: (id) {
        onSelectReciter(id);
        Navigator.of(sheetContext).pop();
      },
      onLoopChanged: onLoopChanged,
      onCycleSpeed: onCycleSpeed,
      onToggleMute: onToggleMute,
    ),
  );
}
