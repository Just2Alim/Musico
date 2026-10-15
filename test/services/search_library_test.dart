import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/data/local_music_cache.dart';
import 'package:musico_app/data/music_repository.dart';
import 'package:musico_app/features/player/playback_cubit.dart';
import 'package:musico_app/providers/music_data_provider.dart';
import 'package:musico_app/services/library_screen.dart';
import 'package:musico_app/services/search_screen.dart';
import 'package:provider/provider.dart';

class _Playback extends Cubit<PlaybackState> implements PlaybackCubit {
  _Playback()
    : super(
        const PlaybackState(
          currentTrack: null,
          isPlaying: false,
          isLoading: false,
          position: Duration.zero,
          duration: Duration.zero,
          errorMessage: '',
          repeatEnabled: false,
          shuffleEnabled: false,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Music extends MusicDataProvider {
  _Music()
    : super(MusicRepository(null), LocalMusicCache(), backendEnabled: false);

  final requests = <String, Completer<Map<String, dynamic>>>{};
  final created = <String>[];
  int libraryLoads = 0;
  List<Playlist> items = [];
  List<Map<String, dynamic>> favorites = [];
  String? userId = 'user-a';

  @override
  String? get currentUserId => userId;

  void switchUser(String? id) {
    userId = id;
    notifyListeners();
  }

  @override
  List<Map<String, dynamic>> get favoriteTracks => favorites;
  @override
  Future<void> toggleFavorite(int trackId) async {
    favorites = favorites.any((track) => track['id'] == trackId)
        ? favorites.where((track) => track['id'] != trackId).toList()
        : [
            ...favorites,
            {'id': trackId},
          ];
    notifyListeners();
  }

  @override
  bool get isSignedIn => userId != null;
  @override
  List<Playlist> get userPlaylists => items;
  @override
  Future<void> loadUserPlaylists() async {
    libraryLoads++;
  }

  @override
  Future<void> loadFavoriteTracks() async {}
  @override
  Future<void> loadRecentlyPlayed() async {}
  @override
  Future<Map<String, dynamic>> searchMusic(String query) {
    final completer = Completer<Map<String, dynamic>>();
    requests[query] = completer;
    return completer.future;
  }

  @override
  Future<bool> createPlaylist(
    String name, {
    String? subtitle,
    String? imageUrl,
  }) async {
    created.add(name);
    items = [Playlist(id: 1, name: name, trackCount: 0, userId: 'user')];
    notifyListeners();
    return true;
  }
}

Map<String, dynamic> _results(String name) => {
  'tracks': [
    {'id': 1, 'name': name, 'artist': 'Artist'},
  ],
  'artists': ['Artist'],
  'playlists': [],
};

Future<void> _mount(WidgetTester tester, _Music music, Widget screen) async {
  final playback = _Playback();
  addTearDown(playback.close);
  addTearDown(music.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<MusicDataProvider>.value(
      value: music,
      child: BlocProvider<PlaybackCubit>.value(
        value: playback,
        child: MaterialApp(home: screen),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final nextUser in <String?>['user-b', null]) {
    testWidgets(
      'retained search clears private playlists on identity change to $nextUser',
      (tester) async {
        final music = _Music();
        final branch = ValueNotifier<int>(0);
        addTearDown(branch.dispose);
        await _mount(
          tester,
          music,
          ValueListenableBuilder<int>(
            valueListenable: branch,
            builder: (_, index, child) => IndexedStack(
              index: index,
              children: [child!, const SizedBox.shrink()],
            ),
            child: const SearchScreen(),
          ),
        );
        await tester.enterText(find.byType(TextField), 'private');
        await tester.pump(const Duration(milliseconds: 400));
        music.requests['private']!.complete({
          ..._results('Public track'),
          'playlists': [
            {'id': 42, 'name': 'Private user A playlist'},
          ],
        });
        await tester.pumpAndSettle();
        await tester.tap(find.text('Плейлисты'));
        await tester.pumpAndSettle();
        expect(find.text('Private user A playlist'), findsOneWidget);
        branch.value = 1;
        await tester.pump();
        music.switchUser(nextUser);
        await tester.pump();
        branch.value = 0;
        await tester.pumpAndSettle();
        expect(find.text('Private user A playlist'), findsNothing);
        expect(find.text('Обзор категорий'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      },
    );
  }

  testWidgets(
    'old identity search cannot populate a new account after completion',
    (tester) async {
      final music = _Music();
      await _mount(tester, music, const SearchScreen());
      await tester.enterText(find.byType(TextField), 'private');
      await tester.pump(const Duration(milliseconds: 400));
      music.switchUser('user-b');
      music.requests['private']!.complete({
        ..._results('Public track'),
        'playlists': [
          {'id': 42, 'name': 'Private user A playlist'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Обзор категорий'), findsOneWidget);
      expect(find.text('Playlists'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('clearing search cancels a pending debounce', (tester) async {
    final music = _Music();
    await _mount(tester, music, const SearchScreen());
    await tester.enterText(find.byType(TextField), 'jazz');
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 400));
    expect(music.requests, isEmpty);
    expect(find.text('Обзор категорий'), findsOneWidget);
  });

  testWidgets('old request cannot replace the results of a newer search', (
    tester,
  ) async {
    final music = _Music();
    await _mount(tester, music, const SearchScreen());
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 400));
    music.requests['new']!.complete(_results('New result'));
    await tester.pump();
    music.requests['old']!.complete(_results('Old result'));
    await tester.pump();
    expect(find.text('New result'), findsOneWidget);
    expect(find.text('Old result'), findsNothing);
  });

  testWidgets('shortening a running search hides stale results and spinner', (
    tester,
  ) async {
    final music = _Music();
    await _mount(tester, music, const SearchScreen());
    await tester.enterText(find.byType(TextField), 'jazz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'j');
    music.requests['jazz']!.complete(_results('Stale result'));
    await tester.pumpAndSettle();
    expect(find.text('Обзор категорий'), findsOneWidget);
    expect(find.text('Stale result'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'search removes an existing favorite without relying on row isLiked',
    (tester) async {
      final music = _Music()
        ..favorites = [
          {'id': 1},
        ];
      await _mount(tester, music, const SearchScreen());
      await tester.enterText(find.byType(TextField), 'song');
      await tester.pump(const Duration(milliseconds: 400));
      music.requests['song']!.complete(_results('Already liked'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();
      expect(music.favoriteTracks, isEmpty);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    },
  );

  testWidgets('library empty state creates a validated playlist', (
    tester,
  ) async {
    final music = _Music();
    await _mount(tester, music, const LibraryScreen());
    await tester.tap(find.text('Создать плейлист'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pump();
    expect(music.created, isEmpty);
    expect(find.text('Введите название'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  Evening  ');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(music.created, ['Evening']);
    expect(find.text('Evening'), findsOneWidget);
    expect(music.libraryLoads, 1);
  });
}
