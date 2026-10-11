import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../graphql/graphql_config.dart';
import '../providers/AudioPlayerAlternativeProvider.dart';
import '../widgets/mini_player.dart';

// Добавьте импорт для platform detection
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class DetailedPlaylistScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const DetailedPlaylistScreen({Key? key, required this.arguments}) : super(key: key);

  @override
  _DetailedPlaylistScreenState createState() => _DetailedPlaylistScreenState();
}

class _DetailedPlaylistScreenState extends State<DetailedPlaylistScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _playlistData;
  List<dynamic> _tracks = [];
  ScrollController _scrollController = ScrollController();
  bool _isAppBarExpanded = false;
  String? _selectedImageUrl;
  TextEditingController _imageUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlaylistData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bool isExpanded = _scrollController.offset > 150;
    if (isExpanded != _isAppBarExpanded) {
      setState(() {
        _isAppBarExpanded = isExpanded;
      });
    }
  }

  void _loadPlaylistData() async {
    final int playlistId = widget.arguments['playlistId'];
    
    const String playlistQuery = '''
      query GetPlaylist(\$playlistId: Int!) {
        playlist(playlistId: \$playlistId) {
          id
          name
          subtitle
          artist
          imageUrl
          userId
          trackCount
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
          user {
            name
          }
        }
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(playlistQuery),
      variables: {
        'playlistId': playlistId,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final GraphQLClient client = GraphQLConfig.initClient();
    final QueryResult result = await client.query(options);

    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки плейлиста: ${result.exception.toString()}')),
      );
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _playlistData = result.data?['playlist'];
      _tracks = _playlistData?['tracks'] ?? [];
      _isLoading = false;
    });
  }

  void _toggleTrackFavorite(int index) async {
    if (_tracks.isEmpty || index >= _tracks.length) return;

    final track = _tracks[index];
    final int trackId = track['id'];
    final bool currentState = track['isLiked'] ?? false;
    
    // Optimistic update
    setState(() {
      _tracks[index]['isLiked'] = !currentState;
    });

    final String mutation = currentState
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
        'trackId': trackId,
      },
    );

    final GraphQLClient client = GraphQLConfig.initClient();
    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления статуса избранного: ${result.exception.toString()}')),
      );
      // Revert on error
      setState(() {
        _tracks[index]['isLiked'] = currentState;
      });
    }
  }

  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    final int minutes = duration.inMinutes;
    final int remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Открыть диалог для редактирования плейлиста
  void _showEditPlaylistDialog() {
    if (_playlistData == null) return;
    
    final TextEditingController nameController = TextEditingController(text: _playlistData!['name']);
    final TextEditingController subtitleController = TextEditingController(text: _playlistData!['subtitle'] ?? '');
    
    if (_playlistData!['imageUrl'] != null) {
      _imageUrlController.text = _playlistData!['imageUrl'];
      _selectedImageUrl = _playlistData!['imageUrl'];
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                'Редактирование плейлиста',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Название',
                        labelStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: subtitleController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Описание',
                        labelStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Поле для URL обложки
                    TextField(
                      controller: _imageUrlController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'URL обложки',
                        labelStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            if (_imageUrlController.text.isNotEmpty) {
                              setState(() {
                                _selectedImageUrl = _imageUrlController.text;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_selectedImageUrl != null && _selectedImageUrl!.isNotEmpty)
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _selectedImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updatePlaylist(
                      nameController.text,
                      subtitleController.text,
                      _selectedImageUrl,
                    );
                    Navigator.pop(context);
                  },
                  child: Text('Сохранить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // Обновление плейлиста на сервере
  void _updatePlaylist(String name, String subtitle, String? imageUrl) async {
    if (_playlistData == null) return;
    
    setState(() => _isLoading = true);
    
    final int playlistId = _playlistData!['id'];
    
    const String mutation = '''
      mutation UpdatePlaylist(\$playlistId: Int!, \$name: String, \$subtitle: String, \$imageUrl: String) {
        updatePlaylist(playlistId: \$playlistId, name: \$name, subtitle: \$subtitle, imageUrl: \$imageUrl) {
          id
          name
          subtitle
          imageUrl
          trackCount
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {
        'playlistId': playlistId,
        'name': name,
        'subtitle': subtitle.isEmpty ? null : subtitle,
        'imageUrl': imageUrl,
      },
    );

    final GraphQLClient client = GraphQLConfig.initClient();
    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления плейлиста: ${result.exception.toString()}')),
      );
    } else {
      // Обновляем данные плейлиста
      setState(() {
        _playlistData!['name'] = name;
        _playlistData!['subtitle'] = subtitle.isEmpty ? null : subtitle;
        if (imageUrl != null) {
          _playlistData!['imageUrl'] = imageUrl;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Плейлист успешно обновлен')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  // Получение миниатюр обложек треков для плейлиста без обложки
  String? _getFirstTrackCoverUrl() {
    if (_tracks.isEmpty) return null;
    
    for (var track in _tracks) {
      if (track['coverImageUrl'] != null && track['coverImageUrl'].isNotEmpty) {
        return track['coverImageUrl'];
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerAlternativeProvider>(context);
    final currentTrack = audioProvider.currentTrack;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : _playlistData == null
                  ? const Center(child: Text('Плейлист не найден', style: TextStyle(color: Colors.white)))
                  : CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Flexible app bar with playlist image and info
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          expandedHeight: 300,
                          pinned: true,
                          stretch: true,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Background image with blur effect
                              _playlistData?['imageUrl'] != null
                                  ? Image.network(
                                      _playlistData?['imageUrl'] ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _getFirstTrackCoverUrl() != null 
                                          ? Image.network(
                                              _getFirstTrackCoverUrl()!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[900],
                                                  child: const Icon(
                                                    Icons.library_music,
                                                    color: Colors.white,
                                                    size: 100,
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              color: Colors.grey[900],
                                              child: const Icon(
                                                Icons.library_music,
                                                color: Colors.white,
                                                size: 100,
                                              ),
                                            );
                                      },
                                    )
                                  : _getFirstTrackCoverUrl() != null 
                                      ? Image.network(
                                          _getFirstTrackCoverUrl()!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[900],
                                              child: const Icon(
                                                Icons.library_music,
                                                color: Colors.white,
                                                size: 100,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[900],
                                          child: const Icon(
                                            Icons.library_music,
                                            color: Colors.white,
                                            size: 100,
                                          ),
                                        ),
                                // Gradient overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.3),
                                        Colors.black.withOpacity(0.5),
                                        Colors.black.withOpacity(0.8),
                                        Colors.black,
                                      ],
                                    ),
                                  ),
                                ),
                                // Playlist info
                                Positioned(
                                  left: 20,
                                  bottom: 20,
                                  right: 20,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _playlistData?['name'] ?? 'Без названия',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_playlistData!['subtitle'] != null)
                                        Text(
                                          _playlistData!['subtitle'],
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (_playlistData!['user'] != null)
                                            Text(
                                              'Создан ${_playlistData!['user']['name']}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${_playlistData!['trackCount'] ?? _tracks.length} треков',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onPressed: () {
                                // Показать меню опций плейлиста
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.grey[900],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  builder: (context) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.edit, color: Colors.white),
                                          title: Text('Редактировать плейлист', style: TextStyle(color: Colors.white)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _showEditPlaylistDialog();
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.share, color: Colors.white),
                                          title: Text('Поделиться', style: TextStyle(color: Colors.white)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Функция "Поделиться" будет доступна позже')),
                                            );
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.delete, color: Colors.red),
                                          title: Text('Удалить плейлист', style: TextStyle(color: Colors.red)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _showDeleteConfirmationDialog();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                        
                        // Action buttons
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    // Play all tracks
                                    if (_tracks.isNotEmpty) {
                                      audioProvider.loadAndPlayPlaylist(_playlistData!['id']);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text('Воспроизвести', style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.shuffle, color: Colors.white),
                                  onPressed: () {
                                    // Shuffle and play
                                    if (_tracks.isNotEmpty) {
                                      audioProvider.toggleShuffleMode();
                                      audioProvider.loadAndPlayPlaylist(_playlistData!['id']);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Track list
                        _tracks.isEmpty
                            ? const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: Text(
                                      'В этом плейлисте нет треков',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final track = _tracks[index];
                                    return ListTile(
                                      leading: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(5),
                                          image: track['coverImageUrl'] != null
                                              ? DecorationImage(
                                                  image: NetworkImage(track['coverImageUrl']),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                          color: Colors.grey[800],
                                        ),
                                        child: track['coverImageUrl'] == null
                                            ? const Icon(Icons.music_note, color: Colors.white)
                                            : null,
                                      ),
                                      title: Text(
                                        track['name'] ?? 'Неизвестный трек',
                                        style: const TextStyle(color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        track['artist'] ?? 'Неизвестный исполнитель',
                                        style: TextStyle(color: Colors.grey[600]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatDuration(track['duration'] ?? 0),
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              track['isLiked'] ? Icons.favorite : Icons.favorite_border,
                                              color: track['isLiked'] ? Colors.green : Colors.grey,
                                            ),
                                            onPressed: () => _toggleTrackFavorite(index),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        audioProvider.loadAndPlayPlaylist(
                                          _playlistData!['id'],
                                          startTrackId: track['id']
                                        );
                                      },
                                    );
                                  },
                                  childCount: _tracks.length,
                                ),
                              ),
                              
                        // Bottom padding for mini player
                        SliverToBoxAdapter(
                          child: SizedBox(height: currentTrack != null ? 80 : 20),
                        ),
                      ],
                    ),
          
          // Mini Player
          if (currentTrack != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(
                trackName: currentTrack.name,
                artistName: currentTrack.artist,
                coverImageUrl: currentTrack.coverImageUrl,
                isPlaying: audioProvider.isPlaying,
                isLoading: audioProvider.isLoading,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/player',
                    arguments: {'trackId': currentTrack.id},
                  );
                },
                onPlayPause: () {
                  audioProvider.togglePlayPause();
                },
              ),
            ),
        ],
      ),
    );
  }

  // Показать диалог подтверждения удаления плейлиста
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Удалить плейлист?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Вы действительно хотите удалить плейлист "${_playlistData!['name']}"? Это действие нельзя отменить.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlaylist();
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Удаление плейлиста
  void _deletePlaylist() async {
    if (_playlistData == null) return;
    
    setState(() => _isLoading = true);
    
    const String mutation = '''
      mutation DeletePlaylist(\$playlistId: Int!) {
        deletePlaylist(playlistId: \$playlistId)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {
        'playlistId': _playlistData!['id'],
      },
    );

    final GraphQLClient client = GraphQLConfig.initClient();
    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления плейлиста: ${result.exception.toString()}')),
      );
      setState(() => _isLoading = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Плейлист удален')),
      );
      Navigator.pop(context); // Возврат на предыдущий экран
    }
  }
}