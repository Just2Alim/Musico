import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musico_app/data/music_repository.dart';
import 'package:musico_app/features/player/playback_cubit.dart';
import 'package:musico_app/providers/audio_player_provider.dart';
import 'package:musico_app/services/player_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _track = Track(
  id: 2,
  name: 'Moonlight Beach',
  artist: 'Kevin MacLeod',
  genre: 'Electronic',
  duration: 339,
  audioFileUrl:
      'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Moonlight%20Beach.mp3',
);

class _Playback extends Cubit<PlaybackState> implements PlaybackCubit {
  _Playback({Track? track = _track, bool loading = false, String error = ''})
    : super(
        PlaybackState(
          currentTrack: track,
          isPlaying: false,
          isLoading: loading,
          position: const Duration(seconds: 30),
          duration: const Duration(seconds: 339),
          errorMessage: error,
          repeatEnabled: false,
          shuffleEnabled: false,
        ),
      );
  final commands = <String>[];
  Duration? seekPosition;
  @override
  Future<void> loadTrackById(int id) async {
    commands.add('load:$id');
  }

  @override
  Future<void> seekTo(Duration position) async {
    seekPosition = position;
  }

  @override
  Future<void> playPrevious() async {
    commands.add('previous');
  }

  @override
  Future<void> playNext() async {
    commands.add('next');
  }

  @override
  Future<void> togglePlayPause() async {
    commands.add('play-pause');
    _update(playing: !state.isPlaying);
  }

  @override
  void toggleShuffle() {
    commands.add('shuffle');
    _update(shuffle: !state.shuffleEnabled);
  }

  @override
  void toggleRepeat() {
    commands.add('repeat');
    _update(repeat: !state.repeatEnabled);
  }

