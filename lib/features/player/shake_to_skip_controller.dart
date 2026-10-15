import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Turns a strong accelerometer movement into a rate-limited next-track action.
class ShakeToSkipController {
  ShakeToSkipController({
    required Stream<AccelerometerEvent> events,
    required Future<void> Function() onShake,
    DateTime Function()? now,
    this.threshold = 18,
    this.cooldown = const Duration(seconds: 1),
  }) : _events = events,
       _onShake = onShake,
       _now = now ?? DateTime.now;

  final Stream<AccelerometerEvent> _events;
  final Future<void> Function() _onShake;
  final DateTime Function() _now;
  final double threshold;
  final Duration cooldown;
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastShake;

  void start() {
    _subscription ??= _events.listen(_handleEvent);
  }

  void _handleEvent(AccelerometerEvent event) {
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude < threshold) return;

    final now = _now();
    final lastShake = _lastShake;
    if (lastShake != null && now.difference(lastShake) < cooldown) return;

    _lastShake = now;
    unawaited(_onShake());
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
