import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/widgets/track_artwork.dart';

void main() {
  testWidgets('shows designed local artwork when a cover URL is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 180,
              child: TrackArtwork(
                title: 'Moonlight Beach',
                artist: 'Kevin MacLeod',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Moonlight Beach'), findsOneWidget);
    expect(find.text('Kevin MacLeod'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });
}
