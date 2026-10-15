import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/widgets/track_list_item.dart';

void main() {
  testWidgets('shows track metadata and opens the selected track', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackListItem(
            id: 42,
            title: 'Night Drive',
            artist: 'Musico Artist',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Musico Artist'), findsOneWidget);
    await tester.tap(find.text('Night Drive'));
    expect(tapped, isTrue);
  });
}
