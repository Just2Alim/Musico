import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// Keeps late platform progress events within the current track's bounds.
class PlaybackProgress extends StatelessWidget {
  const PlaybackProgress({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final length = duration.inMilliseconds;
    return Slider(
      key: const Key('playback-progress'),
      value: length > 0
          ? position.inMilliseconds.clamp(0, length).toDouble()
          : 0,
      min: 0,
      max: length > 0 ? length.toDouble() : 1,
      onChanged: length > 0
          ? (value) => onSeek(Duration(milliseconds: value.round()))
          : null,
      activeColor: AppTheme.accent,
      inactiveColor: AppTheme.elevatedSurface,
    );
  }
}
