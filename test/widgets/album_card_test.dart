import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/widgets/album_card.dart';

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('album card fits 160 by 200 with text scale $scale', (
      tester,
    ) async {
      var selected = false;
      const title = 'Musico Online — a long playlist title that needs ellipsis';
      const subtitle = 'Kevin MacLeod and other licensed online recordings';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SizedBox(
                width: 176,
                height: 200,
                child: AlbumCard(
                  id: 1,
                  title: title,
                  subtitle: subtitle,
                  onTap: () => selected = true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(title), findsOneWidget);
      expect(find.text(subtitle), findsOneWidget);
      expect(find.byIcon(Icons.album), findsOneWidget);
      final titleText = tester.widget<Text>(find.text(title));
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
      await tester.tap(find.text(title));
      expect(selected, isTrue);
    });
  }

  testWidgets('album card can size naturally outside a fixed-height list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AlbumCard(id: 2, title: 'Short title', onTap: () {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Short title'), findsOneWidget);
    expect(find.byIcon(Icons.album), findsOneWidget);
  });
}
