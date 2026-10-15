import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/features/player/playback_cubit.dart';
import 'package:musico_app/providers/audio_player_provider.dart';

class _FakePlaybackEngine extends ChangeNotifier implements PlaybackEngine {
  bool playing = false;

  @override
  Track? get currentTrack => null;
  @override
  Duration get duration => Duration.zero;
  @override
  String get errorMessage => '';
  @override
  bool get isLoading => false;
  @override
  bool get isPlaying => playing;
  @override
  Duration get position => Duration.zero;
  @override
  bool get repeatEnabled => false;
  @override
  bool get shuffleEnabled => false;

  @override
  Future<void> togglePlayPause() async {
    playing = !playing;
    notifyListeners();
  }

  @override
  Future<void> loadTrackById(int trackId) async {}
  @override
  Future<void> loadAndPlayTracks(
    List<Map<String, dynamic>> rows,
    int startId,
  ) async {}
  @override
  Future<void> loadAndPlayPlaylist(
    int playlistId, {
    int startTrackId = -1,
  }) async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> playPreviousTrack() async {}
  @override
  Future<void> playNextTrack() async {}
  @override
  void toggleRepeatMode() {}
  @override
  void toggleShuffleMode() {}
}

void main() {
  test(
    'publishes playback engine updates and routes commands through cubit',
    () async {
      final engine = _FakePlaybackEngine();
      final cubit = PlaybackCubit(engine);

      await cubit.togglePlayPause();

      expect(cubit.state.isPlaying, isTrue);
      await cubit.close();
    },
  );
}
