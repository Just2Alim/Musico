import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../graphql/graphql_config.dart';
import '../providers/AudioPlayerAlternativeProvider.dart';
import '../widgets/mini_player.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoading = true;
  int? _userId;
  List<dynamic> _playlists = [];
  List<dynamic> _favoriteTracks = [];
  List<dynamic> _recentlyPlayed = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getUserId().then((_) {
      _loadUserPlaylists();
      _loadFavoriteTracks();
      _loadRecentlyPlayed();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('userId');
    });
    
    if (_userId == null) {
      // Redirect to login if user is not authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

Future<void> _loadUserPlaylists() async {
  if (_userId == null) {
    print('_loadUserPlaylists: userId is null');
    return;
  }

  print('Loading playlists for userId: $_userId');

  // Проверка токена
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  print('Auth token available: ${token != null}');

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
      'userId': _userId,
    },
    fetchPolicy: FetchPolicy.networkOnly, // Обязательно получаем свежие данные
  );

  try {
    final GraphQLClient client = GraphQLConfig.initClient();
    print('GraphQL client initialized');
    
    final QueryResult result = await client.query(options);
    print('Query executed');

    if (result.hasException) {
      print('Error in query: ${result.exception?.toString()}');
      _showError('Error loading playlists: ${result.exception.toString()}');
    } else {
      print('Query result: ${result.data}');
      final playlists = result.data?['playlists'];
      print('Playlists received: $playlists');
      
      setState(() {
        _playlists = playlists ?? [];
      });
      
      print('Playlists state updated: $_playlists');
    }
  } catch (e) {
    print('Exception in _loadUserPlaylists: $e');
    _showError('Failed to load playlists: $e');
  } finally {
    _updateLoadingState();
  }
}

