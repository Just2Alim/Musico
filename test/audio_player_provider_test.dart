import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:musico_app/data/music_repository.dart';
import 'package:musico_app/features/player/playback_cubit.dart';
import 'package:musico_app/providers/audio_player_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _SourceFake extends Fake implements Source {}

class _FakeRepository extends MusicRepository {
  Completer<void>? favoriteUpdate;
  Object? trackError;
  Object? playlistError;
  Object? favoriteError;
  Object? historyError;
  List<Map<String, dynamic>>? playlistRows;
  final listening = <({int id, bool completed})>[];
  final pendingTracks = <int, Completer<Map<String, dynamic>?>>{};
  final pendingFavorites = <int, Completer<bool>>{};

  @override
  Future<Map<String, dynamic>?> track(int id) async {
    if (trackError != null) throw trackError!;
    if (pendingTracks.containsKey(id)) return pendingTracks[id]!.future;
    final rows = await tracks();
    return rows.where((row) => row['id'] == id).firstOrNull;
  }

  @override
  Future<void> setFavorite(int trackId, bool favorite) async {
    await favoriteUpdate?.future;
  }

  _FakeRepository()
    : super(SupabaseClient('https://example.test', 'public-test-key'));

  @override
  Future<List<Map<String, dynamic>>> tracks({
    String? query,
    int from = 0,
    int limit = 30,
  }) async => [
    {'id': 1, 'name': 'First', 'audio_file_url': 'https://example.test/1.mp3'},
    {'id': 2, 'name': 'Second', 'audio_file_url': 'https://example.test/2.mp3'},
  ];

  @override
  Future<bool> isFavorite(int trackId) async {
    if (favoriteError != null) throw favoriteError!;
    final pending = pendingFavorites[trackId];
    return pending == null ? trackId == 2 : await pending.future;
  }

  @override
  Future<void> recordListening(int trackId, {required bool completed}) async {
    if (historyError != null) throw historyError!;
    listening.add((id: trackId, completed: completed));
  }

