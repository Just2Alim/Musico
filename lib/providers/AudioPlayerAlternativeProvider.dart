import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../graphql/graphql_config.dart';
import 'dart:math';

class Track {
  final int id;
  final String name;
  final String artist;
  final String? genre;
  final String? coverImageUrl;
  final String audioFileUrl;
  final int duration;
  final bool isLiked;

  Track({
    required this.id,
    required this.name,
    required this.artist,
    this.genre,
    this.coverImageUrl,
    required this.audioFileUrl,
    required this.duration,
    this.isLiked = false,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Track',
      artist: json['artist'] ?? 'Unknown Artist',
      genre: json['genre'],
      coverImageUrl: json['coverImageUrl'],
      audioFileUrl: json['audioFileUrl'] ?? '',
      duration: json['duration'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }

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

class AudioPlayerAlternativeProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
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
  List<Track> get playlist => List.unmodifiable(_playlist);
  int get currentTrackIndex => _currentTrackIndex;
  
  AudioPlayerAlternativeProvider() {
    _initialize();
    _updatePlaybackHandlers();
  }
  
  void _initialize() {
    print('Инициализация AudioPlayer (audioplayers)...');
    
    // События аудиоплеера
    _audioPlayer.onPlayerStateChanged.listen((state) {
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
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });
    
    print('AudioPlayer успешно инициализирован');
  }
  
  void _updatePlaybackHandlers() {
    _audioPlayer.onPlayerComplete.listen((_) {
      recordListening(completed: true);
      
      if (_repeatEnabled && _playlist.isEmpty) {
        // Повтор одного трека
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.resume();
      } else if (_playlist.isNotEmpty) {
        // Если воспроизводится плейлист, переходим к следующему треку
        playNextTrack();
      } else {
        _isPlaying = false;
        notifyListeners();
      }
    });
  }
  
  Future<void> loadTrackById(int trackId) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
      
      print('Загрузка трека с ID: $trackId');
      
      const String trackQuery = '''
        query GetTrack(\$trackId: Int!) {
          track(trackId: \$trackId) {
            id
            name
            artist
            genre
            duration
            coverImageUrl
            audioFileUrl
            isLiked
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(trackQuery),
        variables: {
          'trackId': trackId,
        },
        fetchPolicy: FetchPolicy.networkOnly, // Не использовать кэш
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(options);

      if (result.hasException) {
        _errorMessage = 'Error loading track data: ${result.exception.toString()}';
        print('Ошибка запроса GraphQL: ${result.exception.toString()}');
        _isLoading = false;
        notifyListeners();
        return;
      }

      final trackData = result.data?['track'];
      if (trackData == null) {
        _errorMessage = 'Track data not found';
        print('Данные трека не найдены');
        _isLoading = false;
        notifyListeners();
        return;
      }

      print('Получены данные трека: $trackData');
      final track = Track.fromJson(trackData);
      track.logTrackInfo(); // Вывод информации о треке для отладки
      
      await playTrack(track);
    } catch (e) {
      _errorMessage = 'Error loading track: $e';
      print('Ошибка в loadTrackById: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> playTrack(Track track) async {
    try {
      print('Воспроизведение трека:');
      print('ID: ${track.id}');
      print('Название: ${track.name}');
      print('Артист: ${track.artist}');
      print('URL обложки: ${track.coverImageUrl}');
      print('URL аудио: ${track.audioFileUrl}');
      
      _currentTrack = track;
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
      
      // Остановка текущего воспроизведения
      await _audioPlayer.stop();
      
      // Установка URL для воспроизведения
      print('Установка URL: ${track.audioFileUrl}');
      
      // Новый синтаксис audioplayers
      await _audioPlayer.play(UrlSource(track.audioFileUrl));
      
      // Запись в историю прослушиваний
      recordListening(completed: false);
      
      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error playing track: $e';
      print('Ошибка воспроизведения трека: $e');
      _isLoading = false;
      notifyListeners();
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
        await _audioPlayer.pause();
      } else {
        print('Возобновление воспроизведения');
        await _audioPlayer.resume();
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
      await _audioPlayer.seek(position);
    } catch (e) {
      _errorMessage = 'Error seeking: $e';
      print('Ошибка перемотки: $e');
    }
  }
  
  void recordListening({bool completed = false}) async {
    if (_currentTrack == null) return;

    try {
      print('Запись прослушивания трека ID: ${_currentTrack!.id}, completed: $completed');
      
      const String mutation = '''
        mutation RecordListening(\$trackId: Int!, \$completed: Boolean) {
          recordListening(trackId: \$trackId, completed: \$completed) {
            id
          }
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'trackId': _currentTrack!.id,
          'completed': completed,
        },
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final result = await client.mutate(options);
      
      if (result.hasException) {
        print('Ошибка записи прослушивания: ${result.exception.toString()}');
      } else {
        print('Прослушивание успешно записано');
      }
    } catch (e) {
      print('Ошибка записи прослушивания: $e');
    }
  }
  
