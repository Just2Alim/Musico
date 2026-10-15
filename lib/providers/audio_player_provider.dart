import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/music_repository.dart';
import '../features/player/music_audio_handler.dart';
import '../features/player/shake_to_skip_controller.dart';
import 'dart:math';

part 'audio_player_provider.g.dart';

@JsonSerializable()
class Track {
  @JsonKey(fromJson: _trackInt, defaultValue: 0)
  final int id;
  @JsonKey(defaultValue: 'Unknown Track')
  final String name;
  @JsonKey(defaultValue: 'Unknown Artist')
  final String artist;
  final String? genre;
  @JsonKey(name: 'cover_image_url', readValue: _readTrackCover)
  final String? coverImageUrl;
  @JsonKey(name: 'audio_file_url', readValue: _readTrackAudio, defaultValue: '')
  final String audioFileUrl;
  @JsonKey(fromJson: _trackInt, defaultValue: 0)
  final int duration;
  @JsonKey(defaultValue: false)
  final bool isLiked;

  const Track({
    required this.id,
    required this.name,
    required this.artist,
    this.genre,
    this.coverImageUrl,
    required this.audioFileUrl,
    required this.duration,
    this.isLiked = false,
  });

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  Map<String, dynamic> toJson() => _$TrackToJson(this);

  void logTrackInfo() {
    print('Track Info:');
    print('- ID: $id');
    print('- Name: $name');
    print('- Artist: $artist');
    print('- Genre: $genre');
    print('- Cover URL: $coverImageUrl');
    print('- Audio URL: $audioFileUrl');
    print('- Duration: $duration');
    print('- Is Liked: $isLiked');
  }
}

Object? _readTrackCover(Map<dynamic, dynamic> json, String key) =>
    json['cover_image_url'] ?? json['coverImageUrl'];

Object? _readTrackAudio(Map<dynamic, dynamic> json, String key) =>
    json['audio_file_url'] ?? json['audioFileUrl'];

int _trackInt(Object? value) => value is num ? value.toInt() : 0;

abstract interface class PlaybackEngine implements Listenable {
  Track? get currentTrack;
  bool get isPlaying;
  bool get isLoading;
  Duration get position;
  Duration get duration;
  String get errorMessage;
  bool get repeatEnabled;
  bool get shuffleEnabled;

  Future<void> loadTrackById(int trackId);
  Future<void> loadAndPlayTracks(List<Map<String, dynamic>> rows, int startId);
  Future<void> loadAndPlayPlaylist(int playlistId, {int startTrackId = -1});
  Future<void> togglePlayPause();
  Future<void> seekTo(Duration position);
  Future<void> playPreviousTrack();
  Future<void> playNextTrack();
  void toggleRepeatMode();
  void toggleShuffleMode();
}

