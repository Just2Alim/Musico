import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/AudioPlayerAlternativeProvider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../graphql/graphql_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const PlayerScreen({Key? key, required this.arguments}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;
  bool _showBottomSheet = false;
  List<dynamic> _userPlaylists = [];
  bool _isLoadingPlaylists = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTrack();
    _checkUserId();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Приложение в фоновом режиме
    }
  }

  Future<void> _checkUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final token = prefs.getString('token');
    print('Current user ID: $userId');
    print('Auth token: ${token != null ? 'Available' : 'Not available'}');
  }

  void _loadTrack() {
    final int trackId = widget.arguments['trackId'];
    // Загружаем трек через провайдер
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AudioPlayerAlternativeProvider>(context, listen: false)
          .loadTrackById(trackId);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _toggleFavorite(Track track, AudioPlayerAlternativeProvider provider) async {
    await provider.toggleFavorite();
  }

  Future<void> _loadUserPlaylists() async {
    setState(() {
      _isLoadingPlaylists = true;
    });

    try {
      // Получаем ID текущего пользователя из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      
      if (userId == null) {
        print('_loadUserPlaylists: userId is null');
        setState(() {
          _isLoadingPlaylists = false;
        });
        return;
      }
      
      print('Loading playlists for userId: $userId');

      // Изменим запрос, чтобы передавать userId как переменную
      const String playlistsQuery = '''
        query GetUserPlaylists(\$userId: Int!) {
          playlists(userId: \$userId) {
            id
            name
            subtitle
            imageUrl
            trackCount
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(playlistsQuery),
        variables: {
          'userId': userId,
        },
        fetchPolicy: FetchPolicy.networkOnly, // Отключаем кэширование для получения актуальных данных
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      print('GraphQL client initialized');
      
      final QueryResult result = await client.query(options);
      print('Query executed');

      if (result.hasException) {
        print('Error in query: ${result.exception?.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading playlists: ${result.exception.toString()}')),
        );
      } else {
        print('Query result: ${result.data}');
        final playlists = result.data?['playlists'];
        print('Playlists received: $playlists');
        
        setState(() {
          _userPlaylists = playlists ?? [];
        });
        
        print('Playlists state updated: $_userPlaylists');
      }
    } catch (e) {
      print('Exception in _loadUserPlaylists: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load playlists: $e')),
      );
    } finally {
      setState(() {
        _isLoadingPlaylists = false;
      });
    }
  }

  Future<void> _addToPlaylist(int trackId, int playlistId) async {
    try {
      print('Adding track $trackId to playlist $playlistId');
      
      const String mutation = '''
        mutation AddTrackToPlaylist(\$playlistId: Int!, \$trackId: Int!) {
          addTrackToPlaylist(playlistId: \$playlistId, trackId: \$trackId)
        }
      ''';

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {
            'playlistId': playlistId,
            'trackId': trackId,
          },
        ),
      );

      if (result.hasException) {
        print('Error adding track to playlist: ${result.exception.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при добавлении трека: ${result.exception.toString()}')),
        );
      } else {
        print('Track successfully added to playlist');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Трек добавлен в плейлист')),
        );
        Navigator.pop(context); // Закрываем bottom sheet
      }
    } catch (e) {
      print('Exception when adding track to playlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Произошла ошибка: $e')),
      );
    }
  }

  void _showOptionsBottomSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Опции трека',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  leading: const Icon(Icons.queue_music, color: Colors.white),
                  title: const Text('В очередь воспроизведения', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    // Добавляем трек в очередь воспроизведения
                    Provider.of<AudioPlayerAlternativeProvider>(context, listen: false).addToQueue(track);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Трек добавлен в очередь воспроизведения')),
                    );
                  },
                ),
                Consumer<AudioPlayerAlternativeProvider>(
                  builder: (context, provider, child) {
                    return ListTile(
                      leading: Icon(
                        track.isLiked ? Icons.favorite : Icons.favorite_border, 
                        color: track.isLiked ? Colors.green : Colors.white
                      ),
                      title: Text(
                        track.isLiked ? 'Удалить из избранного' : 'Добавить в избранное', 
                        style: TextStyle(color: Colors.white)
                      ),
                      onTap: () async {
                        await _toggleFavorite(track, provider);
                        Navigator.pop(context);
                      },
                    );
                  }
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.white),
                  title: const Text('Поделиться', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    // Логика для функции "Поделиться"
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Функция "Поделиться" будет доступна в ближайшем обновлении')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.white),
                  title: const Text('Информация о треке', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    // Логика для функции "Информация о треке"
                    Navigator.pop(context);
                    _showTrackInfoDialog(context, track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add, color: Colors.white),
                  title: const Text('Добавить в плейлист', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    // Закрываем текущий bottom sheet
                    Navigator.pop(context);
                    
                    // Открываем новый bottom sheet для выбора плейлиста
                    _showAddToPlaylistBottomSheet(context, track);
                  },
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddToPlaylistBottomSheet(BuildContext context, Track track) {
    // Загружаем плейлисты пользователя, если они еще не загружены
    if (_userPlaylists.isEmpty && !_isLoadingPlaylists) {
      _loadUserPlaylists();
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Добавить в плейлист',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.grey),
                
                // Опция создания нового плейлиста
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: Colors.green),
                  title: const Text('Создать новый плейлист', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePlaylistDialog(context, track);
                  },
                ),
                
                const Divider(color: Colors.grey),
                
                // Список существующих плейлистов
                Expanded(
                  child: _isLoadingPlaylists 
                      ? const Center(child: CircularProgressIndicator(color: Colors.green))
                      : _userPlaylists.isEmpty
                          ? const Center(
                              child: Text(
                                'У вас пока нет плейлистов',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _userPlaylists.length,
                              itemBuilder: (context, index) {
                                final playlist = _userPlaylists[index];
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      image: playlist['imageUrl'] != null
                                          ? DecorationImage(
                                              image: NetworkImage(playlist['imageUrl']),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: Colors.grey[800],
                                    ),
                                    child: playlist['imageUrl'] == null
                                        ? const Icon(Icons.music_note, color: Colors.white, size: 24)
                                        : null,
                                  ),
                                  title: Text(
                                    playlist['name'] ?? 'Без названия',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '${playlist['trackCount'] ?? 0} треков',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                  onTap: () {
                                    _addToPlaylist(track.id, playlist['id']);
                                  },
                                );
                              },
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, Track track) {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Создать плейлист',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Название плейлиста',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  // Создаем плейлист и добавляем в него трек
                  await _createPlaylistAndAddTrack(nameController.text.trim(), track.id);
                  Navigator.pop(context);
                }
              },
              child: const Text('Создать', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPlaylistAndAddTrack(String name, int trackId) async {
    try {
      print('Creating playlist "$name" and adding track $trackId');
      
      // Создаем плейлист
      const String createPlaylistMutation = '''
        mutation CreatePlaylist(\$name: String!) {
          createPlaylist(name: \$name) {
            id
            name
            subtitle
            imageUrl
            trackCount
            userId
          }
        }
      ''';

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult createResult = await client.mutate(
        MutationOptions(
          document: gql(createPlaylistMutation),
          variables: {
            'name': name,
          },
        ),
      );

      if (createResult.hasException) {
        print('Error creating playlist: ${createResult.exception.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при создании плейлиста: ${createResult.exception.toString()}')),
        );
        return;
      }

      print('Playlist created successfully: ${createResult.data?['createPlaylist']}');
      
      // Получаем ID созданного плейлиста
      final playlistData = createResult.data?['createPlaylist'];
      if (playlistData == null) {
        print('No playlist data returned from server');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: данные плейлиста не получены')),
        );
        return;
      }
      
      final int playlistId = playlistData['id'];
      print('Using playlist ID: $playlistId');

      // Добавляем трек в созданный плейлист
      const String addTrackMutation = '''
        mutation AddTrackToPlaylist(\$playlistId: Int!, \$trackId: Int!) {
          addTrackToPlaylist(playlistId: \$playlistId, trackId: \$trackId)
        }
      ''';

      print('Adding track $trackId to playlist $playlistId');
      final QueryResult addResult = await client.mutate(
        MutationOptions(
          document: gql(addTrackMutation),
          variables: {
            'playlistId': playlistId,
            'trackId': trackId,
          },
        ),
      );

      if (addResult.hasException) {
        print('Error adding track to playlist: ${addResult.exception.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при добавлении трека в плейлист: ${addResult.exception.toString()}')),
        );
        return;
      }

      print('Track successfully added to playlist');
      
      // Обновляем список плейлистов
      _loadUserPlaylists();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Плейлист "$name" создан и трек добавлен')),
      );
    } catch (e) {
      print('Exception when creating playlist and adding track: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Произошла ошибка: $e')),
      );
    }
  }

  void _showTrackInfoDialog(BuildContext context, Track track) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Информация о треке',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Название', track.name),
              const SizedBox(height: 8),
              _infoRow('Исполнитель', track.artist),
              const SizedBox(height: 8),
              _infoRow('Длительность', _formatDuration(Duration(seconds: track.duration))),
              if (track.genre != null && track.genre!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow('Жанр', track.genre!),
              ],
              const SizedBox(height: 8),
              _infoRow('ID трека', '${track.id}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerAlternativeProvider>(
      builder: (context, audioProvider, child) {
        final track = audioProvider.currentTrack;
        final isLoading = audioProvider.isLoading;
        final isPlaying = audioProvider.isPlaying;
        final position = audioProvider.position;
        final duration = audioProvider.duration;

        return Scaffold(
          backgroundColor: Colors.black,
          body: track == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    // Background with blur
                    Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: track.coverImageUrl != null
                              ? NetworkImage(track.coverImageUrl!)
                              : const AssetImage('assets/images/default_cover.jpg') as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                    ),
                    
                    // Content
                    SafeArea(
                      child: Column(
                        children: [
                          // App bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const Text(
                                  'NOW PLAYING',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.white),
                                  onPressed: () {
                                    _showOptionsBottomSheet(context, track);
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          // Album art
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(30.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      spreadRadius: 1,
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  image: DecorationImage(
                                    image: track.coverImageUrl != null
                                      ? NetworkImage(track.coverImageUrl!)
                                      : const AssetImage('assets/images/default_cover.jpg') as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Track info
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 30.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              track.artist,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          track.isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: track.isLiked ? Colors.green : Colors.white,
                                          size: 30,
                                        ),
                                        onPressed: () => _toggleFavorite(track, audioProvider),
                                      ),
                                    ],
                                  ),
                                  
                                  // Progress slider
                                  const SizedBox(height: 30),
                                  Slider(
                                    value: position.inSeconds.toDouble(),
                                    min: 0,
                                    max: duration.inSeconds.toDouble() > 0 
                                        ? duration.inSeconds.toDouble() 
                                        : 1.0,
                                    onChanged: (value) {
                                      audioProvider.seekTo(Duration(seconds: value.toInt()));
                                    },
                                    activeColor: Colors.green,
                                    inactiveColor: Colors.grey[800],
                                  ),
                                  
                                  // Time indicators
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(position),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Playback controls
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.shuffle,
                                      color: audioProvider.shuffleEnabled ? Colors.green : Colors.white,
                                    ),
                                    onPressed: () {
                                      // Обновляем состояние провайдера вместо локального состояния
                                      audioProvider.toggleShuffleMode();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(audioProvider.shuffleEnabled 
                                            ? 'Перемешивание включено' 
                                            : 'Перемешивание выключено'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                                    onPressed: () {
                                      // Используем метод провайдера вместо сообщения
                                      audioProvider.playPreviousTrack();
                                    },
                                  ),
                                  _buildPlayButton(isLoading, isPlaying, audioProvider),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                                    onPressed: () {
                                      // Используем метод провайдера вместо сообщения
                                      audioProvider.playNextTrack();
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.repeat,
                                      color: audioProvider.repeatEnabled ? Colors.green : Colors.white,
                                    ),
                                    onPressed: () {
                                      // Обновляем состояние провайдера вместо локального состояния
                                      audioProvider.toggleRepeatMode();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(audioProvider.repeatEnabled 
                                            ? 'Повтор включен' 
                                            : 'Повтор выключен'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPlayButton(bool isLoading, bool isPlaying, AudioPlayerAlternativeProvider audioProvider) {
    if (isLoading) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.withOpacity(0.7),
        ),
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      );
    }
    
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 40,
        ),
        onPressed: () => audioProvider.togglePlayPause(),
      ),
    );
  }
}