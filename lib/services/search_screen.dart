import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/MusicDataProvider.dart';
import '../providers/AudioPlayerAlternativeProvider.dart';
import '../widgets/mini_player.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  
  Map<String, dynamic> _searchResults = {
    'tracks': [],
    'playlists': [],
    'artists': [],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 2) {
      setState(() {
        _searchQuery = _searchController.text;
      });
      _performSearch(_searchQuery);
    } else if (_searchController.text.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = {
          'tracks': [],
          'playlists': [],
          'artists': [],
        };
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });

    final musicProvider = Provider.of<MusicDataProvider>(context, listen: false);
    final results = await musicProvider.searchMusic(query);
    
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerAlternativeProvider>(context);
    final currentTrack = audioProvider.currentTrack;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.green,
                    decoration: InputDecoration(
                      hintText: 'Search for tracks, artists, playlists...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.green, width: 1.0),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) _performSearch(value);
                    },
                  ),
                ),

                // Tab bar
                if (_searchQuery.isNotEmpty)
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.green,
                    tabs: const [
                      Tab(text: 'Tracks'),
                      Tab(text: 'Artists'),
                      Tab(text: 'Playlists'),
                    ],
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                  ),

                // Search results or categories
                Expanded(
                  child: _isSearching
                      ? const Center(child: CircularProgressIndicator(color: Colors.green))
                      : _searchQuery.isEmpty
                          ? _buildSearchCategories()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                // Tracks tab
                                _buildTracksResults(),
                                
                                // Artists tab
                                _buildArtistsResults(),
                                
                                // Playlists tab
                                _buildPlaylistsResults(),
                              ],
                            ),
                ),
                
                // Space for bottom navigation and mini-player
                SizedBox(height: currentTrack != null ? 130 : 60),
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
        currentIndex: 1, // Search tab
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
              // Already on search
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/library');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/account');
              break;
          }
        },
      ),
    );
  }

  // Search categories grid (when not searching)
  Widget _buildSearchCategories() {
    // Sample categories
    final categories = [
      {'name': 'Pop', 'color': Colors.pink},
      {'name': 'Rock', 'color': Colors.purple},
      {'name': 'Hip Hop', 'color': Colors.orange},
      {'name': 'Electronic', 'color': Colors.blue},
      {'name': 'R&B', 'color': Colors.red},
      {'name': 'Classical', 'color': Colors.teal},
      {'name': 'Jazz', 'color': Colors.amber},
      {'name': 'Metal', 'color': Colors.grey},
      {'name': 'Folk', 'color': Colors.brown},
      {'name': 'Indie', 'color': Colors.indigo},
    ];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Browse Categories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.0,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = categories[index]['name'] as String;
                    _performSearch(_searchController.text);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: categories[index]['color'] as Color,
                    ),
                    child: Center(
                      child: Text(
                        categories[index]['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Tracks results
  Widget _buildTracksResults() {
    final tracks = _searchResults['tracks'] as List<dynamic>;
    
    if (tracks.isEmpty) {
      return _buildEmptyResults('No tracks found');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
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
            icon: Icon(
              track['isLiked'] ? Icons.favorite : Icons.favorite_border,
              color: track['isLiked'] ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              // Toggle favorite
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

  // Artists results
  Widget _buildArtistsResults() {
    final artists = _searchResults['artists'] as List<dynamic>;
    
    if (artists.isEmpty) {
      return _buildEmptyResults('No artists found');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.person, color: Colors.white),
          ),
          title: Text(
            artist ?? 'Unknown Artist',
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            // Navigate to artist page
          },
        );
      },
    );
  }

  // Playlists results
  Widget _buildPlaylistsResults() {
    final playlists = _searchResults['playlists'] as List<dynamic>;
    
    if (playlists.isEmpty) {
      return _buildEmptyResults('No playlists found');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              image: playlist['imageUrl'] != null
                  ? DecorationImage(
                      image: NetworkImage(playlist['imageUrl']),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.grey[800],
            ),
            child: playlist['imageUrl'] == null
                ? const Icon(Icons.playlist_play, color: Colors.white)
                : null,
          ),
          title: Text(
            playlist['name'] ?? 'Unknown Playlist',
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${playlist['trackCount'] ?? 0} tracks',
            style: TextStyle(color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/playlist',
              arguments: {'playlistId': playlist['id']},
            );
          },
        );
      },
    );
  }

  // Empty results
  Widget _buildEmptyResults(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: Colors.grey[700], size: 70),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}