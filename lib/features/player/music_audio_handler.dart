import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

/// Bridges the existing audio engine to Android/iOS media controls.
class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  MusicAudioHandler([AudioPlayer? player]) : player = player ?? AudioPlayer() {
    _subscriptions.addAll([
      this.player.onPlayerStateChanged.listen(_publishPlayerState),
      this.player.onPositionChanged.listen(_publishPosition),
      this.player.onPlayerComplete.listen((_) {
        if (_preparingSource || _disposed) return;
        _publishState(
          playing: false,
          processingState: AudioProcessingState.completed,
        );
      }),
    ]);
  }

  final AudioPlayer player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;
  Duration _position = Duration.zero;
  Future<void> _operationTail = Future<void>.value();
  int _sourceRequest = 0;
  bool _preparingSource = false;
  bool _disposed = false;

  bool _isCurrent(int request) => !_disposed && request == _sourceRequest;

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationTail.then((_) => operation());
    // Return the error to this caller, while allowing later commands to run.
    _operationTail = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) {
    if (_disposed) return Future<void>.value();
    final request = ++_sourceRequest;
    _preparingSource = true;
    _position = Duration.zero;
    this.mediaItem.add(mediaItem);
    _publishState(
      playing: false,
      processingState: AudioProcessingState.loading,
    );
    return _enqueue(() async {
      if (!_isCurrent(request)) return;
      try {
        await player.stop();
        if (!_isCurrent(request)) return;
        await player.play(UrlSource(mediaItem.id));
        if (!_isCurrent(request)) return;
        _position = Duration.zero;
        _preparingSource = false;
        _publishState(
          playing: true,
          processingState: AudioProcessingState.ready,
        );
      } catch (_) {
        if (_isCurrent(request)) {
          _preparingSource = false;
          _publishState(
            playing: false,
            processingState: AudioProcessingState.idle,
          );
        }
        rethrow;
      }
    });
  }

  @override
  Future<void> play() {
    final request = _sourceRequest;
    return _enqueue(() async {
      if (!_isCurrent(request)) return;
      await player.resume();
      if (!_isCurrent(request)) return;
      _publishState(playing: true, processingState: AudioProcessingState.ready);
    });
  }

  @override
  Future<void> pause() {
    final request = _sourceRequest;
    return _enqueue(() async {
      if (!_isCurrent(request)) return;
      await player.pause();
      if (!_isCurrent(request)) return;
      _publishState(
        playing: false,
        processingState: AudioProcessingState.ready,
      );
    });
  }

  @override
  Future<void> seek(Duration position) {
    final request = _sourceRequest;
    return _enqueue(() async {
      if (!_isCurrent(request)) return;
      await player.seek(position);
      if (!_isCurrent(request)) return;
      _position = position;
      _publishState(
        playing: playbackState.value.playing,
        processingState: AudioProcessingState.ready,
      );
    });
  }

  @override
  Future<void> stop() {
    final request = ++_sourceRequest;
    _preparingSource = true;
    return _enqueue(() async {
      if (!_isCurrent(request)) return;
      await player.stop();
      if (!_isCurrent(request)) return;
      _position = Duration.zero;
      _preparingSource = false;
      _publishState(playing: false, processingState: AudioProcessingState.idle);
      await super.stop();
    });
  }

  @override
  Future<void> skipToNext() async => onSkipNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipPrevious?.call();

  void _publishPlayerState(PlayerState state) {
    if (_preparingSource || _disposed) return;
    switch (state) {
      case PlayerState.playing:
        _publishState(
          playing: true,
          processingState: AudioProcessingState.ready,
        );
        return;
      case PlayerState.paused:
      case PlayerState.stopped:
        _publishState(
          playing: false,
          processingState: AudioProcessingState.ready,
        );
        return;
      case PlayerState.completed:
        _publishState(
          playing: false,
          processingState: AudioProcessingState.completed,
        );
        return;
      case PlayerState.disposed:
        _publishState(
          playing: false,
          processingState: AudioProcessingState.idle,
        );
        return;
    }
  }

  void _publishPosition(Duration position) {
    if (_preparingSource || _disposed) return;
    _position = position;
    _publishState(
      playing: playbackState.value.playing,
      processingState: playbackState.value.processingState,
    );
  }

  void _publishState({
    required bool playing,
    required AudioProcessingState processingState,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: processingState,
        playing: playing,
        updatePosition: _position,
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    ++_sourceRequest;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