  void _update({bool? playing, bool? repeat, bool? shuffle}) => emit(
    PlaybackState(
      currentTrack: state.currentTrack,
      isPlaying: playing ?? state.isPlaying,
      isLoading: state.isLoading,
      position: state.position,
      duration: state.duration,
      errorMessage: state.errorMessage,
      repeatEnabled: repeat ?? state.repeatEnabled,
      shuffleEnabled: shuffle ?? state.shuffleEnabled,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Audio extends ChangeNotifier implements AudioPlayerAlternativeProvider {
  final queued = <Track>[];
  int favoriteCalls = 0;
  String favoriteError = '';
  @override
  String get errorMessage => favoriteError;
  @override
  Future<void> toggleFavorite() async {
    favoriteCalls++;
  }

  @override
  void addToQueue(Track track) {
    queued.add(track);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends MusicRepository {
  _Repository() : super(null);
  List<Map<String, dynamic>> rows = [
    {'id': 11, 'name': 'Evening', 'trackCount': 3},
  ];
  final additions = <String>[];
  final creations = <String>[];
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<List<Map<String, dynamic>>> playlists({String? ownerId}) async {
    if (failRead) throw StateError('Unavailable');
    return rows;
  }

  @override
  Future<void> addTrack(int playlistId, int trackId) async {
    if (failWrite) throw StateError('Unavailable');
    additions.add('$playlistId:$trackId');
  }

  @override
  Future<int> createPlaylist(
    String name, {
    String? subtitle,
    String? imageUrl,
  }) async {
    if (failWrite) throw StateError('Unavailable');
    creations.add(name);
    return 12;
  }
}

Future<void> _signedIn() => Supabase.instance.client.auth.setInitialSession(
  jsonEncode({
    'access_token':
        'header.${base64Url.encode(utf8.encode('{"exp":4102444800,"sub":"test-user"}')).replaceAll('=', '')}.signature',
    'token_type': 'bearer',
    'refresh_token': 'test-refresh',
    'user': {
      'id': 'test-user',
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '',
    },
  }),
);

Future<void> _mount(
  WidgetTester tester, {
  _Playback? playback,
  _Audio? audio,
  _Repository? repository,
  Size size = const Size(448, 997),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final player = playback ?? _Playback();
  final engine = audio ?? _Audio();
  addTearDown(player.close);
  addTearDown(engine.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<MusicRepository>.value(value: repository ?? _Repository()),
        ChangeNotifierProvider<AudioPlayerAlternativeProvider>.value(
          value: engine,
        ),
        BlocProvider<PlaybackCubit>.value(value: player),
      ],
      child: const MaterialApp(home: PlayerScreen(arguments: {'trackId': 2})),
    ),
  );
  await tester.pump();
}

Future<void> _options(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

Future<void> _playlists(WidgetTester tester) async {
  await _options(tester);
  await tester.tap(find.text('Добавить в плейлист'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'public-test-key',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });
  tearDown(() async {
    await Supabase.instance.dispose();
  });

  for (final size in [const Size(448, 997), const Size(997, 448)]) {
    testWidgets('player handles absent artwork at $size', (tester) async {
      await _mount(tester, size: size);
      await tester.pumpAndSettle();
      expect(find.text('Moonlight Beach'), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'controls dispatch playback, navigation, repeat, shuffle and seek',
    (tester) async {
      final playback = _Playback();
      await _mount(tester, playback: playback);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause));
      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();
      expect(playback.state.shuffleEnabled, isTrue);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      expect(playback.state.repeatEnabled, isTrue);
      await tester.drag(find.byType(Slider), const Offset(45, 0));
      await tester.pump();
      expect(playback.seekPosition, isNotNull);
      expect(playback.commands, [
        'load:2',
        'play-pause',
        'play-pause',
        'previous',
        'next',
        'shuffle',
        'repeat',
      ]);
    },
  );

  testWidgets(
    'loading state prevents playback and unavailable track can retry',
    (tester) async {
      final loading = _Playback(loading: true);
      await _mount(tester, playback: loading);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      final failed = _Playback(track: null, error: 'Трек недоступен');
      await _mount(tester, playback: failed);
      expect(find.text('Трек недоступен'), findsOneWidget);
      await tester.tap(find.text('Повторить'));
      expect(
        failed.commands.where((command) => command == 'load:2').length,
        greaterThanOrEqualTo(1),
      );
    },
  );

  testWidgets('empty track shows loading instead of broken player controls', (
    tester,
  ) async {
    await _mount(tester, playback: _Playback(track: null));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('credits show the verified recording attribution and license', (
    tester,
  ) async {
    await _mount(tester);
    await _options(tester);
    await tester.tap(find.text('Авторство и лицензия'));
    await tester.pumpAndSettle();
    expect(
      find.text('Creative Commons Attribution 4.0 (CC BY 4.0)'),
      findsOneWidget,
    );
    expect(find.textContaining('isrc=USUAN2000005'), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Опции трека'), findsOneWidget);
  });

  testWidgets('track information displays duration genre and ID', (
    tester,
  ) async {
    await _mount(tester);
    await _options(tester);
    await tester.tap(find.text('Информация о треке'));
    await tester.pumpAndSettle();
    expect(find.text('Electronic'), findsOneWidget);
    expect(find.text('ID трека: '), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('05:39'), findsWidgets);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('queue option dispatches the selected track', (tester) async {
    final audio = _Audio();
    await _mount(tester, audio: audio);
    await _options(tester);
    await tester.tap(find.text('В очередь воспроизведения'));
    await tester.pumpAndSettle();
    expect(audio.queued.single.id, 2);
    expect(
      find.text('Трек добавлен в очередь воспроизведения'),
      findsOneWidget,
    );
  });

  testWidgets('favorite errors stay visible for guest actions', (tester) async {
    final audio = _Audio()
      ..favoriteError = 'Войдите, чтобы добавить в избранное';
    await _mount(tester, audio: audio);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(audio.favoriteCalls, 1);
    expect(find.text(audio.favoriteError), findsOneWidget);
  });

  testWidgets('favorite option updates the engine and closes sheet', (
    tester,
  ) async {
    final audio = _Audio();
    await _mount(tester, audio: audio);
    await _options(tester);
    await tester.tap(find.text('Добавить в избранное'));
    await tester.pumpAndSettle();
    expect(audio.favoriteCalls, 1);
    expect(find.text('Опции трека'), findsNothing);
  });

  testWidgets('guest gets sign-in guidance instead of playlist mutations', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository: repository);
    await _playlists(tester);
    expect(
      find.text('Войдите, чтобы добавлять треки в плейлисты.'),
      findsOneWidget,
    );
    expect(repository.additions, isEmpty);
    expect(find.text('Создать новый плейлист'), findsNothing);
  });

  testWidgets('signed-in user chooses a playlist and sees saved confirmation', (
    tester,
  ) async {
    await _signedIn();
    final repository = _Repository();
    await _mount(tester, repository: repository);
    await _playlists(tester);
    expect(find.text('Evening'), findsOneWidget);
    await tester.tap(find.text('Evening'));
    await tester.pumpAndSettle();
    expect(repository.additions, ['11:2']);
    expect(find.text('Трек добавлен в плейлист'), findsOneWidget);
  });

  testWidgets(
    'empty library supports creating a playlist with the current track',
    (tester) async {
      await _signedIn();
      final repository = _Repository()..rows = [];
      await _mount(tester, repository: repository);
      await _playlists(tester);
      expect(find.text('У вас пока нет плейлистов'), findsOneWidget);
      await tester.tap(find.text('Создать новый плейлист'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Fresh mix  ');
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(repository.creations, ['Fresh mix']);
      expect(repository.additions, ['12:2']);
      expect(
        find.text('Плейлист "Fresh mix" создан и трек добавлен'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'playlist write failure is reported and keeps selection available',
    (tester) async {
      await _signedIn();
      final repository = _Repository()..failWrite = true;
      await _mount(tester, repository: repository);
      await _playlists(tester);
      await tester.tap(find.text('Evening'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Произошла ошибка:'), findsOneWidget);
      expect(repository.additions, isEmpty);
      expect(find.text('Evening'), findsOneWidget);
    },
  );
}
