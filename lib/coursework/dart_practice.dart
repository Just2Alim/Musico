/// Small, runnable examples used for the Dart fundamentals in Week 1.
class PracticeTrack {
  const PracticeTrack({
    required this.title,
    required this.artist,
    required this.duration,
    this.album,
  });

  final String title;
  final String artist;
  final int duration;
  final String? album;
}

class TrackSummary {
  const TrackSummary({
    required this.trackCount,
    required this.totalDuration,
    required this.artists,
  });

  final int trackCount;
  final Duration totalDuration;
  final Set<String> artists;
}

TrackSummary summarizeTracks(Iterable<PracticeTrack> tracks) {
  var count = 0;
  var totalSeconds = 0;
  final artists = <String>{};

  for (final track in tracks) {
    count++;
    totalSeconds += track.duration;
    artists.add(track.artist);
  }

  return TrackSummary(
    trackCount: count,
    totalDuration: Duration(seconds: totalSeconds),
    artists: Set.unmodifiable(artists),
  );
}

String formatAlbumName(String? album) {
  final trimmedAlbum = album?.trim();
  return trimmedAlbum == null || trimmedAlbum.isEmpty
      ? 'Без альбома'
      : trimmedAlbum;
}

Future<List<PracticeTrack>> loadPracticePlaylist(
  Future<List<PracticeTrack>> Function() load,
) async {
  final tracks = await load();
  return List.unmodifiable(tracks);
}
