import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musico_app/data/music_repository.dart';
import 'package:musico_app/providers/music_data_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'e542b2e4-6cc0-42cc-a635-3b5c2f554af0';
const _track = <String, dynamic>{
  'id': 7,
  'name': 'Summer Day',
  'artist': 'Kevin MacLeod',
  'duration': 198,
  'cover_image_url': 'https://example.test/cover.jpg',
  'audio_file_url': 'https://example.test/audio.mp3',
};

http.Response _json(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

String _testToken() {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': _userId, 'exp': 4102444800, 'role': 'authenticated'})}.test';
}

void main() {
  late SupabaseClient client;
  late MusicRepository repository;
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'listener@example.test',
      password: 'local-fixture-password',
    );
  }

  setUp(() {
    requests = [];
    respond = (_) => _json([]);
    final transport = MockClient((request) async {
      if (request.url.path == '/auth/v1/token') {
        return _json({
          'access_token': _testToken(),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'local-fixture-refresh-token',
          'user': {
            'id': _userId,
            'aud': 'authenticated',
            'email': 'listener@example.test',
            'app_metadata': {'provider': 'email'},
            'user_metadata': {'display_name': 'Listener'},
            'created_at': '2026-10-15T00:00:00Z',
          },
        });
      }
      requests.add(request);
      final response = respond(request);
      // PostgREST inspects the originating HTTP method and Accept header.
      // A real Client populates response.request; MockClient does not.
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
        reasonPhrase: response.reasonPhrase,
      );
    });
    client = SupabaseClient(
      'https://project.example.test',
      'test-publishable-key',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = MusicRepository(client, httpClient: transport);
  });

  tearDown(() async => client.dispose());

  test(
    'REST catalog uses the signed-in session while retaining the project key',
    () async {
      await signIn();
      late http.Request captured;
      final restRepository = MusicRepository(
        client,
        supabaseUrl: 'https://project.example.test',
        publishableKey: 'test-publishable-key',
        httpClient: MockClient((request) async {
          captured = request;
          return _json([_track]);
        }),
      );
      final rows = await restRepository.tracks();
      expect(captured.headers['authorization'], 'Bearer ${_testToken()}');
      expect(captured.headers['apikey'], 'test-publishable-key');
      expect(rows.single['audioFileUrl'], 'https://example.test/audio.mp3');
    },
  );

  test(
    'guest reads private collections as empty without issuing requests',
    () async {
      expect(await repository.notifications(), isEmpty);
      expect(await repository.favoriteTracks(), isEmpty);
      expect(await repository.recentlyPlayed(), isEmpty);
      expect(await repository.isFavorite(7), isFalse);
      await repository.recordListening(7, completed: true);
      expect(requests, isEmpty);
    },
  );

  test('guest mutations reject before reaching the database', () async {
    await expectLater(
      repository.createPlaylist('Mix'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      repository.markNotificationRead(1),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      repository.setFavorite(7, true),
      throwsA(isA<AuthException>()),
    );
    expect(
      () => repository.subscribeToNotifications(() {}),
      throwsA(isA<AuthException>()),
    );
    expect(requests, isEmpty);
  });

  test(
    'SDK catalog queries preserve pagination, search and normalized media',
    () async {
      respond = (_) => _json([_track]);
      final rows = await repository.tracks(
        query: ' Summer, Day ',
        from: 10,
        limit: 5,
      );
      final request = requests.single;
      expect(request.url.path, '/rest/v1/tracks');
      expect(
        request.url.queryParameters['or'],
        '(name.ilike.%Summer Day%,artist.ilike.%Summer Day%)',
      );
      expect(request.url.queryParameters['offset'], '10');
      expect(request.url.queryParameters['limit'], '5');
      expect(
        request.url.queryParameters['order'],
        startsWith('created_at.desc'),
      );
      expect(rows.single['id'], 7);
      expect(rows.single['coverImageUrl'], 'https://example.test/cover.jpg');
      expect(rows.single['audioFileUrl'], 'https://example.test/audio.mp3');
    },
  );

  test('SDK track lookup handles present, absent and invalid IDs', () async {
    respond = (_) => _json([_track]);
    final row = await repository.track(7);
    expect(row?['audioFileUrl'], 'https://example.test/audio.mp3');
    expect(requests.single.url.queryParameters['id'], 'eq.7');
    respond = (_) => _json([]);
    expect(await repository.track(8), isNull);
    final count = requests.length;
    expect(await repository.track(0), isNull);
    expect(await repository.track(-1), isNull);
    expect(requests.length, count);
  });

  test('venue response maps location and website for the map', () async {
    respond = (_) => _json([
      {
        'id': 2,
        'name': 'Concert Hall',
        'address': 'Almaty',
        'description': 'Live music',
        'latitude': 43.25,
        'longitude': 76.95,
        'website_url': 'https://example.test/hall',
      },
    ]);
    final venues = await repository.fetchVenues();
    expect(requests.single.url.path, '/rest/v1/venues');
    expect(
      requests.single.url.queryParameters['order'],
      startsWith('name.asc'),
    );
    expect(venues.single.name, 'Concert Hall');
    expect(venues.single.latitude, 43.25);
    expect(venues.single.longitude, 76.95);
    expect(venues.single.websiteUrl, 'https://example.test/hall');
  });

  test(
    'notification reads and updates stay scoped to the current user',
    () async {
      await signIn();
      respond = (_) => _json([
        {'id': 6, 'title': 'New music', 'user_id': _userId},
      ]);
      expect((await repository.notifications()).single['title'], 'New music');
      final read = requests.single;
      expect(read.url.path, '/rest/v1/notifications');
      expect(read.url.queryParameters['user_id'], 'eq.$_userId');
      expect(read.url.queryParameters['order'], startsWith('created_at.desc'));
      respond = (_) => http.Response('', 204);
      final before = DateTime.now().toUtc();
      await repository.markNotificationRead(6);
      final update = requests.last;
      expect(update.method, 'PATCH');
      expect(update.url.queryParameters['id'], 'eq.6');
      expect(update.url.queryParameters['user_id'], 'eq.$_userId');
      final timestamp = DateTime.parse(
        jsonDecode(update.body)['read_at'] as String,
      );
      expect(timestamp.isUtc, isTrue);
      expect(timestamp.isBefore(before), isFalse);
      expect(timestamp.isAfter(DateTime.now().toUtc()), isFalse);
    },
  );

  test(
    'playlist listing optionally filters by owner and supports missing IDs',
    () async {
      respond = (_) => _json([
        {'id': 4, 'name': 'Mix', 'user_id': _userId},
      ]);
      expect((await repository.playlists()).single['name'], 'Mix');
      expect(requests.last.url.queryParameters.containsKey('user_id'), isFalse);
      await repository.playlists(ownerId: _userId);
      expect(requests.last.url.queryParameters['user_id'], 'eq.$_userId');
      expect((await repository.playlist(4))?['name'], 'Mix');
      expect(requests.last.url.queryParameters['id'], 'eq.4');
      expect(requests.last.url.queryParameters['limit'], '1');
      respond = (_) => _json([]);
      expect(await repository.playlist(404), isNull);
    },
  );

  test(
    'playlist tracks request ordering and unwrap nested track media',
    () async {
      respond = (_) => _json([
        {'position': 0, 'tracks': _track},
      ]);
      final rows = await repository.playlistTracks(4);
      final request = requests.single;
      expect(request.url.path, '/rest/v1/playlist_tracks');
      expect(request.url.queryParameters['playlist_id'], 'eq.4');
      expect(request.url.queryParameters['order'], startsWith('position.asc'));
      expect(request.url.queryParameters['select'], 'position,tracks(*)');
      expect(rows.single['name'], 'Summer Day');
      expect(rows.single['coverImageUrl'], 'https://example.test/cover.jpg');
    },
  );

  test(
    'playlist list exposes embedded track count to library models',
    () async {
      respond = (_) => _json([
        {
          'id': 4,
          'name': 'Online mix',
          'user_id': _userId,
          'playlist_tracks': [
            {'count': 3},
          ],
        },
        {
          'id': 5,
          'name': 'Empty mix',
          'user_id': _userId,
          'playlist_tracks': [
            {'count': 0},
          ],
        },
      ]);
      final rows = await repository.playlists(ownerId: _userId);
      expect(Playlist.fromJson(rows.first).trackCount, 3);
      expect(Playlist.fromJson(rows.last).trackCount, 0);
      expect(
        requests.single.url.queryParameters['select'],
        '*,playlist_tracks(count)',
      );
    },
  );

  test('playlist detail carries the same normalized track count', () async {
    respond = (_) => _json([
      {
        'id': 4,
        'name': 'Online mix',
        'playlist_tracks': [
          {'count': 1},
        ],
      },
    ]);
    final row = await repository.playlist(4);
    expect(row?['track_count'], 1);
    expect(
      requests.single.url.queryParameters['select'],
      '*,playlist_tracks(count)',
    );
  });

  test(
    'createPlaylist writes the current owner and trimmed name and returns ID',
    () async {
      await signIn();
      respond = (_) => _json({'id': 12}, status: 201);
      final id = await repository.createPlaylist(
        '  My mix  ',
        subtitle: 'Evening',
        imageUrl: 'https://example.test/mix.jpg',
      );
      expect(id, 12);
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/playlists');
      expect(request.headers['authorization'], 'Bearer ${_testToken()}');
      expect(jsonDecode(request.body), {
        'user_id': _userId,
        'name': 'My mix',
        'subtitle': 'Evening',
        'image_url': 'https://example.test/mix.jpg',
      });
    },
  );

  test(
    'addTrack places a new track after the existing playlist entries',
    () async {
      respond = (request) => request.method == 'GET'
          ? _json([
              {'track_id': 1, 'position': 0},
              {'track_id': 2, 'position': 1},
            ])
          : http.Response('', 201);
      await repository.addTrack(4, 7);
      expect(requests.length, 2);
      expect(requests.first.url.queryParameters['playlist_id'], 'eq.4');
      expect(requests.last.method, 'POST');
      expect(
        requests.last.headers['prefer'],
        contains('resolution=merge-duplicates'),
      );
      expect(jsonDecode(requests.last.body), {
        'playlist_id': 4,
        'track_id': 7,
        'position': 2,
      });
    },
  );

  test('removeTrack restricts deletion to both playlist and track', () async {
    respond = (_) => http.Response('', 204);
    await repository.removeTrack(4, 7);
    final request = requests.single;
    expect(request.method, 'DELETE');
    expect(request.url.path, '/rest/v1/playlist_tracks');
    expect(request.url.queryParameters['playlist_id'], 'eq.4');
    expect(request.url.queryParameters['track_id'], 'eq.7');
  });

  test(
    'append uses the highest position after earlier entries were removed',
    () async {
      respond = (request) => request.method == 'GET'
          ? _json([
              {'track_id': 2, 'position': 5},
              {'track_id': 1, 'position': 0},
            ])
          : http.Response('', 201);
      await repository.addTrack(4, 7);
      expect(jsonDecode(requests.last.body)['position'], 6);
      expect(requests.first.url.queryParameters['select'], 'track_id,position');
    },
  );

  test('first playlist entry starts at position zero', () async {
    respond = (request) =>
        request.method == 'GET' ? _json([]) : http.Response('', 201);
    await repository.addTrack(4, 7);
    expect(jsonDecode(requests.last.body)['position'], 0);
  });

  test(
    'adding an existing playlist track does not silently reorder it',
    () async {
      respond = (request) => request.method == 'GET'
          ? _json([
              {'track_id': 7, 'position': 0},
              {'track_id': 9, 'position': 4},
            ])
          : http.Response('', 201);
      await repository.addTrack(4, 7);
      expect(requests.length, 1);
      expect(requests.single.method, 'GET');
    },
  );

  test('deletePlaylist targets only the requested playlist', () async {
    respond = (_) => http.Response('', 204);
    await repository.deletePlaylist(4);
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/rest/v1/playlists');
    expect(requests.single.url.queryParameters['id'], 'eq.4');
  });

  test(
    'favorite lookup returns the saved state and scopes query to user and track',
    () async {
      await signIn();
      respond = (_) => _json([
        {'track_id': 7},
      ]);
      expect(await repository.isFavorite(7), isTrue);
      final request = requests.single;
      expect(request.url.path, '/rest/v1/favorites');
      expect(request.url.queryParameters['user_id'], 'eq.$_userId');
      expect(request.url.queryParameters['track_id'], 'eq.7');
      expect(request.url.queryParameters['limit'], '1');
      respond = (_) => _json([]);
      expect(await repository.isFavorite(8), isFalse);
    },
  );

  test('favorite save and removal carry the authenticated owner', () async {
    await signIn();
    respond = (_) => http.Response('', 204);
    await repository.setFavorite(7, true);
    expect(requests.single.method, 'POST');
    expect(jsonDecode(requests.single.body), {
      'user_id': _userId,
      'track_id': 7,
    });
    await repository.setFavorite(7, false);
    expect(requests.last.method, 'DELETE');
    expect(requests.last.url.queryParameters['user_id'], 'eq.$_userId');
    expect(requests.last.url.queryParameters['track_id'], 'eq.7');
  });

  test(
    'listening history records completion and never accepts an owner parameter',
    () async {
      await signIn();
      respond = (_) => http.Response('', 201);
      await repository.recordListening(7, completed: false);
      expect(requests.single.url.path, '/rest/v1/listening_history');
      expect(jsonDecode(requests.single.body), {
        'user_id': _userId,
        'track_id': 7,
        'completed': false,
      });
      await repository.recordListening(7, completed: true);
      expect(jsonDecode(requests.last.body)['completed'], isTrue);
    },
  );

  test(
    'favorite collection unwraps join and marks returned tracks as liked',
    () async {
      await signIn();
      respond = (_) => _json([
        {'created_at': '2026-10-15', 'tracks': _track},
      ]);
      final rows = await repository.favoriteTracks();
      expect(requests.single.url.queryParameters['user_id'], 'eq.$_userId');
      expect(
        requests.single.url.queryParameters['order'],
        startsWith('created_at.desc'),
      );
      expect(rows.single['isLiked'], isTrue);
      expect(rows.single['audioFileUrl'], 'https://example.test/audio.mp3');
    },
  );

  test(
    'recent history applies user, newest-first ordering and requested limit',
    () async {
      await signIn();
      respond = (_) => _json([
        {'listened_at': '2026-10-15', 'tracks': _track},
      ]);
      final rows = await repository.recentlyPlayed(limit: 3);
      final request = requests.single;
      expect(request.url.queryParameters['user_id'], 'eq.$_userId');
      expect(
        request.url.queryParameters['order'],
        startsWith('listened_at.desc'),
      );
      expect(request.url.queryParameters['limit'], '3');
      expect(rows.single['id'], 7);
      expect(rows.single['coverImageUrl'], 'https://example.test/cover.jpg');
    },
  );

  test(
    'RLS denial propagates instead of reporting a successful playlist save',
    () async {
      await signIn();
      respond = (_) => _json({
        'code': '42501',
        'message': 'row-level security violation',
        'details': null,
        'hint': null,
      }, status: 403);
      await expectLater(
        repository.createPlaylist('Forbidden'),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.code,
            'code',
            '42501',
          ),
        ),
      );
    },
  );
}
