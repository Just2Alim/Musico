import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musico_app/data/jamendo_catalog_service.dart';

void main() {
  test('an unconfigured catalog returns no tracks without a request', () async {
    var requests = 0;
    final service = JamendoCatalogService(
      clientId: '',
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );

    expect(await service.search('ambient'), isEmpty);
    expect(requests, 0);
  });

  test(
    'search maps a credited Jamendo stream to an external track row',
    () async {
      final service = JamendoCatalogService(
        clientId: 'public-test-client',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['search'], 'ambient');
          expect(request.url.queryParameters['include'], 'licenses');
          return http.Response(
            jsonEncode({
              'headers': {'status': 'success'},
              'results': [
                {
                  'id': '123',
                  'name': 'Open Sky',
                  'artist_name': 'Example Artist',
                  'duration': 210,
                  'audio': 'https://cdn.example.test/open-sky.mp3',
                  'image': 'https://cdn.example.test/open-sky.jpg',
                  'license_ccurl':
                      'https://creativecommons.org/licenses/by/4.0/',
                  'shareurl': 'https://www.jamendo.com/track/123',
                },
              ],
            }),
            200,
          );
        }),
      );

      final tracks = await service.search('ambient');

      expect(tracks, hasLength(1));
      expect(tracks.single['id'], -123);
      expect(tracks.single['source'], 'jamendo');
      expect(tracks.single['artist'], 'Example Artist');
      expect(tracks.single['audio_file_url'], contains('.mp3'));
      expect(tracks.single['license_url'], contains('creativecommons.org'));
      expect(tracks.single['source_url'], contains('jamendo.com'));
    },
  );

  test('tracks without a stream or attribution are not exposed', () async {
    final service = JamendoCatalogService(
      clientId: 'public-test-client',
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'headers': {'status': 'success'},
            'results': [
              {
                'id': '1',
                'name': 'No Stream',
                'license_ccurl': 'https://license.test',
              },
              {
                'id': '2',
                'name': 'No Credit',
                'audio': 'https://cdn.test/a.mp3',
              },
            ],
          }),
          200,
        );
      }),
    );

    expect(await service.search('test'), isEmpty);
  });
}