class AudioPlayerAlternativeProvider
    with ChangeNotifier
    implements PlaybackEngine {
  final MusicRepository _repository;
  late final AudioPlayer _audioPlayer;
  late final MusicAudioHandler _audioHandler;
  Track? _currentTrack;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _errorMessage = '';
  List<Track> _playlist = [];
  int _currentTrackIndex = 0;
  bool _repeatEnabled = false;
  bool _shuffleEnabled = false;
  bool _shakeToSkipEnabled = false;
  bool _isDisposed = false;
  int? _loadingTrackId;
  Future<void>? _trackLoad;
  int _trackRequest = 0;
  int _favoriteRequest = 0;
  ShakeToSkipController? _shakeController;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  String get errorMessage => _errorMessage;
  bool get repeatEnabled => _repeatEnabled;
  bool get shuffleEnabled => _shuffleEnabled;
  bool get shakeToSkipEnabled => _shakeToSkipEnabled;
  List<Track> get playlist => List.unmodifiable(_playlist);
  int get currentTrackIndex => _currentTrackIndex;

  Future<void> loadShakeToSkipSetting() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('shake_to_skip_enabled') == true) {
      await setShakeToSkipEnabled(true, persist: false);
    }
  }

  Future<void> setShakeToSkipEnabled(
    bool enabled, {
    bool persist = true,
  }) async {
    if (_shakeToSkipEnabled == enabled) return;
    _shakeToSkipEnabled = enabled;
    if (enabled) {
      _shakeController = ShakeToSkipController(
        events: accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ),
        onShake: playNextTrack,
      )..start();
    } else {
      await _shakeController?.dispose();
      _shakeController = null;
    }
    if (persist) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('shake_to_skip_enabled', enabled);
    }
    notifyListeners();
  }

  AudioPlayerAlternativeProvider(
    this._repository, {
    AudioPlayer? audioPlayer,
    MusicAudioHandler? audioHandler,
  }) {
    _audioPlayer = audioHandler?.player ?? audioPlayer ?? AudioPlayer();
    _audioHandler = audioHandler ?? MusicAudioHandler(_audioPlayer);
    _audioHandler.onSkipNext = playNextTrack;
    _audioHandler.onSkipPrevious = playPreviousTrack;
    _initialize();
    _updatePlaybackHandlers();
  }

  void _initialize() {
    print('Инициализация AudioPlayer (audioplayers)...');

    // События аудиоплеера
    _playerSubscriptions.add(
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (_isDisposed) return;
        print('Состояние плеера: $state');
        switch (state) {
          case PlayerState.playing:
            _isPlaying = true;
            _isLoading = false;
            break;
          case PlayerState.paused:
            _isPlaying = false;
            break;
          case PlayerState.stopped:
            _isPlaying = false;
            break;
          case PlayerState.completed:
            _isPlaying = false;
            recordListening(completed: true);
            break;
          case PlayerState.disposed:
            break;
        }
        notifyListeners();
      }),
    );

    _playerSubscriptions.add(
      _audioPlayer.onPositionChanged.listen((position) {
        if (_isDisposed) return;
        _position = position;
        notifyListeners();
      }),
    );

    _playerSubscriptions.add(
      _audioPlayer.onDurationChanged.listen((duration) {
        if (_isDisposed) return;
        _duration = duration;
        notifyListeners();
      }),
    );

    print('AudioPlayer успешно инициализирован');
  }

  void _updatePlaybackHandlers() {
    _playerSubscriptions.add(
      _audioPlayer.onPlayerComplete.listen((_) {
        if (_isDisposed) return;
        recordListening(completed: true);

        if (_repeatEnabled && _playlist.isEmpty) {
          // Повтор одного трека
          _audioHandler.seek(Duration.zero);
          _audioHandler.play();
        } else if (_playlist.isNotEmpty) {
          // Если воспроизводится плейлист, переходим к следующему треку
          playNextTrack();
        } else {
          _isPlaying = false;
          notifyListeners();
        }
      }),
    );
  }

  Future<void> loadTrackById(int trackId) {
    if (_loadingTrackId == trackId && _trackLoad != null) return _trackLoad!;
    if (_currentTrack?.id == trackId && _errorMessage.isEmpty) {
      return Future<void>.value();
    }
    _loadingTrackId = trackId;
    final request = ++_trackRequest;
    late final Future<void> loading;
    loading = _loadTrackById(trackId, request).whenComplete(() {
      if (identical(_trackLoad, loading)) {
        _loadingTrackId = null;
        _trackLoad = null;
      }
    });
    _trackLoad = loading;
    return loading;
  }

  Future<void> _loadTrackById(int trackId, int request) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      print('Загрузка трека с ID: $trackId');

      final trackData = await _repository.track(trackId);
      if (_isDisposed || request != _trackRequest) return;
      if (trackData == null) {
        _errorMessage = 'Track data not found';
        _isLoading = false;
        notifyListeners();
        return;
      }
      final liked = await _repository.isFavorite(trackId);
      if (_isDisposed || request != _trackRequest) return;
      final track = Track.fromJson({
        ...trackData,
        'coverImageUrl': trackData['cover_image_url'],
        'audioFileUrl': trackData['audio_file_url'],
        'isLiked': liked,
      });

      await playTrack(track, refreshFavorite: false);
    } catch (e) {
      if (_isDisposed || request != _trackRequest) return;
      _errorMessage = 'Error loading track: $e';
      print('Ошибка в loadTrackById: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAndPlayTracks(
    List<Map<String, dynamic>> rows,
    int startId,
  ) async {
    _playlist = rows
        .map(
          (row) => Track.fromJson({
            ...row,
            'coverImageUrl': row['coverImageUrl'] ?? row['cover_image_url'],
            'audioFileUrl': row['audioFileUrl'] ?? row['audio_file_url'],
            'isLiked': row['isLiked'] ?? false,
          }),
        )
        .toList();
    _currentTrackIndex = _playlist.indexWhere((track) => track.id == startId);
    if (_currentTrackIndex < 0) _currentTrackIndex = 0;
    if (_playlist.isNotEmpty) await playTrack(_playlist[_currentTrackIndex]);
  }

  Future<void> playTrack(Track track, {bool refreshFavorite = true}) async {
    final request = ++_trackRequest;
    final favoriteRequest = _favoriteRequest;
    try {
      print('Воспроизведение трека:');
      print('ID: ${track.id}');
      print('Название: ${track.name}');
      print('Артист: ${track.artist}');
      print('URL обложки: ${track.coverImageUrl}');
      print('URL аудио: ${track.audioFileUrl}');

      _currentTrack = track;
      _position = Duration.zero;
      _duration = Duration(seconds: max(0, track.duration));
      _isPlaying = false;
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      // Проверка URL аудио
      if (track.audioFileUrl.isEmpty) {
        _errorMessage = 'Audio URL is empty';
        print('Ошибка: URL аудио пустой');
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _audioHandler.playMediaItem(
        MediaItem(
          id: track.audioFileUrl,
          title: track.name,
          artist: track.artist,
          album: track.genre,
          duration: Duration(seconds: track.duration),
          artUri: track.coverImageUrl?.isNotEmpty == true
              ? Uri.tryParse(track.coverImageUrl!)
              : null,
          extras: {'trackId': track.id},
        ),
      );

      if (_isDisposed || request != _trackRequest) return;
      // Запись в историю прослушиваний
      recordListening(completed: false);

      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
      if (refreshFavorite) {
        await _hydrateFavorite(track.id, request, favoriteRequest);
      }
    } catch (e) {
      if (_isDisposed || request != _trackRequest) return;
      _errorMessage = 'Error playing track: $e';
      print('Ошибка воспроизведения трека: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _hydrateFavorite(
    int trackId,
    int trackRequest,
    int favoriteRequest,
  ) async {
    try {
      final liked = await _repository.isFavorite(trackId);
      if (_isDisposed ||
          trackRequest != _trackRequest ||
          favoriteRequest != _favoriteRequest ||
          _currentTrack?.id != trackId)
        return;
      _currentTrack = Track.fromJson({
        ..._currentTrack!.toJson(),
        'isLiked': liked,
      });
      _playlist = _playlist
          .map(
            (queued) => queued.id == trackId
                ? Track.fromJson({...queued.toJson(), 'isLiked': liked})
                : queued,
          )
          .toList();
      notifyListeners();
    } catch (error) {
      // A failed metadata refresh must not interrupt public audio playback.
      // Keep the last known favorite value; mutations report their own errors.
      debugPrint('Favorite metadata refresh failed (${error.runtimeType}).');
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null) {
      _errorMessage = 'No track selected';
      print('Ошибка: Трек не выбран');
      return;
    }

    try {
      if (_isPlaying) {
        print('Пауза воспроизведения');
        await _audioHandler.pause();
      } else {
        print('Возобновление воспроизведения');
        await _audioHandler.play();
      }
    } catch (e) {
      _errorMessage = 'Error toggling play/pause: $e';
      print('Ошибка переключения воспроизведения/паузы: $e');
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      print('Перемотка к позиции: ${position.inSeconds} сек.');
      await _audioHandler.seek(position);
    } catch (e) {
      _errorMessage = 'Error seeking: $e';
      print('Ошибка перемотки: $e');
    }
  }

  void recordListening({bool completed = false}) async {
    if (_currentTrack == null) return;

    try {
      print(
        'Запись прослушивания трека ID: ${_currentTrack!.id}, completed: $completed',
      );

      await _repository.recordListening(
        _currentTrack!.id,
        completed: completed,
      );
    } catch (e) {
      print('Ошибка записи прослушивания: $e');
    }
  }

  Future<void> toggleFavorite() async {
    final track = _currentTrack;
    if (track == null) return;
    final request = ++_favoriteRequest;
    final updated = Track.fromJson({
      ...track.toJson(),
      'isLiked': !track.isLiked,
    });
    _currentTrack = updated;
    notifyListeners();

    try {
      await _repository.setFavorite(track.id, updated.isLiked);
    } catch (error) {
      // A delayed response belongs to the selected track at request time.
      if (_isDisposed ||
          request != _favoriteRequest ||
          _currentTrack?.id != track.id)
        return;
      _currentTrack = track;
      _errorMessage = error is AuthException
          ? 'Войдите в аккаунт, чтобы сохранять избранное.'
          : 'Не удалось обновить избранное. Попробуйте ещё раз.';
      notifyListeners();
    }
  }

  // Воспроизведение предыдущего трека
  Future<void> playPreviousTrack() async {
    if (_playlist.isEmpty) return;

    // Если прошло меньше 3 секунд, переходим к предыдущему треку
    // Иначе начинаем текущий трек сначала
    if (_position.inSeconds <= 3 && _currentTrackIndex > 0) {
      _currentTrackIndex--;
      await playTrack(_playlist[_currentTrackIndex]);
    } else if (_position.inSeconds <= 3 &&
        _currentTrackIndex == 0 &&
        _repeatEnabled) {
      // Если включен повтор и мы на первом треке, переходим к последнему
      _currentTrackIndex = _playlist.length - 1;
      await playTrack(_playlist[_currentTrackIndex]);
    } else {
      // Начинаем текущий трек сначала
      await _audioHandler.seek(Duration.zero);
    }
  }

  // Воспроизведение следующего трека
  Future<void> playNextTrack() async {
    if (_playlist.isEmpty) return;

    if (_currentTrackIndex < _playlist.length - 1) {
      _currentTrackIndex++;
      await playTrack(_playlist[_currentTrackIndex]);
    } else if (_repeatEnabled) {
      // Если включен режим повтора и мы в конце плейлиста, начинаем сначала
      _currentTrackIndex = 0;
      await playTrack(_playlist[_currentTrackIndex]);
    } else {
      // Иначе останавливаем воспроизведение
      await _audioHandler.stop();
      _isPlaying = false;
      notifyListeners();
    }
  }

  // Включение/выключение режима повтора
  void toggleRepeatMode() {
    _repeatEnabled = !_repeatEnabled;
    print('Режим повтора: ${_repeatEnabled ? "включен" : "выключен"}');
    notifyListeners();
  }

  // Включение/выключение режима перемешивания
  void toggleShuffleMode() {
    _shuffleEnabled = !_shuffleEnabled;
    print('Режим перемешивания: ${_shuffleEnabled ? "включен" : "выключен"}');
    if (_shuffleEnabled && _playlist.isNotEmpty) {
      // Запоминаем текущий трек
      final currentTrack = _playlist[_currentTrackIndex];

      // Перемешиваем плейлист
      final Random random = Random();
      for (int i = _playlist.length - 1; i > 0; i--) {
        int j = random.nextInt(i + 1);
        Track temp = _playlist[i];
        _playlist[i] = _playlist[j];
        _playlist[j] = temp;
      }

      // Ищем новый индекс текущего трека
      _currentTrackIndex = _playlist.indexWhere(
        (track) => track.id == currentTrack.id,
      );
    }
    notifyListeners();
  }

  // Метод для получения списка треков в плейлисте
  Future<List<Track>> getPlaylistTracks(int playlistId) async {
    try {
      final tracksData = await _repository.playlistTracks(playlistId);
      final converted = <Track>[];
      for (final row in tracksData) {
        converted.add(
          Track.fromJson({
            ...row,
            'coverImageUrl': row['cover_image_url'],
            'audioFileUrl': row['audio_file_url'],
            'isLiked': await _repository.isFavorite(row['id'] as int),
          }),
        );
      }
      return converted;
    } catch (e) {
      print('Исключение при получении треков плейлиста: $e');
      return [];
    }
  }

  // Воспроизведение плейлиста
  Future<void> loadAndPlayPlaylist(
    int playlistId, {
    int startTrackId = -1,
  }) async {
    try {
      _playlist = await getPlaylistTracks(playlistId);

      if (_playlist.isEmpty) {
        _errorMessage = 'Плейлист пуст';
        notifyListeners();
        return;
      }

      // Если указан конкретный трек для начала воспроизведения
      if (startTrackId != -1) {
        _currentTrackIndex = _playlist.indexWhere(
          (track) => track.id == startTrackId,
        );
        if (_currentTrackIndex == -1)
          _currentTrackIndex = 0; // Если трек не найден, начинаем с первого
      } else {
        _currentTrackIndex = 0;
      }

      // Перемешиваем список, если включен режим shuffle
      if (_shuffleEnabled) {
        // Сохраняем выбранный трек
        final Track? selectedTrack = startTrackId != -1
            ? _playlist.firstWhere(
                (track) => track.id == startTrackId,
                orElse: () => _playlist[0],
              )
            : _playlist[0];

        // Перемешиваем
        final Random random = Random();
        for (int i = _playlist.length - 1; i > 0; i--) {
          int j = random.nextInt(i + 1);
          Track temp = _playlist[i];
          _playlist[i] = _playlist[j];
          _playlist[j] = temp;
        }

        // Перемещаем выбранный трек на первую позицию
        int newIndex = selectedTrack != null
            ? _playlist.indexWhere((track) => track.id == selectedTrack.id)
            : -1;
        if (newIndex != -1) {
          Track selected = _playlist.removeAt(newIndex);
          _playlist.insert(0, selected);
          _currentTrackIndex = 0;
        }
      }

      // Запускаем воспроизведение
      await playTrack(_playlist[_currentTrackIndex]);
    } catch (e) {
      _errorMessage = 'Ошибка загрузки плейлиста: $e';
      print(_errorMessage);
      notifyListeners();
    }
  }

  // Добавление трека в очередь воспроизведения
  void addToQueue(Track track) {
    _playlist.add(track);
    print('Трек "${track.name}" добавлен в очередь воспроизведения');
    notifyListeners();
  }

  // Очистка очереди воспроизведения
  void clearQueue() {
    _playlist.clear();
    _currentTrackIndex = 0;
    print('Очередь воспроизведения очищена');
    notifyListeners();
  }

  // Тестовый метод
  Future<void> playTestTrack() async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      const testUrl =
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
      print('Воспроизведение тестового трека: $testUrl');

      // Создание тестового трека
      final testTrack = Track(
        id: 999,
        name: 'Test Track',
        artist: 'Test Artist',
        audioFileUrl: testUrl,
        duration: 0,
      );

      _currentTrack = testTrack;

      await _audioHandler.playMediaItem(
        const MediaItem(
          id: testUrl,
          title: 'Test Track',
          artist: 'Test Artist',
        ),
      );

      _isPlaying = true;
      _isLoading = false;
      notifyListeners();

      print('Тестовый трек запущен успешно');
    } catch (e) {
      _errorMessage = 'Error playing test track: $e';
      print('Ошибка воспроизведения тестового трека: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    try {
      print('Освобождение ресурсов AudioPlayer');
      for (final subscription in _playerSubscriptions) {
        unawaited(subscription.cancel());
      }
      unawaited(_shakeController?.dispose() ?? Future<void>.value());
      unawaited(_audioHandler.dispose());
      unawaited(_audioPlayer.dispose());
    } catch (e) {
      print('Ошибка при освобождении ресурсов AudioPlayer: $e');
    }
    super.dispose();
  }
}
