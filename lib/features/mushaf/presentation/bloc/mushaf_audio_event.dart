import 'package:equatable/equatable.dart';

import '../../domain/services/mushaf_audio_engine.dart';

abstract class MushafAudioEvent extends Equatable {
  const MushafAudioEvent();

  @override
  List<Object?> get props => [];
}

/// Switch to a verified reciter by id. Unknown ids are ignored.
class MushafAudioSelectReciterEvent extends MushafAudioEvent {
  final String reciterId;

  const MushafAudioSelectReciterEvent(this.reciterId);

  @override
  List<Object?> get props => [reciterId];
}

/// The reader selected an ayah. Stops audio that belongs to another ayah.
class MushafAudioSetTargetEvent extends MushafAudioEvent {
  final int surahNumber;
  final int ayahNumberInSurah;

  const MushafAudioSetTargetEvent({
    required this.surahNumber,
    required this.ayahNumberInSurah,
  });

  @override
  List<Object?> get props => [surahNumber, ayahNumberInSurah];
}

/// Play (or resume) this ayah. Repeated requests while loading/playing the
/// same ayah are ignored.
class MushafAudioPlayAyahEvent extends MushafAudioEvent {
  final int surahNumber;
  final int ayahNumberInSurah;

  const MushafAudioPlayAyahEvent({
    required this.surahNumber,
    required this.ayahNumberInSurah,
  });

  @override
  List<Object?> get props => [surahNumber, ayahNumberInSurah];
}

class MushafAudioPauseEvent extends MushafAudioEvent {
  const MushafAudioPauseEvent();
}

class MushafAudioStopEvent extends MushafAudioEvent {
  /// Also forget the target ayah (e.g. the reader closed the audio bar).
  final bool clearTarget;

  const MushafAudioStopEvent({this.clearTarget = false});

  @override
  List<Object?> get props => [clearTarget];
}

class MushafAudioToggleLoopEvent extends MushafAudioEvent {
  const MushafAudioToggleLoopEvent();
}

class MushafAudioClearErrorEvent extends MushafAudioEvent {
  const MushafAudioClearErrorEvent();
}

/// Internal — engine playback state changed.
class MushafAudioEngineSnapshotEvent extends MushafAudioEvent {
  final MushafEngineSnapshot snapshot;

  const MushafAudioEngineSnapshotEvent(this.snapshot);

  @override
  List<Object?> get props => [snapshot.playing, snapshot.phase];
}

/// Internal — engine reported a playback error.
class MushafAudioEngineErrorEvent extends MushafAudioEvent {
  const MushafAudioEngineErrorEvent();
}