Future<void> _loadFavoriteTracks() async {
  if (_userId == null) {
    print('_loadFavoriteTracks: userId is null');
    return;
  }

  print('Loading favorite tracks for userId: $_userId');

  // Изменим запрос, чтобы передавать userId в параметрах
  const String favoritesQuery = '''
    query GetFavoriteTracks(\$userId: Int!) {
      favoriteTracks(userId: \$userId) {
        id
        addedAt
        track {
          id
          name
          artist
          duration
          coverImageUrl
        }
      }
    }
  ''';

  final QueryOptions options = QueryOptions(
    document: gql(favoritesQuery),
    variables: {
      'userId': _userId, // Передаем userId в запрос
    },
    fetchPolicy: FetchPolicy.networkOnly, // Отключаем кэширование для получения актуальных данных
  );

  try {
    final GraphQLClient client = GraphQLConfig.initClient();
    print('GraphQL client initialized for favorites');
    
    final QueryResult result = await client.query(options);
    print('Favorites query executed');

    if (result.hasException) {
      print('Error in favorites query: ${result.exception?.toString()}');
      _showError('Error loading favorite tracks: ${result.exception.toString()}');
    } else {
      print('Favorites query result: ${result.data}');
      final favoriteTracks = result.data?['favoriteTracks'];
      print('Favorite tracks received: $favoriteTracks');
      
      setState(() {
        _favoriteTracks = favoriteTracks ?? [];
      });
      
      print('Favorite tracks state updated: $_favoriteTracks');
    }
  } catch (e) {
    print('Exception in _loadFavoriteTracks: $e');
    _showError('Failed to load favorite tracks: $e');
  } finally {
    _updateLoadingState();
  }
}

  Future<void> _loadRecentlyPlayed() async {
    if (_userId == null) return;

    const String recentQuery = '''
      query GetRecentlyPlayed {
        recentlyPlayed(limit: 20) {
          id
          listenedAt
          track {
            id
            name
            artist
            duration
            coverImageUrl
          }
        }
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(recentQuery),
    );

    final GraphQLClient client = GraphQLConfig.initClient();
    final QueryResult result = await client.query(options);

    if (result.hasException) {
      _showError('Error loading recently played: ${result.exception.toString()}');
    } else {
      setState(() {
        _recentlyPlayed = result.data?['recentlyPlayed'] ?? [];
      });
    }
    
    _updateLoadingState();
  }

  void _updateLoadingState() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _createNewPlaylist() async {
    if (_userId == null) return;

    // Показываем диалоговое окно для ввода имени плейлиста
    final TextEditingController nameController = TextEditingController();
    final String? playlistName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Create New Playlist',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, nameController.text),
              child: const Text('Create', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );

    // Проверяем, было ли введено имя плейлиста
    if (playlistName == null || playlistName.isEmpty) return;

    // Создаем плейлист в бэкенде
    const String createPlaylistMutation = '''
      mutation CreatePlaylist(\$name: String!) {
        createPlaylist(name: \$name) {
          id
          name
          subtitle
          imageUrl
          userId
          trackCount
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(createPlaylistMutation),
      variables: {
        'name': playlistName,  // Здесь используется playlistName, а не name
      },
    );

    setState(() => _isLoading = true);
    
    try {
      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.mutate(options);

      if (result.hasException) {
        print('Error creating playlist: ${result.exception.toString()}');
        _showError('Error creating playlist: ${result.exception.toString()}');
      } else {
        // Обновляем список плейлистов
        _loadUserPlaylists();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist "$playlistName" created successfully')),
        );
      }
    } catch (e) {
      print('Exception during playlist creation: $e');
      _showError('An error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    final int minutes = duration.inMinutes;
    final int remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerAlternativeProvider>(context);
    final currentTrack = audioProvider.currentTrack;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Your Library',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.green,
          tabs: const [
            Tab(text: 'Playlists'),
            Tab(text: 'Favorites'),
            Tab(text: 'Recently Played'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      floatingActionButton: _tabController?.index == 0
          ? FloatingActionButton(
              onPressed: _createNewPlaylist,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            )
          : null,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : _userId == null
                  ? const Center(
                      child: Text(
                        'Please log in to view your library',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.only(bottom: currentTrack != null ? 80 : 0),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Playlists tab
                          _buildPlaylistsTab(),
                          
                          // Favorites tab
                          _buildFavoritesTab(),
                          
                          // Recently played tab
                          _buildRecentlyPlayedTab(),
                        ],
                      ),
                    ),
          
          // Mini Player
          if (currentTrack != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60, // Space for bottom navigation
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 2, // Library tab
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/search');
              break;
            case 2:
              // Already on library
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/account');
              break;
          }
        },
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    if (_playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_play, color: Colors.grey[700], size: 70),
            const SizedBox(height: 16),
            Text(
              'No playlists yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _createNewPlaylist,
              child: const Text('Create a playlist', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/playlist',
              arguments: {'playlistId': playlist['id']},
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: playlist['imageUrl'] != null
                        ? DecorationImage(
                            image: NetworkImage(playlist['imageUrl']),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey[900],
                  ),
                  child: playlist['imageUrl'] == null
                      ? const Center(
                          child: Icon(Icons.music_note, color: Colors.white, size: 50),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                playlist['name'] ?? 'Untitled Playlist',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${playlist['trackCount'] ?? 0} tracks',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    if (_favoriteTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, color: Colors.grey[700], size: 70),
            const SizedBox(height: 16),
            Text(
              'No favorite tracks yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Discover music', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _favoriteTracks.length,
      itemBuilder: (context, index) {
        final favorite = _favoriteTracks[index];
        final track = favorite['track'];
        
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
            track['name'] ?? 'Unknown Track',
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track['artist'] ?? 'Unknown Artist',
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
                icon: const Icon(Icons.favorite, color: Colors.green),
                onPressed: () {
                  // Unlike track logic (would need to implement)
                },
              ),
            ],
          ),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/player',
              arguments: {'trackId': track['id']},
            );
          },
        );
      },
    );
  }

Widget _buildRecentlyPlayedTab() {
  if (_recentlyPlayed.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, color: Colors.grey[700], size: 70),
          const SizedBox(height: 16),
          Text(
            'No recently played tracks',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: const Text('Discover music', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }
  
  return ListView.builder(
    itemCount: _recentlyPlayed.length,
    itemBuilder: (context, index) {
      final history = _recentlyPlayed[index];
      final track = history['track'];
      
      // Просто используем "Recently" вместо попыток обработать дату
      String timeAgo = 'Recently';
      
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
          track['name'] ?? 'Unknown Track',
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track['artist'] ?? 'Unknown Artist',
          style: TextStyle(color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_filled, color: Colors.green),
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/player',
              arguments: {'trackId': track['id']},
            );
          },
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/player',
            arguments: {'trackId': track['id']},
          );
        },
      );
    },
  );
}
}