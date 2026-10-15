import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:musico_app/features/player/music_audio_handler.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _SourceFake extends Fake implements Source {}

void main() {
  setUpAll(() {
    registerFallbackValue(_SourceFake());
    registerFallbackValue(Duration.zero);
  });

  late _MockAudioPlayer player;
  late MusicAudioHandler handler;
  late StreamController<PlayerState> states;
  late StreamController<Duration> positions;
  late StreamController<void> completions;

  setUp(() {
    player = _MockAudioPlayer();
    states = StreamController<PlayerState>.broadcast(sync: true);
    positions = StreamController<Duration>.broadcast(sync: true);
    completions = StreamController<void>.broadcast(sync: true);
    when(() => player.onPlayerStateChanged).thenAnswer((_) => states.stream);
    when(() => player.onPositionChanged).thenAnswer((_) => positions.stream);
    when(
      () => player.onDurationChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(() => player.onPlayerComplete).thenAnswer((_) => completions.stream);
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.play(any<Source>())).thenAnswer((_) async {});
    when(() => player.pause()).thenAnswer((_) async {});
    when(() => player.resume()).thenAnswer((_) async {});
    when(() => player.seek(any<Duration>())).thenAnswer((_) async {});
    handler = MusicAudioHandler(player);
  });

  tearDown(() async {
    await handler.dispose();
    await states.close();
    await positions.close();
    await completions.close();
  });

  test('publishes media metadata and starts the selected item', () async {
    final item = MediaItem(
      id: 'https://example.test/song.mp3',
      title: 'North',
      artist: 'Aster',
    );

    await handler.playMediaItem(item);

    expect(handler.mediaItem.value?.title, 'North');
    expect(handler.playbackState.value.playing, isTrue);
    verify(() => player.play(any<Source>())).called(1);
  });

  test('forwards pause and seek requests to the audio engine', () async {
    await handler.pause();
    await handler.seek(const Duration(seconds: 12));

    verify(() => player.pause()).called(1);
    verify(() => player.seek(const Duration(seconds: 12))).called(1);
    expect(handler.playbackState.value.playing, isFalse);
  });
  test('media controls reflect player state and elapsed position', () async {
    states.add(PlayerState.playing);
    positions.add(const Duration(seconds: 25));
    expect(handler.playbackState.value.playing, isTrue);
    expect(
      handler.playbackState.value.updatePosition,
      const Duration(seconds: 25),
    );
    expect(handler.playbackState.value.controls, contains(MediaControl.pause));
    states.add(PlayerState.paused);
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.controls, contains(MediaControl.play));
    states.add(PlayerState.stopped);
    expect(handler.playbackState.value.playing, isFalse);
    states.add(PlayerState.completed);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.completed,
    );
    states.add(PlayerState.disposed);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });

  test(
    'resume and stop publish consistent state for system controls',
    () async {
      await handler.play();
      expect(handler.playbackState.value.playing, isTrue);
      verify(() => player.resume()).called(1);
      await handler.seek(const Duration(seconds: 13));
      expect(
        handler.playbackState.value.updatePosition,
        const Duration(seconds: 13),
      );
      await handler.stop();
      expect(handler.playbackState.value.playing, isFalse);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      expect(handler.playbackState.value.updatePosition, Duration.zero);
      verify(() => player.stop()).called(1);
    },
  );

  test(
    'system next and previous actions invoke the installed queue handlers',
    () async {
      var selected = 1;
      handler.onSkipNext = () async {
        selected++;
      };
      handler.onSkipPrevious = () async {
        selected--;
      };
      await handler.skipToNext();
      expect(selected, 2);
      await handler.skipToPrevious();
      expect(selected, 1);
      handler.onSkipNext = null;
      handler.onSkipPrevious = null;
      await handler.skipToNext();
      await handler.skipToPrevious();
      expect(selected, 1);
    },
  );

  test(
    'completion clears the playing flag and disposed handlers ignore events',
    () async {
      await handler.play();
      completions.add(null);
      expect(handler.playbackState.value.playing, isFalse);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.completed,
      );
      await handler.dispose();
      final completed = handler.playbackState.value;
      states.add(PlayerState.playing);
      positions.add(const Duration(seconds: 40));
      expect(handler.playbackState.value, same(completed));
    },
  );

  test('a delayed stop cannot start an obsolete selected source', () async {
    final firstStop = Completer<void>();
    var stops = 0;
    when(
      () => player.stop(),
    ).thenAnswer((_) => ++stops == 1 ? firstStop.future : Future<void>.value());
    final first = handler.playMediaItem(
      const MediaItem(id: 'https://example.test/old.mp3', title: 'Old'),
    );
    await Future<void>.delayed(Duration.zero);
    final latest = handler.playMediaItem(
      const MediaItem(id: 'https://example.test/new.mp3', title: 'New'),
    );
    await Future<void>.delayed(Duration.zero);
    firstStop.complete();
    await Future.wait([first, latest]);
    final played = verify(
      () => player.play(captureAny<Source>()),
    ).captured.cast<UrlSource>().map((source) => source.url);
    expect(played, ['https://example.test/new.mp3']);
    expect(handler.mediaItem.value?.title, 'New');
    expect(handler.playbackState.value.playing, isTrue);
  });

  test('a delayed old play cannot replace the latest audible source', () async {
    final firstPlay = Completer<void>();
    String? audibleSource;
    when(() => player.play(any<Source>())).thenAnswer((invocation) async {
      final source = invocation.positionalArguments.first as UrlSource;
      if (source.url.endsWith('/old.mp3')) await firstPlay.future;
      audibleSource = source.url;
    });
    final first = handler.playMediaItem(
      const MediaItem(id: 'https://example.test/old.mp3', title: 'Old'),
    );
    await Future<void>.delayed(Duration.zero);
    final latest = handler.playMediaItem(
      const MediaItem(id: 'https://example.test/new.mp3', title: 'New'),
    );
    await Future<void>.delayed(Duration.zero);
    firstPlay.complete();
    await Future.wait([first, latest]);
    expect(audibleSource, 'https://example.test/new.mp3');
    expect(handler.mediaItem.value?.title, 'New');
  });

  test('stop while a selection is preparing prevents later autoplay', () async {
    final firstStop = Completer<void>();
    var stops = 0;
    when(
      () => player.stop(),
    ).thenAnswer((_) => ++stops == 1 ? firstStop.future : Future<void>.value());
    final loading = handler.playMediaItem(
      const MediaItem(id: 'https://example.test/old.mp3', title: 'Old'),
    );
    await Future<void>.delayed(Duration.zero);
    final stopping = handler.stop();
    firstStop.complete();
    await Future.wait([loading, stopping]);
    verifyNever(() => player.play(any<Source>()));
    expect(handler.playbackState.value.playing, isFalse);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });

  test(
    'a failed audio operation does not prevent the next selection',
    () async {
      when(() => player.play(any<Source>())).thenThrow(StateError('Failed'));
      await expectLater(
        handler.playMediaItem(
          const MediaItem(id: 'https://example.test/old.mp3', title: 'Old'),
        ),
        throwsStateError,
      );
      when(() => player.play(any<Source>())).thenAnswer((_) async {});
      await handler.playMediaItem(
        const MediaItem(id: 'https://example.test/new.mp3', title: 'New'),
      );
      expect(handler.mediaItem.value?.title, 'New');
      expect(handler.playbackState.value.playing, isTrue);
    },
  );

  test(
    'disposing while a source prepares prevents any later audio start',
    () async {
      final stopping = Completer<void>();
      when(() => player.stop()).thenAnswer((_) => stopping.future);
      final loading = handler.playMediaItem(
        const MediaItem(id: 'https://example.test/old.mp3', title: 'Old'),
      );
      await Future<void>.delayed(Duration.zero);
      await handler.dispose();
      stopping.complete();
      await loading;
      verifyNever(() => player.play(any<Source>()));
    },
  );
}
