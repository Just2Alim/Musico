import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musico_app/data/music_repository.dart';
import 'package:musico_app/providers/audio_player_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Track JSON model', () {
    test('reads the Supabase track representation', () {
      final track = Track.fromJson({
        'id': 3,
        'name': 'Night Drive',
        'artist': 'Musico Artist',
        'genre': 'Electronic',
        'duration': 210,
        'cover_image_url': 'https://example.test/cover.jpg',
        'audio_file_url': 'https://example.test/audio.mp3',
        'isLiked': true,
      });

      expect(track.id, 3);
      expect(track.name, 'Night Drive');
      expect(track.artist, 'Musico Artist');
      expect(track.duration, 210);
      expect(track.coverImageUrl, 'https://example.test/cover.jpg');
      expect(track.audioFileUrl, 'https://example.test/audio.mp3');
      expect(track.isLiked, isTrue);
    });

    test('uses safe defaults for incomplete API data', () {
      final track = Track.fromJson({});
      expect(track.id, 0);
      expect(track.name, 'Unknown Track');
      expect(track.audioFileUrl, isEmpty);
      expect(track.isLiked, isFalse);
    });
  });

  test('fails clearly when a Supabase operation is requested offline', () {
    final repository = MusicRepository(null);
    expect(() => repository.client, throwsStateError);
  });

  test('loads and decodes a paginated catalog through Supabase REST', () async {
    late http.Request capturedRequest;
    final restClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode([
          {
            'id': 8,
            'name': 'Night Drive',
            'artist': 'Aster',
            'duration': 182,
            'cover_image_url': 'https://example.test/cover.jpg',
            'audio_file_url': 'https://example.test/audio.mp3',
          },
        ]),
        200,
      );
    });
    final repository = MusicRepository(
      null,
      supabaseUrl: 'https://project.supabase.co',
      publishableKey: 'sb_publishable_test_key',
      httpClient: restClient,
    );

    final tracks = await repository.tracks(
      query: 'Night Drive',
      from: 10,
      limit: 5,
    );

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/rest/v1/tracks');
    expect(capturedRequest.url.queryParameters['offset'], '10');
    expect(capturedRequest.url.queryParameters['limit'], '5');
    expect(capturedRequest.url.queryParameters['or'], contains('Night Drive'));
    expect(capturedRequest.headers['apikey'], 'sb_publishable_test_key');
    expect(tracks.single['name'], 'Night Drive');
    expect(tracks.single['coverImageUrl'], 'https://example.test/cover.jpg');
  });
  test(
    'looks up a track by ID without restricting it to the first page',
    () async {
      late http.Request captured;
      final repository = MusicRepository(
        null,
        supabaseUrl: 'https://project.supabase.co',
        publishableKey: 'sb_publishable_test_key',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode([
              {
                'id': 101,
                'name': 'Older track',
                'artist': 'Artist',
                'audio_file_url': 'https://example.test/older.mp3',
              },
            ]),
            200,
          );
        }),
      );
      final row = await repository.track(101);
      expect(captured.url.queryParameters['id'], 'eq.101');
      expect(captured.url.queryParameters['limit'], '1');
      expect(row, isNotNull);
      final found = row!;
      expect(found['id'], 101);
      expect(found['audioFileUrl'], 'https://example.test/older.mp3');
    },
  );

  test('by-ID lookup returns null for an absent track', () async {
    final repository = MusicRepository(
      null,
      supabaseUrl: 'https://project.supabase.co',
      publishableKey: 'sb_publishable_test_key',
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    );
    expect(await repository.track(404), isNull);
  });

  test(
    'guest favorites fail explicitly instead of reporting a saved like',
    () async {
      final client = SupabaseClient('https://example.test', 'public-test-key');
      final repository = MusicRepository(client);
      await expectLater(
        repository.setFavorite(1, true),
        throwsA(isA<AuthException>()),
      );
      await client.dispose();
    },
  );

  test('invalid pagination fails before any HTTP request', () async {
    var requests = 0;
    final repository = MusicRepository(
      null,
      supabaseUrl: 'https://project.example.test',
      publishableKey: 'test-key',
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    await expectLater(repository.tracks(from: -1), throwsArgumentError);
    await expectLater(repository.tracks(limit: 0), throwsArgumentError);
    await expectLater(repository.tracks(limit: 101), throwsArgumentError);
    expect(requests, 0);
  });

  test(
    'REST errors preserve status without exposing response internals',
    () async {
      final repository = MusicRepository(
        null,
        supabaseUrl: 'https://project.example.test',
        publishableKey: 'test-key',
        httpClient: MockClient(
          (_) async => http.Response('private backend detail', 403),
        ),
      );
      await expectLater(
        repository.tracks(),
        throwsA(
          isA<http.ClientException>()
              .having((error) => error.message, 'status', contains('403'))
              .having(
                (error) => error.message,
                'no response disclosure',
                isNot(contains('private backend detail')),
              ),
        ),
      );
    },
  );

  for (final body in ['{"error":"not an array"}', 'not-json']) {
    test('malformed catalog body is rejected: $body', () async {
      final repository = MusicRepository(
        null,
        supabaseUrl: 'https://project.example.test',
        publishableKey: 'test-key',
        httpClient: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(repository.tracks(), throwsFormatException);
    });
  }

  test(
    'search punctuation is data, never additional PostgREST operators',
    () async {
      late Uri requested;
      final repository = MusicRepository(
        null,
        supabaseUrl: 'https://project.example.test///',
        publishableKey: 'test-key',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response('[]', 200);
        }),
      );
      await repository.tracks(query: ' Moon, (Day).*% ');
      expect(requested.path, '/rest/v1/tracks');
      expect(
        requested.queryParameters['or'],
        '(name.ilike.*Moon Day*,artist.ilike.*Moon Day*)',
      );
      await repository.tracks(query: ' ,().%* ');
      expect(requested.queryParameters.containsKey('or'), isFalse);
    },
  );
}
