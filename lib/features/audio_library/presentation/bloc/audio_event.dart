import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/audio_entities.dart';

abstract class AudioLibraryEvent extends Equatable {
  const AudioLibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Load all required data
class LoadAudioLibraryEvent extends AudioLibraryEvent {
  const LoadAudioLibraryEvent();
}

/// Toggle follow reciter
class ToggleFollowReciterEvent extends AudioLibraryEvent {
  final String reciterId;
  final bool isFollowing;

  const ToggleFollowReciterEvent({
    required this.reciterId,
    required this.isFollowing,
  });

  @override
  List<Object?> get props => [reciterId, isFollowing];
}

/// Select surah to play
class SelectSurahAudioEvent extends AudioLibraryEvent {
  final SurahAudioEntity surah;

  const SelectSurahAudioEvent(this.surah);

  @override
  List<Object?> get props => [surah];
}

/// Play selected surah
class PlaySurahAudioEvent extends AudioLibraryEvent {
  const PlaySurahAudioEvent();
}

/// Pause playback
class PausePlaybackEvent extends AudioLibraryEvent {
  const PausePlaybackEvent();
}

/// Resume playback
class ResumePlaybackEvent extends AudioLibraryEvent {
  const ResumePlaybackEvent();
}

/// Seek to position
class SeekToPositionEvent extends AudioLibraryEvent {
  final Duration position;

  const SeekToPositionEvent(this.position);

  @override
  List<Object?> get props => [position];
}

/// Update search query
class SearchAudioLibraryEvent extends AudioLibraryEvent {
  final String query;

  const SearchAudioLibraryEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class SelectReciterEvent extends AudioLibraryEvent {
  final String? reciterId;

  const SelectReciterEvent(this.reciterId);

  @override
  List<Object?> get props => [reciterId];
}
