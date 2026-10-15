import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/coursework/dart_practice.dart';

void main() {
  test('summarizes track duration and nullable album names', () {
    const tracks = [
      PracticeTrack(title: 'North', artist: 'Aster', duration: 125),
      PracticeTrack(title: 'South', artist: 'Aster', duration: 95),
      PracticeTrack(title: 'East', artist: 'Mira', duration: 180),
    ];

    final summary = summarizeTracks(tracks);

    expect(summary.trackCount, 3);
    expect(summary.totalDuration, const Duration(seconds: 400));
    expect(summary.artists, {'Aster', 'Mira'});
    expect(formatAlbumName(null), 'Без альбома');
    expect(formatAlbumName('  Night Drive  '), 'Night Drive');
  });

  test('loads a playlist asynchronously', () async {
    final tracks = await loadPracticePlaylist(
      () async => const [
        PracticeTrack(title: 'North', artist: 'Aster', duration: 125),
      ],
    );

    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'North');
  });
}
