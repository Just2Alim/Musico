import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/widgets/mini_player.dart';

void main() {
  testWidgets(
    'mini player separates open, playback, next and favorite actions',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              trackName: 'Moonlight Beach',
              artistName: 'Kevin MacLeod',
              isPlaying: false,
              isLoading: false,
              isLiked: true,
              onTap: () => calls.add('open'),
              onPlayPause: () => calls.add('play'),
              onNext: () => calls.add('next'),
              onLike: () => calls.add('like'),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.tap(find.byIcon(Icons.favorite));
      expect(calls, ['play', 'next', 'like']);
      await tester.tap(find.text('Moonlight Beach'));
      expect(calls, ['play', 'next', 'like', 'open']);
    },
  );

  testWidgets('loading disables playback and optional actions stay hidden', (
    tester,
  ) async {
    var playCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniPlayer(
            trackName: 'Loading',
            artistName: 'Artist',
            isPlaying: false,
            isLoading: true,
            onTap: () {},
            onPlayPause: () => playCalls++,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(find.byIcon(Icons.skip_next), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(playCalls, 0);
  });

  testWidgets('playing state exposes pause and unselected favorite', (
    tester,
  ) async {
    var pauseCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniPlayer(
            trackName: 'Playing',
            artistName: 'Artist',
            isPlaying: true,
            isLoading: false,
            onTap: () {},
            onPlayPause: () => pauseCalls++,
            onLike: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.pause_circle_filled));
    expect(pauseCalls, 1);
  });
}
