import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/player/playback_cubit.dart';
import '../providers/music_data_provider.dart';
import '../widgets/mini_player.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _debounce;
  int _searchVersion = 0;
  String _searchNotice = '';
  bool _identityInitialized = false;
  String? _observedUserId;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final music = context.read<MusicDataProvider>();
      if (music.isSignedIn) music.loadFavoriteTracks();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<MusicDataProvider>().currentUserId;
    if (_identityInitialized && userId != _observedUserId) {
      _debounce?.cancel();
      _searchVersion++;
      _searchController.removeListener(_onSearchChanged);
      _searchController.clear();
      _searchController.addListener(_onSearchChanged);
      _searchQuery = '';
      _searchNotice = '';
      _isSearching = false;
      _searchResults = {'tracks': [], 'playlists': [], 'artists': []};
    }
    _identityInitialized = true;
    _observedUserId = userId;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    final version = ++_searchVersion;
    setState(() {
      _searchQuery = query.length >= 2 ? query : '';
      _isSearching = query.length >= 2;
      _searchNotice = '';
      _searchResults = {'tracks': [], 'playlists': [], 'artists': []};
    });
    if (query.length < 2) return;
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _performSearch(query, version),
    );
  }

  void _submitSearch(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) return;
    final version = ++_searchVersion;
    setState(() {
      _searchQuery = query;
      _isSearching = true;
      _searchNotice = '';
    });
    _performSearch(query, version);
  }

  Future<void> _performSearch(String query, int version) async {
    if (!mounted || version != _searchVersion) return;
    final music = context.read<MusicDataProvider>();
    final userId = music.currentUserId;
    final results = await music.searchMusic(query);
    if (!mounted || version != _searchVersion || userId != music.currentUserId)
      return;
    setState(() {
      _searchResults = results;
      _searchNotice = music.errorMessage;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackCubit>().state;
    final currentTrack = playback.currentTrack;

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
                    onSubmitted: _submitSearch,
                  ),
                ),

                if (_searchNotice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _searchNotice,
                      style: const TextStyle(color: Colors.amber),
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
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.green),
                        )
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
                isPlaying: playback.isPlaying,
                isLoading: playback.isLoading,
                onTap: () {
                  context.push('/player/${currentTrack.id}');
                },
                onPlayPause: () {
                  context.read<PlaybackCubit>().togglePlayPause();
                },
              ),
            ),
        ],
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
                    _searchController.text =
                        categories[index]['name'] as String;
                    _submitSearch(_searchController.text);
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
    final favoriteIds = context
        .watch<MusicDataProvider>()
        .favoriteTracks
        .map((track) => track['id'])
        .toSet();

    if (tracks.isEmpty) {
      return _buildEmptyResults('No tracks found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isFavorite = favoriteIds.contains(track['id']);
        return ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              image:
                  (track['coverImageUrl'] ?? track['cover_image_url']) != null
                  ? DecorationImage(
                      image: NetworkImage(
                        track['coverImageUrl'] ?? track['cover_image_url'],
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.grey[800],
            ),
            child: (track['coverImageUrl'] ?? track['cover_image_url']) == null
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
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.green : Colors.grey,
            ),
            onPressed: () async {
              await context.read<MusicDataProvider>().toggleFavorite(
                track['id'] as int,
              );
              if (!mounted) return;
              final music = context.read<MusicDataProvider>();
              if (music.errorMessage.isNotEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(music.errorMessage)));
                return;
              }
            },
          ),
          onTap: () {
            context.read<PlaybackCubit>().playTracks(
              List<Map<String, dynamic>>.from(_searchResults['tracks'] as List),
              track['id'] as int,
            );
            context.push('/player/${track['id']}');
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
            _searchController.text = artist as String;
            _tabController?.animateTo(0);
            _submitSearch(artist);
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
              image: (playlist['imageUrl'] ?? playlist['image_url']) != null
                  ? DecorationImage(
                      image: NetworkImage(
                        playlist['imageUrl'] ?? playlist['image_url'],
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.grey[800],
            ),
            child: (playlist['imageUrl'] ?? playlist['image_url']) == null
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
            '${playlist['trackCount'] ?? playlist['track_count'] ?? 0} tracks',
            style: TextStyle(color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            context.push('/playlist/${playlist['id']}');
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
