import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/providers/audio_player_provider.dart';
import 'package:musico_app/widgets/music_credit.dart';

Track track({
  String name = 'Acid Trumpet',
  String artist = 'Kevin MacLeod',
  String audioUrl =
      'https://incompetech.com/music/royalty-free/mp3-royaltyfree/AcidJazz.mp3',
}) => Track(
  id: 1,
  name: name,
  artist: artist,
  audioFileUrl: audioUrl,
  duration: 208,
);

Future<void> showCredit(WidgetTester tester, Track value) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 280, child: MusicCredit(track: value)),
      ),
    ),
  );
}

void main() {
  testWidgets('licensed track exposes author and selectable source and license', (
    tester,
  ) async {
    await showCredit(tester, track());
    expect(find.textContaining('Acid Trumpet'), findsOneWidget);
    expect(find.textContaining('Kevin MacLeod'), findsOneWidget);
    expect(find.textContaining('CC BY 4.0'), findsOneWidget);
    expect(find.textContaining('без изменений'), findsOneWidget);
    expect(
      find.widgetWithText(
        SelectableText,
        'https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100339',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        SelectableText,
        'https://creativecommons.org/licenses/by/4.0/',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not assign the license to a different artist', (
    tester,
  ) async {
    await showCredit(tester, track(artist: 'Other Artist'));
    expect(find.textContaining('CC BY'), findsNothing);
  });

  testWidgets('does not assign the license to an unverified track', (
    tester,
  ) async {
    await showCredit(tester, track(name: 'Unknown composition'));
    expect(find.textContaining('CC BY'), findsNothing);
  });

  testWidgets('does not credit an unverified recording with a familiar title', (
    tester,
  ) async {
    await showCredit(
      tester,
      track(audioUrl: 'https://example.com/AcidJazz.mp3'),
    );
    expect(find.textContaining('CC BY'), findsNothing);
  });
}
