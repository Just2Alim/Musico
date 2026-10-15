import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/domain/entities/venue.dart';
import 'package:musico_app/providers/audio_player_provider.dart';

void main() {
  test('Track JSON serialization preserves Supabase column names', () {
    const track = Track(
      id: 5,
      name: 'Midnight',
      artist: 'Aster',
      audioFileUrl: 'https://example.test/audio.mp3',
      duration: 182,
      coverImageUrl: 'https://example.test/cover.jpg',
      isLiked: true,
    );

    final json = track.toJson();

    expect(json['cover_image_url'], 'https://example.test/cover.jpg');
    expect(json['audio_file_url'], 'https://example.test/audio.mp3');
    expect(Track.fromJson(json).name, 'Midnight');
    expect(Track.fromJson(json).source, 'supabase');
  });

  test('Track JSON round-trips licensed external source metadata', () {
    final track = Track.fromJson({
      'id': -123,
      'name': 'Open Sky',
      'artist': 'Example Artist',
      'audio_file_url': 'https://cdn.example.test/open-sky.mp3',
      'duration': 210,
      'source': 'jamendo',
      'license_url': 'https://creativecommons.org/licenses/by/4.0/',
      'source_url': 'https://www.jamendo.com/track/123',
    });

    expect(track.source, 'jamendo');
    expect(track.licenseUrl, 'https://creativecommons.org/licenses/by/4.0/');
    expect(track.sourceUrl, 'https://www.jamendo.com/track/123');
    expect(Track.fromJson(track.toJson()).sourceUrl, track.sourceUrl);
  });

  test('Venue JSON serialization round-trips coordinates', () {
    const venue = Venue(
      id: 7,
      name: 'Live Hall',
      address: 'Almaty',
      description: 'Concert venue',
      latitude: 43.238,
      longitude: 76.945,
    );

    final decoded = Venue.fromJson(venue.toJson());

    expect(decoded.latitude, 43.238);
    expect(decoded.longitude, 76.945);
    expect(decoded.name, 'Live Hall');
  });
}
