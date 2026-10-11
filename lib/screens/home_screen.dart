import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/AudioPlayerAlternativeProvider.dart';
import '../providers/MusicDataProvider.dart';
import '../widgets/mini_player.dart';
import '../widgets/category_header.dart';
import '../widgets/album_card.dart';
import '../widgets/track_list_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarBackground = false;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.offset > 80 && !_showAppBarBackground) {
      setState(() {
        _showAppBarBackground = true;
      });
    } else if (_scrollController.offset <= 80 && _showAppBarBackground) {
      setState(() {
        _showAppBarBackground = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerAlternativeProvider>(context);
    final musicProvider = Provider.of<MusicDataProvider>(context);
    final currentTrack = audioProvider.currentTrack;
    final screenSize = MediaQuery.of(context).size;
    
    // Load data if necessary
    if (musicProvider.featuredPlaylists.isEmpty &&
        !musicProvider.isLoading) {
      musicProvider.loadAllData();
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient background
          Container(
            width: screenSize.width,
            height: screenSize.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1DB954).withOpacity(0.8), // Green tint
                  Colors.black.withOpacity(0.95),
                  Colors.black,
                ],
                stops: [0.0, 0.2, 0.5],
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverAppBar(
                  backgroundColor: _showAppBarBackground 
                      ? Colors.black.withOpacity(0.9)
                      : Colors.transparent,
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  expandedHeight: 100,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      _getGreeting(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    titlePadding: EdgeInsets.only(left: 20, bottom: 16),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () {
                        // Notifications action
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      onPressed: () {
                        // Settings action
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                
                // Main content
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Recent Playlists (2x2 grid)
                      const SizedBox(height: 16),
                      _buildRecentGrid(context),
                      
                      // Recently Played Tracks
                      const SizedBox(height: 32),
                      CategoryHeader(
                        title: 'Recently Played',
                        onSeeAllPressed: () {
                          Navigator.pushNamed(context, '/library');
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildRecentlyPlayed(context),
                      
                      // Made For You
                      const SizedBox(height: 32),
                      CategoryHeader(
                        title: 'Made For You',
                        onSeeAllPressed: () {
                          // Navigate to made for you screen
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildMadeForYou(context),
                      
                      // Popular Artists
                      const SizedBox(height: 32),
                      CategoryHeader(
                        title: 'Popular Artists',
                        onSeeAllPressed: () {
                          // Navigate to artists screen
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPopularArtists(context),
                      
                      // Spacing for mini player and bottom navigation
                      SizedBox(height: currentTrack != null ? 140 : 80),
                    ]),
                  ),
                ),
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
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              // Already home
              break;
            case 1:
              Navigator.pushNamed(context, '/search');
              break;
            case 2:
              Navigator.pushNamed(context, '/library');
              break;
            case 3:
              Navigator.pushNamed(context, '/account');
              break;
          }
        },
      ),
    );
  }

  Widget _buildRecentGrid(BuildContext context) {
    // Sample data
    final items = [
      {'name': 'Liked Songs', 'color': Colors.pink[800], 'icon': Icons.favorite},
      {'name': 'Recently Played', 'color': Colors.indigo[600], 'icon': Icons.history},
      {'name': 'Top Tracks', 'color': Colors.orange[800], 'icon': Icons.trending_up},
      {'name': 'New Releases', 'color': Colors.blue[600], 'icon': Icons.new_releases},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            // Navigate to the corresponding screen
          },
          child: Container(
            decoration: BoxDecoration(
              color: items[index]['color'] as Color?,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    items[index]['icon'] as IconData,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                Expanded(
                  child: Text(
                    items[index]['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentlyPlayed(BuildContext context) {
    final musicProvider = Provider.of<MusicDataProvider>(context);
    final recentlyPlayed = musicProvider.recentlyPlayed;
    
    if (musicProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }
    
    if (recentlyPlayed.isEmpty) {
      return const Center(
        child: Text(
          'No recently played tracks',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentlyPlayed.length,
        itemBuilder: (context, index) {
          final item = recentlyPlayed[index];
          final track = item['track'];
          return TrackListItem(
            id: track['id'],
            title: track['name'] ?? 'Unknown Track',
            artist: track['artist'] ?? 'Unknown Artist',
            coverUrl: track['coverImageUrl'],
            onTap: () {
              Navigator.pushNamed(
                context,
                '/player',
                arguments: {'trackId': track['id']},
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMadeForYou(BuildContext context) {
    final musicProvider = Provider.of<MusicDataProvider>(context);
    final playlists = musicProvider.featuredPlaylists;
    
    if (musicProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }
    
    if (playlists.isEmpty) {
      return const Center(
        child: Text(
          'No featured playlists',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return AlbumCard(
            id: playlist.id,
            title: playlist.name,
            subtitle: playlist.subtitle ?? 'Featured Playlist',
            imageUrl: playlist.imageUrl,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/playlist',
                arguments: {'playlistId': playlist.id},
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPopularArtists(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 10,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[800],
                  child: Icon(Icons.person, size: 50, color: Colors.grey[300]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Artist ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}