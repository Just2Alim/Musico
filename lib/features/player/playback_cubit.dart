import 'package:flutter_bloc/flutter_bloc.dart';

import '../../providers/audio_player_provider.dart';

class PlaybackState {
  const PlaybackState({
    required this.currentTrack,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.duration,
    required this.errorMessage,
    required this.repeatEnabled,
    required this.shuffleEnabled,
  });

  factory PlaybackState.fromEngine(PlaybackEngine engine) => PlaybackState(
    currentTrack: engine.currentTrack,
    isPlaying: engine.isPlaying,
    isLoading: engine.isLoading,
    position: engine.position,
    duration: engine.duration,
    errorMessage: engine.errorMessage,
    repeatEnabled: engine.repeatEnabled,
    shuffleEnabled: engine.shuffleEnabled,
  );

  final Track? currentTrack;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final String errorMessage;
  final bool repeatEnabled;
  final bool shuffleEnabled;
}

class PlaybackCubit extends Cubit<PlaybackState> {
  PlaybackCubit(this._engine) : super(PlaybackState.fromEngine(_engine)) {
    _engine.addListener(_syncFromEngine);
  }

  final PlaybackEngine _engine;

  void _syncFromEngine() => emit(PlaybackState.fromEngine(_engine));

  Future<void> loadTrackById(int trackId) => _engine.loadTrackById(trackId);

  Future<void> playTracks(List<Map<String, dynamic>> tracks, int startId) =>
      _engine.loadAndPlayTracks(tracks, startId);

  Future<void> playPlaylist(int playlistId, {int startTrackId = -1}) =>
      _engine.loadAndPlayPlaylist(playlistId, startTrackId: startTrackId);

  Future<void> togglePlayPause() => _engine.togglePlayPause();

  Future<void> seekTo(Duration position) => _engine.seekTo(position);

  Future<void> playPrevious() => _engine.playPreviousTrack();

  Future<void> playNext() => _engine.playNextTrack();

  void toggleRepeat() => _engine.toggleRepeatMode();

  void toggleShuffle() => _engine.toggleShuffleMode();

  @override
  Future<void> close() {
    _engine.removeListener(_syncFromEngine);
    return super.close();
  }
}