  Future<void> toggleFavorite() async {
    if (_currentTrack == null) return;

    final bool currentLiked = _currentTrack!.isLiked;
    
    // Оптимистичное обновление
    _currentTrack = Track(
      id: _currentTrack!.id,
      name: _currentTrack!.name,
      artist: _currentTrack!.artist,
      genre: _currentTrack!.genre,
      coverImageUrl: _currentTrack!.coverImageUrl,
      audioFileUrl: _currentTrack!.audioFileUrl,
      duration: _currentTrack!.duration,
      isLiked: !currentLiked,
    );
    
    notifyListeners();

    try {
      print('Переключение статуса избранного для трека ID: ${_currentTrack!.id}, текущий статус: $currentLiked');
      
      final String mutation = currentLiked
          ? '''
            mutation UnlikeTrack(\$trackId: Int!) {
              unlikeTrack(trackId: \$trackId)
            }
          '''
          : '''
            mutation LikeTrack(\$trackId: Int!) {
              likeTrack(trackId: \$trackId)
            }
          ''';

      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'trackId': _currentTrack!.id,
        },
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.mutate(options);

      if (result.hasException) {
        print('Ошибка изменения статуса избранного: ${result.exception.toString()}');
        
        // Вернуть предыдущее состояние при ошибке
// Вернуть предыдущее состояние при ошибке
        _currentTrack = Track(
          id: _currentTrack!.id,
          name: _currentTrack!.name,
          artist: _currentTrack!.artist,
          genre: _currentTrack!.genre,
          coverImageUrl: _currentTrack!.coverImageUrl,
          audioFileUrl: _currentTrack!.audioFileUrl,
          duration: _currentTrack!.duration,
          isLiked: currentLiked,
        );
        notifyListeners();
      } else {
        print('Статус избранного успешно изменен');
      }
    } catch (e) {
      print('Ошибка переключения избранного: $e');
      
      // Вернуть предыдущее состояние при ошибке
      _currentTrack = Track(
        id: _currentTrack!.id,
        name: _currentTrack!.name,
        artist: _currentTrack!.artist,
        genre: _currentTrack!.genre,
        coverImageUrl: _currentTrack!.coverImageUrl,
        audioFileUrl: _currentTrack!.audioFileUrl,
        duration: _currentTrack!.duration,
        isLiked: currentLiked,
      );
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
    } else if (_position.inSeconds <= 3 && _currentTrackIndex == 0 && _repeatEnabled) {
      // Если включен повтор и мы на первом треке, переходим к последнему
      _currentTrackIndex = _playlist.length - 1;
      await playTrack(_playlist[_currentTrackIndex]);
    } else {
      // Начинаем текущий трек сначала
      await _audioPlayer.seek(Duration.zero);
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
      await _audioPlayer.stop();
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
      _currentTrackIndex = _playlist.indexWhere((track) => track.id == currentTrack.id);
    }
    notifyListeners();
  }
  
  // Метод для получения списка треков в плейлисте
  Future<List<Track>> getPlaylistTracks(int playlistId) async {
    try {
      const String query = '''
        query GetPlaylistTracks(\$playlistId: Int!) {
          playlist(playlistId: \$playlistId) {
            tracks {
              id
              name
              artist
              genre
              duration
              coverImageUrl
              audioFileUrl
              isLiked
            }
          }
        }
      ''';

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(
        QueryOptions(
          document: gql(query),
          variables: {
            'playlistId': playlistId,
          },
        ),
      );

      if (result.hasException) {
        print('Ошибка при получении треков плейлиста: ${result.exception.toString()}');
        return [];
      }

      final List<dynamic> tracksData = result.data?['playlist']['tracks'] ?? [];
      return tracksData.map((trackData) => Track.fromJson(trackData)).toList();
    } catch (e) {
      print('Исключение при получении треков плейлиста: $e');
      return [];
    }
  }
  
  // Воспроизведение плейлиста
  Future<void> loadAndPlayPlaylist(int playlistId, {int startTrackId = -1}) async {
    try {
      _playlist = await getPlaylistTracks(playlistId);
      
      if (_playlist.isEmpty) {
        _errorMessage = 'Плейлист пуст';
        notifyListeners();
        return;
      }
      
      // Если указан конкретный трек для начала воспроизведения
      if (startTrackId != -1) {
        _currentTrackIndex = _playlist.indexWhere((track) => track.id == startTrackId);
        if (_currentTrackIndex == -1) _currentTrackIndex = 0; // Если трек не найден, начинаем с первого
      } else {
        _currentTrackIndex = 0;
      }
      
      // Перемешиваем список, если включен режим shuffle
      if (_shuffleEnabled) {
        // Сохраняем выбранный трек
        final Track? selectedTrack = startTrackId != -1
            ? _playlist.firstWhere((track) => track.id == startTrackId, orElse: () => _playlist[0])
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
      
      const testUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
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
      
      // Остановка текущего воспроизведения
      await _audioPlayer.stop();
      
      // Установка URL для воспроизведения
      await _audioPlayer.play(UrlSource(testUrl));
      
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
  void dispose() {
    try {
      print('Освобождение ресурсов AudioPlayer');
      _audioPlayer.dispose();
    } catch (e) {
      print('Ошибка при освобождении ресурсов AudioPlayer: $e');
    }
    super.dispose();
  }
}