import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/features/player/shake_to_skip_controller.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  test(
    'skips on a strong shake and ignores readings during cooldown',
    () async {
      final events = StreamController<AccelerometerEvent>();
      var now = DateTime.utc(2026);
      var skipCount = 0;
      final controller = ShakeToSkipController(
        events: events.stream,
        onShake: () async => skipCount++,
        now: () => now,
        cooldown: const Duration(seconds: 1),
        threshold: 18,
      );
      controller.start();

      events.add(AccelerometerEvent(3, 2, 1, now));
      events.add(AccelerometerEvent(20, 0, 0, now));
      await Future<void>.delayed(Duration.zero);
      expect(skipCount, 1);

      now = now.add(const Duration(milliseconds: 500));
      events.add(AccelerometerEvent(22, 0, 0, now));
      await Future<void>.delayed(Duration.zero);
      expect(skipCount, 1);

      now = now.add(const Duration(seconds: 1));
      events.add(AccelerometerEvent(22, 0, 0, now));
      await Future<void>.delayed(Duration.zero);
      expect(skipCount, 2);

      await controller.dispose();
      await events.close();
    },
  );
}
