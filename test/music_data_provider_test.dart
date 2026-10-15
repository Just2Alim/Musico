import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/data/local_music_cache.dart';
import 'package:musico_app/data/music_repository.dart';
import 'package:musico_app/providers/music_data_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepository extends MusicRepository {
  _FakeRepository()
    : super(SupabaseClient('https://example.test', 'public-test-key'));

  bool failTracks = false;
  bool failPlaylists = false;
  bool failPlaylistWrites = false;
  bool favorite = false;
  int nextPlaylistId = 101;
  final calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> tracks({
    String? query,
    int from = 0,
    int limit = 30,
  }) async {
    calls.add('tracks:$from:$query');
    if (failTracks) throw StateError('network');
    if (query != null)
      return [
        {'id': 9, 'artist': 'One'},
      ];
    return List.generate(from == 0 ? 30 : 1, (i) => {'id': from + i + 1});
  }

  @override
  Future<List<Map<String, dynamic>>> playlists({String? ownerId}) async {
    calls.add('playlists:$ownerId');
    if (failPlaylists) throw StateError('playlists unavailable');
    return [
      {'id': 1, 'name': 'Morning Mix', 'user_id': ownerId ?? 'featured'},
      {'id': 2, 'name': 'Night Set', 'user_id': ownerId ?? 'featured'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> recentlyPlayed({int limit = 10}) async => [
    {'id': 3, 'name': 'Recent'},
  ];

  @override
  Future<List<Map<String, dynamic>>> favoriteTracks() async => favorite
      ? [
          {'id': 4, 'name': 'Favorite'},
        ]
      : [];

  @override
  Future<bool> isFavorite(int trackId) async => favorite;

  @override
  Future<void> setFavorite(int trackId, bool value) async {
    favorite = value;
  }

  @override
  Future<int> createPlaylist(
    String name, {
    String? subtitle,
    String? imageUrl,
  }) async {
    if (failPlaylistWrites) throw StateError('write failed');
    return nextPlaylistId++;
  }

  @override
  Future<void> addTrack(int playlistId, int trackId) async {
    if (failPlaylistWrites) throw StateError('write failed');
  }

  @override
  Future<void> removeTrack(int playlistId, int trackId) async {}

  @override
  Future<void> deletePlaylist(int playlistId) async {}
}

class _FakeCache extends LocalMusicCache {
  List<Map<String, dynamic>> saved = [];

  @override
  List<Map<String, dynamic>> readTracks() => saved;

  @override
  Future<void> saveTracks(List<Map<String, dynamic>> tracks) async {
    saved = List.of(tracks);
  }
}

class _AuthClient extends Mock implements GoTrueClient {}

class _SupabaseClient extends Mock implements SupabaseClient {}

class _AuthRepository extends _FakeRepository {
  _AuthRepository(this.authClient);
  final SupabaseClient authClient;
  Completer<List<Map<String, dynamic>>>? pendingFavorites;
  Completer<List<Map<String, dynamic>>>? pendingPlaylists;
  Completer<void>? playlistsStarted;
  @override
  Future<List<Map<String, dynamic>>> playlists({String? ownerId}) {
    final pending = pendingPlaylists;
    pendingPlaylists = null;
    if (pending == null) return super.playlists(ownerId: ownerId);
    playlistsStarted?.complete();
    return pending.future;
  }

  @override
  SupabaseClient get client => authClient;
  @override
  Future<List<Map<String, dynamic>>> favoriteTracks() =>
      pendingFavorites?.future ?? super.favoriteTracks();
}

class _PrivateCache extends _FakeCache {
  final favoriteOwners = <String>[];
  @override
  Future<void> saveFavorites(
    String userId,
    List<Map<String, dynamic>> rows,
  ) async {
    favoriteOwners.add(userId);
  }

  @override
  Future<void> saveHistory(
    String userId,
    List<Map<String, dynamic>> rows,
  ) async {}
}

void main() {
  for (final nextUser in <String?>['user-b', null]) {
    test(
      'pending search drops previous identity private playlists on switch to $nextUser',
      () async {
        final auth = _AuthClient();
        final client = _SupabaseClient();
        final events = StreamController<AuthState>(sync: true);
        User? user = const User(
          id: 'user-a',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '',
        );
        when(() => client.auth).thenReturn(auth);
        when(() => auth.currentUser).thenAnswer((_) => user);
        when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
        final pending = Completer<List<Map<String, dynamic>>>();
        final started = Completer<void>();
        final repository = _AuthRepository(client)
          ..pendingPlaylists = pending
          ..playlistsStarted = started;
        final provider = MusicDataProvider(
          repository,
          _PrivateCache(),
          backendEnabled: true,
        );
        addTearDown(provider.dispose);
        addTearDown(events.close);
        final request = provider.searchMusic('private');
        await started.future;
        user = nextUser == null
            ? null
            : User(
                id: nextUser,
                appMetadata: {},
                userMetadata: {},
                aud: 'authenticated',
                createdAt: '',
              );
        final session = user == null
            ? null
            : Session(
                accessToken: 'test-token',
                tokenType: 'bearer',
                user: user,
              );
        events.add(
          AuthState(
            user == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
            session,
          ),
        );
        pending.complete([
          {'id': 42, 'name': 'Private user A playlist', 'user_id': 'user-a'},
        ]);
        final result = await request;
        expect(result['playlists'], isEmpty);
        expect(result['tracks'], hasLength(1));
        expect(result['artists'], ['One']);
      },
    );
  }

  test(
    'auth changes clear private data and ignore an old user request',
    () async {
      final auth = _AuthClient();
      final client = _SupabaseClient();
      final events = StreamController<AuthState>(sync: true);
      User? user = const User(
        id: 'user-a',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '',
      );
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenAnswer((_) => user);
      when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
      final repository = _AuthRepository(client)..favorite = true;
      final cache = _PrivateCache();
      final provider = MusicDataProvider(
        repository,
        cache,
        backendEnabled: true,
      );
      await provider.loadAllData();
      expect(provider.userPlaylists, isNotEmpty);
      expect(provider.favoriteTracks, isNotEmpty);
      expect(provider.recentlyPlayed, isNotEmpty);

      final pending = Completer<List<Map<String, dynamic>>>();
      repository.pendingFavorites = pending;
      final request = provider.loadFavoriteTracks();
      user = null;
      events.add(const AuthState(AuthChangeEvent.signedOut, null));
      expect(provider.userPlaylists, isEmpty);
      expect(provider.favoriteTracks, isEmpty);
      expect(provider.recentlyPlayed, isEmpty);
      expect(provider.tracks, isNotEmpty);
      pending.complete([
        {'id': 99, 'name': 'Old private track'},
      ]);
      await request;
      expect(provider.favoriteTracks, isEmpty);
      expect(cache.favoriteOwners, ['user-a']);

      repository.pendingFavorites = null;
      user = const User(
        id: 'user-b',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '',
      );
      events.add(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(accessToken: 'test-token', tokenType: 'bearer', user: user),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        provider.userPlaylists.every((playlist) => playlist.userId == 'user-b'),
        isTrue,
      );
      expect(provider.userPlaylists, isNotEmpty);
      expect(cache.favoriteOwners, ['user-a', 'user-b']);
      provider.dispose();
      expect(events.hasListener, isFalse);
      await events.close();
    },
  );

  test(
    'loads subsequent catalog pages and persists the combined cache',
    () async {
      final cache = _FakeCache();
      final provider = MusicDataProvider(
        _FakeRepository(),
        cache,
        backendEnabled: true,
      );

      await provider.loadAllData();
      expect(provider.tracks, hasLength(30));
      expect(provider.hasMoreTracks, isTrue);

      await provider.loadMoreTracks();
      expect(provider.tracks, hasLength(31));
      expect(provider.hasMoreTracks, isFalse);
      expect(cache.saved, hasLength(31));
    },
  );

  test(
    'shows cached tracks without contacting Supabase when offline',
    () async {
      final cache = _FakeCache()
        ..saved = [
          {'id': 7, 'name': 'Cached Track'},
        ];
      final provider = MusicDataProvider(
        _FakeRepository(),
        cache,
        backendEnabled: false,
      );

      await provider.loadAllData();

      expect(provider.tracks.single['name'], 'Cached Track');
      expect(provider.errorMessage, contains('Офлайн'));
      expect(provider.isLoading, isFalse);
    },
  );

  test('maps playlist JSON while accepting the legacy camelCase fields', () {
    final playlist = Playlist.fromJson({
      'id': 8,
      'name': 'Late Night',
      'imageUrl': 'cover.png',
      'trackCount': 12,
      'userId': 'u-1',
    });

    expect(playlist.id, 8);
    expect(playlist.imageUrl, 'cover.png');
    expect(playlist.trackCount, 12);
    expect(playlist.userId, 'u-1');
    expect(playlist.toJson()['track_count'], 12);
    expect(playlist.toJson()['user_id'], 'u-1');
  });

  test(
    'loads featured, history, and favorites into observable state',
    () async {
      final provider = MusicDataProvider(
        _FakeRepository(),
        _FakeCache(),
        backendEnabled: true,
      );

      await provider.loadFeaturedPlaylists();
      await provider.loadRecentlyPlayed();
      await provider.loadFavoriteTracks();

      expect(provider.featuredPlaylists, hasLength(2));
      expect(provider.recentlyPlayed.single['name'], 'Recent');
      expect(provider.favoriteTracks, isEmpty);
    },
  );

  test(
    'searches tracks and filters playlist names case-insensitively',
    () async {
      final provider = MusicDataProvider(
        _FakeRepository(),
        _FakeCache(),
        backendEnabled: true,
      );

      final result = await provider.searchMusic(' morning ');

      expect(result['tracks'], hasLength(1));
      expect((result['playlists'] as List), hasLength(1));
      expect(result['artists'], ['One']);
      expect(provider.isLoading, isFalse);
    },
  );

  test(
    'failed search preserves the result contract and searches cached tracks',
    () async {
      final repository = _FakeRepository()..failTracks = true;
      final cache = _FakeCache()
        ..saved = [
          {
            'id': 1,
            'name': 'Cached Song',
            'artist': 'Local Artist',
            'genre': 'Jazz',
          },
          {'id': 2, 'name': 'Other Song', 'artist': 'Other Artist'},
        ];
      final provider = MusicDataProvider(
        repository,
        cache,
        backendEnabled: true,
      );

      final result = await provider.searchMusic('jazz');

      expect((result['tracks'] as List).single['id'], 1);
      expect(result['playlists'], isEmpty);
      expect(result['artists'], ['Local Artist']);
      expect(provider.errorMessage, contains('Офлайн'));
      expect(provider.isLoading, isFalse);
    },
  );

  test('playlist failure does not hide matching public tracks', () async {
    final repository = _FakeRepository()..failPlaylists = true;
    final provider = MusicDataProvider(
      repository,
      _FakeCache(),
      backendEnabled: true,
    );

    final result = await provider.searchMusic('song');

    expect(result['tracks'], hasLength(1));
    expect(result['playlists'], isEmpty);
    expect(result['artists'], ['One']);
  });

  test(
    'offline search avoids network and always returns list fields',
    () async {
      final repository = _FakeRepository();
      final provider = MusicDataProvider(
        repository,
        _FakeCache(),
        backendEnabled: false,
      );

      final result = await provider.searchMusic('missing');

      expect(result, {'tracks': [], 'playlists': [], 'artists': []});
      expect(repository.calls, isEmpty);
    },
  );

  test('toggles favorite and reports playlist write failures', () async {
    final repository = _FakeRepository();
    final provider = MusicDataProvider(
      repository,
      _FakeCache(),
      backendEnabled: true,
    );

    await provider.toggleFavorite(4);
    expect(provider.favoriteTracks.single['name'], 'Favorite');

    repository.failPlaylistWrites = true;
    expect(await provider.createPlaylist('New list'), isFalse);
    expect(provider.errorMessage, contains('создать плейлист'));
    expect(provider.isLoading, isFalse);
    expect(await provider.addTrackToPlaylist(1, 2), isFalse);
    expect(await provider.createPlaylistWithTrack('Broken', 2), isNull);
  });

  test('loads catalog from cache when the backend request fails', () async {
    final repository = _FakeRepository()..failTracks = true;
    final cache = _FakeCache()
      ..saved = [
        {'id': 22, 'name': 'Saved'},
      ];
    final provider = MusicDataProvider(repository, cache, backendEnabled: true);

    await provider.loadAllData();

    expect(provider.tracks.single['name'], 'Saved');
    expect(provider.errorMessage, isEmpty);
    expect(provider.isLoading, isFalse);
  });

  test(
    'supports playlist mutations and prevents duplicate page requests',
    () async {
      final repository = _FakeRepository();
      final provider = MusicDataProvider(
        repository,
        _FakeCache(),
        backendEnabled: true,
      );

      await provider.loadAllData();
      expect(await provider.addTrackToPlaylist(1, 8), isTrue);
      expect(await provider.removeTrackFromPlaylist(1, 8), isTrue);
      expect(await provider.deletePlaylist(1), isTrue);
      await provider.loadMoreTracks();
      expect(provider.tracks, hasLength(31));
      expect(provider.hasMoreTracks, isFalse);
      final before = repository.calls.length;
      await provider.loadMoreTracks();
      expect(repository.calls.length, before);
    },
  );
}
