import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import '../bloc/audio_bloc.dart';
import '../bloc/audio_event.dart';
import '../bloc/audio_state.dart';
import '../../domain/entities/audio_entities.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AudioLibraryBloc, AudioLibraryState>(
      // يسمع بس لما رسالة الخطأ تتغير، عشان الـ SnackBar متتكررش كل build
      listenWhen: (previous, current) =>
          previous.playbackError != current.playbackError &&
          current.playbackError != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                state.playbackError!,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'NotoNaskhArabic'),
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
      },
      child: BlocBuilder<AudioLibraryBloc, AudioLibraryState>(
        builder: (context, state) {
          if (state.selectedSurah == null) {
            return const SizedBox.shrink();
          }

          final surah = state.selectedSurah!;

          final durationMs = state.duration?.inMilliseconds.toDouble() ?? 0.0;
          final positionMs = state.position.inMilliseconds.toDouble().clamp(
            0.0,
            durationMs == 0 ? 0.0 : durationMs,
          );

          return Container(
            color: AppColors.darkCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (state.isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          state.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          if (state.isPlaying) {
                            context.read<AudioLibraryBloc>().add(
                              const PausePlaybackEvent(),
                            );
                          } else {
                            context.read<AudioLibraryBloc>().add(
                              const ResumePlaybackEvent(),
                            );
                          }
                        },
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // مؤشر صغير إن الصوت شغال دلوقتي
                              if (state.isPlaying) ...[
                                const SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  '${surah.surahName} - ${surah.reciterName ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'NotoNaskhArabic',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white54,
                              thumbColor: Colors.white,
                              overlayColor: Colors.white24,
                            ),
                            child: Slider(
                              value: positionMs,
                              max: durationMs,
                              onChanged: durationMs == 0
                                  ? null
                                  : (value) {
                                      context.read<AudioLibraryBloc>().add(
                                        SeekToPositionEvent(
                                          Duration(milliseconds: value.toInt()),
                                        ),
                                      );
                                    },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(
                                  state.duration ?? Duration.zero,
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                _formatDuration(state.position),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
