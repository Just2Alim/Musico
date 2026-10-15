import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:musico_app/main.dart' as app;
import 'package:musico_app/providers/audio_player_provider.dart';
import 'package:musico_app/services/player_screen.dart';

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  int seconds = 40,
}) async {
  for (var i = 0; i < seconds * 4 && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for runtime state');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real Android stream, controls, reopen and catalog search', (
    tester,
  ) async {
    await app.main();
    await waitFor(
      tester,
      () => find.text('Moonlight Beach').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Moonlight Beach').first);
    await waitFor(
      tester,
      () => find.byType(PlayerScreen).evaluate().isNotEmpty,
    );
    final context = tester.element(find.byType(PlayerScreen));
    final player = context.read<AudioPlayerAlternativeProvider>();
    await waitFor(tester, () => player.position.inSeconds >= 2);
    expect(player.currentTrack?.name, 'Moonlight Beach');
    expect(player.duration.inSeconds, greaterThan(300));
    expect(player.errorMessage, isEmpty);
    await tester.tap(find.byIcon(Icons.pause).first);
    await waitFor(tester, () => !player.isPlaying);
    await player.seekTo(const Duration(seconds: 30));
    await waitFor(tester, () => player.position.inSeconds >= 29);
    final router = GoRouter.of(context);
    router.pop();
    await tester.pumpAndSettle();
    router.push('/player/${player.currentTrack!.id}');
    await waitFor(
      tester,
      () => find.byType(PlayerScreen).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(player.isPlaying, isFalse);
    expect(player.position.inSeconds, greaterThanOrEqualTo(29));
    final previousId = player.currentTrack!.id;
    await tester.tap(find.byIcon(Icons.skip_next).first);
    await waitFor(
      tester,
      () => player.currentTrack?.id != previousId && player.isPlaying,
    );
    await waitFor(tester, () => player.position.inSeconds >= 1);
    expect(player.errorMessage, isEmpty);
    await player.togglePlayPause();
    router.pop();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Поиск').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).first, 'Easy Lemon');
    await waitFor(tester, () => find.text('Easy Lemon').evaluate().isNotEmpty);
    expect(find.text('Kevin MacLeod'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