  @override
  Future<List<Map<String, dynamic>>> playlistTracks(int playlistId) async {
    if (playlistError != null) throw playlistError!;
    return playlistRows ?? await tracks();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(_SourceFake());
    registerFallbackValue(Duration.zero);
  });
  late _MockAudioPlayer audio;
  late AudioPlayerAlternativeProvider provider;
  late _FakeRepository repository;

  setUp(() {
    audio = _MockAudioPlayer();
    when(
      () => audio.onPlayerStateChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(() => audio.onPositionChanged).thenAnswer((_) => const Stream.empty());
    when(() => audio.onDurationChanged).thenAnswer((_) => const Stream.empty());
    when(() => audio.onPlayerComplete).thenAnswer((_) => const Stream.empty());
    when(() => audio.stop()).thenAnswer((_) async {});
    when(() => audio.play(any<Source>())).thenAnswer((_) async {});
    when(() => audio.seek(any<Duration>())).thenAnswer((_) async {});
    when(() => audio.dispose()).thenAnswer((_) async {});
    when(() => audio.pause()).thenAnswer((_) async {});
    when(() => audio.resume()).thenAnswer((_) async {});
    repository = _FakeRepository();
    provider = AudioPlayerAlternativeProvider(repository, audioPlayer: audio);
  });

  tearDown(() => provider.dispose());

  test('loads and starts a track from the Supabase catalogue', () async {
    await provider.loadTrackById(2);

    expect(provider.currentTrack?.id, 2);
    expect(provider.currentTrack?.isLiked, isTrue);
    expect(provider.isPlaying, isTrue);
    verify(() => audio.play(any<Source>())).called(1);
  });

  test(
    'catalog queue hydrates the saved favorite without restarting audio',
    () async {
      await provider.loadAndPlayTracks(await repository.tracks(), 2);
      expect(provider.currentTrack?.id, 2);
      expect(provider.currentTrack?.isLiked, isTrue);
      expect(provider.playlist.last.isLiked, isTrue);
      verify(() => audio.play(any<Source>())).called(1);
    },
  );

  test('late favorite hydration cannot undo a new user toggle', () async {
    repository.pendingFavorites[1] = Completer<bool>();
    final loading = provider.loadAndPlayTracks(await repository.tracks(), 1);
    await Future<void>.delayed(Duration.zero);
    await provider.toggleFavorite();
    repository.pendingFavorites[1]!.complete(false);
    await loading;
    expect(provider.currentTrack?.id, 1);
    expect(provider.currentTrack?.isLiked, isTrue);
  });

  test(
    'late favorite hydration cannot replace a different playing track',
    () async {
      repository.pendingFavorites[1] = Completer<bool>();
      final older = provider.loadAndPlayTracks(await repository.tracks(), 1);
      await Future<void>.delayed(Duration.zero);
      await provider.loadAndPlayTracks(await repository.tracks(), 2);
      repository.pendingFavorites[1]!.complete(false);
      await older;
      expect(provider.currentTrack?.id, 2);
      expect(provider.currentTrack?.isLiked, isTrue);
    },
  );

  test(
    'reopening the current player preserves position and paused state',
    () async {
      final states = StreamController<PlayerState>.broadcast(sync: true);
      when(() => audio.onPlayerStateChanged).thenAnswer((_) => states.stream);
      final positions = StreamController<Duration>.broadcast(sync: true);
      when(() => audio.onPositionChanged).thenAnswer((_) => positions.stream);
      provider.dispose();
      provider = AudioPlayerAlternativeProvider(repository, audioPlayer: audio);
      await provider.loadTrackById(1);
      positions.add(const Duration(seconds: 12));
      states.add(PlayerState.paused);
      await provider.loadTrackById(1);

      expect(provider.position, const Duration(seconds: 12));
      expect(provider.isPlaying, isFalse);
      verify(() => audio.play(any<Source>())).called(1);
      await positions.close();
      await states.close();
    },
  );

  test('coalesces simultaneous requests for the same track', () async {
    await Future.wait([provider.loadTrackById(1), provider.loadTrackById(1)]);
    verify(() => audio.play(any<Source>())).called(1);
  });

  test('new track resets stale progress before audio prepares', () async {
    final positions = StreamController<Duration>.broadcast(sync: true);
    final durations = StreamController<Duration>.broadcast(sync: true);
    when(() => audio.onPositionChanged).thenAnswer((_) => positions.stream);
    when(() => audio.onDurationChanged).thenAnswer((_) => durations.stream);
    provider.dispose();
    provider = AudioPlayerAlternativeProvider(repository, audioPlayer: audio);
    await provider.loadTrackById(1);
    positions.add(const Duration(seconds: 120));
    durations.add(const Duration(seconds: 180));
    final ready = Completer<void>();
    when(() => audio.play(any<Source>())).thenAnswer((_) => ready.future);
    final loading = provider.playTrack(
      const Track(
        id: 2,
        name: 'Short',
        artist: 'Artist',
        duration: 9,
        audioFileUrl: 'https://example.test/short.mp3',
      ),
    );
    expect(provider.position, Duration.zero);
    expect(provider.duration, const Duration(seconds: 9));
    ready.complete();
    await loading;
    await positions.close();
    await durations.close();
  });

  test('failed favorite update cannot change a newly selected track', () async {
    await provider.loadTrackById(1);
    repository.favoriteUpdate = Completer<void>();
    final favorite = provider.toggleFavorite();
    await provider.loadTrackById(2);
    repository.favoriteUpdate!.completeError(StateError('Offline'));
    await favorite;
    expect(provider.currentTrack?.id, 2);
    expect(provider.currentTrack?.isLiked, isTrue);
  });

  test(
    'an older catalog response cannot replace the latest selection',
    () async {
      repository.pendingTracks[1] = Completer<Map<String, dynamic>?>();
      repository.pendingTracks[2] = Completer<Map<String, dynamic>?>();
      final older = provider.loadTrackById(1);
      final newer = provider.loadTrackById(2);
      repository.pendingTracks[2]!.complete({
        'id': 2,
        'name': 'New selection',
        'audio_file_url': 'https://example.test/2.mp3',
      });
      await newer;
      repository.pendingTracks[1]!.complete({
        'id': 1,
        'name': 'Old selection',
        'audio_file_url': 'https://example.test/1.mp3',
      });
      await older;
      expect(provider.currentTrack?.id, 2);
      verify(() => audio.play(any<Source>())).called(1);
    },
  );

  test(
    'favorite failure restores the same track and exposes a friendly error',
    () async {
      await provider.loadTrackById(1);
      repository.favoriteUpdate = Completer<void>();
      final favorite = provider.toggleFavorite();
      repository.favoriteUpdate!.completeError(const AuthException('Sign in'));
      await favorite;
      expect(provider.currentTrack?.isLiked, isFalse);
      expect(provider.errorMessage, contains('Войдите'));
    },
  );

  test(
    'an old audio preparation error cannot overwrite a newer playing track',
    () async {
      final oldAudio = Completer<void>();
      when(() => audio.play(any<Source>())).thenAnswer((invocation) {
        final source = invocation.positionalArguments.first as UrlSource;
        return source.url.endsWith('/1.mp3')
            ? oldAudio.future
            : Future<void>.value();
      });
      final older = provider.playTrack(
        const Track(
          id: 1,
          name: 'Old',
          artist: 'Artist',
          duration: 20,
          audioFileUrl: 'https://example.test/1.mp3',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final newer = provider.playTrack(
        const Track(
          id: 2,
          name: 'New',
          artist: 'Artist',
          duration: 30,
          audioFileUrl: 'https://example.test/2.mp3',
        ),
      );
      oldAudio.completeError(StateError('Old request failed'));
      await Future.wait([older, newer]);
      expect(provider.currentTrack?.id, 2);
      expect(provider.isPlaying, isTrue);
      expect(provider.errorMessage, isEmpty);
    },
  );

  test('detaches audio events before the provider is disposed', () async {
    final events = StreamController<PlayerState>.broadcast(sync: true);
    when(() => audio.onPlayerStateChanged).thenAnswer((_) => events.stream);
    provider.dispose();
    provider = AudioPlayerAlternativeProvider(
      _FakeRepository(),
      audioPlayer: audio,
    );
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.dispose();
    events.add(PlayerState.stopped);
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 0);
    await events.close();
  });

  test(
    'reports missing track and empty audio URL without starting playback',
    () async {
      await provider.loadTrackById(404);
      expect(provider.errorMessage, 'Track data not found');

      await provider.loadAndPlayTracks([
        {'id': 3, 'name': 'Silent'},
      ], 3);
      expect(provider.errorMessage, 'Audio URL is empty');
      expect(provider.isLoading, isFalse);
    },
  );

  test(
    'steps through queue and stops at its end unless repeat is enabled',
    () async {
      await provider.loadAndPlayTracks([
        {
          'id': 1,
          'name': 'First',
          'audioFileUrl': 'https://example.test/1.mp3',
        },
        {
          'id': 2,
          'name': 'Second',
          'audioFileUrl': 'https://example.test/2.mp3',
        },
      ], 1);
      await provider.playNextTrack();
      expect(provider.currentTrack?.id, 2);
      await provider.playNextTrack();
      expect(provider.isPlaying, isFalse);

      provider.toggleRepeatMode();
      await provider.playNextTrack();
      expect(provider.currentTrack?.id, 1);
    },
  );

  test(
    'returns playlist tracks and handles controls when no track is selected',
    () async {
      expect(await provider.getPlaylistTracks(1), hasLength(2));
      await provider.togglePlayPause();
      expect(provider.errorMessage, 'No track selected');
      await provider.playPreviousTrack();
      await provider.playNextTrack();
      provider.toggleShuffleMode();
      expect(provider.shuffleEnabled, isTrue);
    },
  );
  test('play and pause follow native player state changes', () async {
    final states = StreamController<PlayerState>.broadcast(sync: true);
    when(() => audio.onPlayerStateChanged).thenAnswer((_) => states.stream);
    provider.dispose();
    provider = AudioPlayerAlternativeProvider(repository, audioPlayer: audio);
    await provider.loadTrackById(1);
    states.add(PlayerState.playing);
    await provider.togglePlayPause();
    verify(() => audio.pause()).called(1);
    states.add(PlayerState.paused);
    expect(provider.isPlaying, isFalse);
    await provider.togglePlayPause();
    verify(() => audio.resume()).called(1);
    states.add(PlayerState.playing);
    expect(provider.isPlaying, isTrue);
    states.add(PlayerState.stopped);
    expect(provider.isPlaying, isFalse);
    states.add(PlayerState.completed);
    expect(repository.listening, contains((id: 1, completed: true)));
    states.add(PlayerState.disposed);
    expect(provider.isPlaying, isFalse);
    await states.close();
  });

  test('catalog failures stop loading and permit a later retry', () async {
    repository.trackError = StateError('Offline');
    await provider.loadTrackById(1);
    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, contains('Error loading track'));
    repository.trackError = null;
    await provider.loadTrackById(1);
    expect(provider.errorMessage, isEmpty);
    expect(provider.isPlaying, isTrue);
  });

  test('audio preparation failure is visible and retry can recover', () async {
    when(
      () => audio.play(any<Source>()),
    ).thenThrow(StateError('Unavailable audio'));
    await provider.loadTrackById(1);
    expect(provider.errorMessage, contains('Error playing track'));
    expect(provider.isLoading, isFalse);
    expect(provider.isPlaying, isFalse);
    when(() => audio.play(any<Source>())).thenAnswer((_) async {});
    await provider.loadTrackById(1);
    expect(provider.isPlaying, isTrue);
    expect(provider.errorMessage, isEmpty);
  });

  test(
    'pause and seek errors are reported without discarding selection',
    () async {
      await provider.loadTrackById(1);
      when(() => audio.pause()).thenThrow(StateError('Audio route lost'));
      await provider.togglePlayPause();
      expect(provider.errorMessage, contains('Error toggling play/pause'));
      expect(provider.currentTrack?.id, 1);
      await provider.seekTo(const Duration(seconds: 8));
      verify(() => audio.seek(const Duration(seconds: 8))).called(1);
      when(
        () => audio.seek(any<Duration>()),
      ).thenThrow(StateError('Seek unavailable'));
      await provider.seekTo(const Duration(seconds: 10));
      expect(provider.errorMessage, contains('Error seeking'));
      expect(provider.currentTrack?.id, 1);
    },
  );

  test(
    'metadata and listening-history outages do not stop public playback',
    () async {
      repository.favoriteError = StateError('Favorites unavailable');
      repository.historyError = StateError('History unavailable');
      await provider.loadAndPlayTracks(await repository.tracks(), 1);
      await Future<void>.delayed(Duration.zero);
      expect(provider.currentTrack?.id, 1);
      expect(provider.isPlaying, isTrue);
      expect(provider.errorMessage, isEmpty);
    },
  );

  test(
    'previous restarts after three seconds and wraps only with repeat',
    () async {
      final positions = StreamController<Duration>.broadcast(sync: true);
      when(() => audio.onPositionChanged).thenAnswer((_) => positions.stream);
      provider.dispose();
      provider = AudioPlayerAlternativeProvider(repository, audioPlayer: audio);
      await provider.loadAndPlayTracks(await repository.tracks(), 2);
      positions.add(const Duration(seconds: 12));
      await provider.playPreviousTrack();
      expect(provider.currentTrack?.id, 2);
      verify(() => audio.seek(Duration.zero)).called(1);
      positions.add(Duration.zero);
      await provider.playPreviousTrack();
      expect(provider.currentTrack?.id, 1);
      provider.toggleRepeatMode();
      expect(provider.repeatEnabled, isTrue);
      await provider.playPreviousTrack();
      expect(provider.currentTrack?.id, 2);
      expect(provider.currentTrackIndex, 1);
      await positions.close();
    },
  );

  test(
    'shuffle preserves the selected track and the queue membership',
    () async {
      await provider.loadAndPlayTracks(await repository.tracks(), 2);
      provider.toggleShuffleMode();
      expect(provider.shuffleEnabled, isTrue);
      expect(provider.currentTrack?.id, 2);
      expect(
        provider.playlist.map((track) => track.id),
        unorderedEquals([1, 2]),
      );
      expect(provider.playlist[provider.currentTrackIndex].id, 2);
      provider.toggleShuffleMode();
      expect(provider.shuffleEnabled, isFalse);
    },
  );

  test(
    'playlist starts at the selected track and defaults to its first track',
    () async {
      await provider.loadAndPlayPlaylist(10, startTrackId: 2);
      expect(provider.currentTrack?.id, 2);
      expect(provider.currentTrack?.isLiked, isTrue);
      await provider.loadAndPlayPlaylist(10, startTrackId: 999);
      expect(provider.currentTrack?.id, 1);
      await provider.loadAndPlayPlaylist(10);
      expect(provider.currentTrack?.id, 1);
    },
  );

  test(
    'shuffled playlist starts with the requested track and keeps all songs',
    () async {
      provider.toggleShuffleMode();
      await provider.loadAndPlayPlaylist(10, startTrackId: 2);
      expect(provider.currentTrack?.id, 2);
      expect(provider.currentTrackIndex, 0);
      expect(
        provider.playlist.map((track) => track.id),
        unorderedEquals([1, 2]),
      );
      await provider.loadAndPlayPlaylist(10, startTrackId: 999);
      expect(provider.currentTrack?.id, 1);
      await provider.loadAndPlayPlaylist(10);
      expect(provider.currentTrack?.id, 1);
    },
  );

  test('empty or unavailable playlists do not start audio', () async {
    repository.playlistRows = [];
    await provider.loadAndPlayPlaylist(10);
    expect(provider.errorMessage, 'Плейлист пуст');
    expect(provider.currentTrack, isNull);
    repository.playlistError = StateError('Unavailable');
    expect(await provider.getPlaylistTracks(10), isEmpty);
    verifyNever(() => audio.play(any<Source>()));
  });

  test(
    'queue can be extended and cleared without stopping the selected track',
    () async {
      await provider.loadAndPlayTracks(await repository.tracks(), 1);
      provider.addToQueue(
        const Track(
          id: 3,
          name: 'Third',
          artist: 'Artist',
          duration: 50,
          audioFileUrl: 'https://example.test/3.mp3',
        ),
      );
      expect(provider.playlist.map((track) => track.id), [1, 2, 3]);
      expect(() => provider.playlist.clear(), throwsUnsupportedError);
      provider.clearQueue();
      expect(provider.playlist, isEmpty);
      expect(provider.currentTrackIndex, 0);
      expect(provider.currentTrack?.id, 1);
      expect(provider.isPlaying, isTrue);
    },
  );

  test(
    'completing a queued track records history and advances to the next',
    () async {
      final completions = StreamController<void>.broadcast(sync: true);
      when(() => audio.onPlayerComplete).thenAnswer((_) => completions.stream);
      provider.dispose();
      provider = AudioPlayerAlternativeProvider(repository, audioPlayer: audio);
      await provider.loadAndPlayTracks(await repository.tracks(), 1);
      completions.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repository.listening, contains((id: 1, completed: true)));
      expect(provider.currentTrack?.id, 2);
      await completions.close();
    },
  );

  test(
    'single track completion stops or repeats according to repeat mode',
    () async {
      final completions = StreamController<void>.broadcast(sync: true);
      when(() => audio.onPlayerComplete).thenAnswer((_) => completions.stream);
      provider.dispose();
      provider = AudioPlayerAlternativeProvider(repository, audioPlayer: audio);
      await provider.loadTrackById(1);
      completions.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(provider.isPlaying, isFalse);
      provider.toggleRepeatMode();
      completions.add(null);
      await Future<void>.delayed(Duration.zero);
      verify(() => audio.seek(Duration.zero)).called(1);
      verify(() => audio.resume()).called(1);
      await completions.close();
    },
  );

  test(
    'shake setting restores from storage and disabling it is persisted',
    () async {
      SharedPreferences.setMockInitialValues({'shake_to_skip_enabled': true});
      const methods = MethodChannel('dev.fluttercommunity.plus/sensors/method');
      const events = MethodChannel(
        'dev.fluttercommunity.plus/sensors/accelerometer',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(methods, (_) async => null);
      messenger.setMockMethodCallHandler(events, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(methods, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      await provider.loadShakeToSkipSetting();
      expect(provider.shakeToSkipEnabled, isTrue);
      await provider.setShakeToSkipEnabled(true);
      await provider.setShakeToSkipEnabled(false);
      expect(provider.shakeToSkipEnabled, isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('shake_to_skip_enabled'), isFalse);
      await provider.loadShakeToSkipSetting();
      expect(provider.shakeToSkipEnabled, isFalse);
    },
  );

  test('Cubit playback commands update the real provider state', () async {
    final cubit = PlaybackCubit(provider);
    addTearDown(cubit.close);
    await cubit.loadTrackById(1);
    expect(cubit.state.currentTrack?.id, 1);
    await cubit.playTracks(await repository.tracks(), 2);
    expect(cubit.state.currentTrack?.id, 2);
    await cubit.playPrevious();
    expect(cubit.state.currentTrack?.id, 1);
    await cubit.playNext();
    expect(cubit.state.currentTrack?.id, 2);
    cubit.toggleRepeat();
    expect(cubit.state.repeatEnabled, isTrue);
    cubit.toggleShuffle();
    expect(cubit.state.shuffleEnabled, isTrue);
    await cubit.playPlaylist(10, startTrackId: 1);
    expect(cubit.state.currentTrack?.id, 1);
    await cubit.seekTo(const Duration(seconds: 7));
    verify(() => audio.seek(const Duration(seconds: 7))).called(1);
    await cubit.togglePlayPause();
    verify(() => audio.pause()).called(1);
  });
}
