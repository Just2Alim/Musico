import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/widgets/playback_progress.dart';

void main() {
  testWidgets('clamps stale position and disables unknown duration', (
    tester,
  ) async {
    Future<void> mount(Duration duration) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackProgress(
            position: const Duration(seconds: 120),
            duration: duration,
            onSeek: (_) {},
          ),
        ),
      ),
    );
    await mount(const Duration(seconds: 9));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 9000);
    expect(tester.takeException(), isNull);
    await mount(Duration.zero);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(tester.takeException(), isNull);
  });
}
