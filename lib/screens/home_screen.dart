import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../core/responsive_breakpoints.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/player/playback_cubit.dart';
import '../providers/music_data_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MusicDataProvider>().loadAllData();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 500) {
      context.read<MusicDataProvider>().loadMoreTracks();
    }
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
      return 'Доброе утро';
    } else if (hour < 17) {
      return 'Добрый день';
    } else {
      return 'Добрый вечер';
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackCubit>().state;
    final musicProvider = Provider.of<MusicDataProvider>(context);
    final currentTrack = playback.currentTrack;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
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
                  AppTheme.accent.withValues(alpha: 0.3),
                  AppTheme.canvas.withValues(alpha: 0.95),
                  AppTheme.canvas,
                ],
                stops: [0.0, 0.2, 0.5],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: musicProvider.loadAllData,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: _showAppBarBackground
                        ? AppTheme.canvas.withValues(alpha: 0.9)
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
                        tooltip: 'Концертные площадки',
                        icon: const Icon(
                          Icons.map_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () => context.push('/venues'),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          context.push('/notifications');
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                        ),
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
                        if (musicProvider.errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              musicProvider.errorMessage,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),

                        // Recently Played Tracks
                        const SizedBox(height: 32),
                        CategoryHeader(
                          title: 'Недавно прослушано',
                          onSeeAllPressed: () {
                            context.push('/library');
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildRecentlyPlayed(context),

                        // Made For You
                        const SizedBox(height: 32),
                        CategoryHeader(
                          title: 'Для вас',
                          onSeeAllPressed: () {
                            // Navigate to made for you screen
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildMadeForYou(context),

                        const SizedBox(height: 32),
                        const CategoryHeader(title: 'Каталог музыки'),
                        const SizedBox(height: 16),
                        _buildTrackCatalog(context),

                        // Popular Artists
                        const SizedBox(height: 32),
                        CategoryHeader(
                          title: 'Популярные исполнители',
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

  Widget _buildRecentGrid(BuildContext context) {
    // Curated entry points into the user's real library and catalog.
    final items = [
      {'name': 'Избранное', 'color': Colors.pink[800], 'icon': Icons.favorite},
      {
        'name': 'Недавно прослушано',
        'color': Colors.indigo[600],
        'icon': Icons.history,
      },
      {
        'name': 'Популярные треки',
        'color': Colors.orange[800],
        'icon': Icons.trending_up,
      },
      {
        'name': 'Новые релизы',
        'color': Colors.blue[600],
        'icon': Icons.new_releases,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: responsiveGridColumns(constraints.maxWidth),
          childAspectRatio: constraints.maxWidth >= 1000 ? 3.2 : 2.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              if (index < 2) {
                context.go('/library');
              } else {
                context.go('/search');
              }
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
      ),
    );
  }

  Widget _buildRecentlyPlayed(BuildContext context) {
    final musicProvider = Provider.of<MusicDataProvider>(context);
    final recentlyPlayed = musicProvider.recentlyPlayed;

    if (musicProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (recentlyPlayed.isEmpty) {
      return const Center(
        child: Text(
          'Пока нет прослушанных треков',
          style: TextStyle(color: AppTheme.mutedText),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentlyPlayed.length,
        itemBuilder: (context, index) {
          final track = recentlyPlayed[index];
          return TrackListItem(
            id: track['id'],
            title: track['name'] ?? 'Unknown Track',
            artist: track['artist'] ?? 'Unknown Artist',
            coverUrl: track['coverImageUrl'],
            onTap: () {
              context.push('/player/${track['id']}');
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
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (playlists.isEmpty) {
      return const Center(
        child: Text(
          'Подборки пока не добавлены',
          style: TextStyle(color: AppTheme.mutedText),
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
            subtitle: playlist.subtitle ?? 'Подборка Musico',
            imageUrl: playlist.imageUrl,
            onTap: () {
              context.push('/playlist/${playlist.id}');
            },
          );
        },
      ),
    );
  }

  Widget _buildTrackCatalog(BuildContext context) {
    final provider = context.watch<MusicDataProvider>();
    if (provider.tracks.isEmpty) {
      return Text(
        provider.errorMessage.isNotEmpty
            ? provider.errorMessage
            : 'Каталог пока пуст.',
        style: const TextStyle(color: AppTheme.mutedText),
      );
    }
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.tracks.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= provider.tracks.length) {
            return const SizedBox(
              width: 72,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final track = provider.tracks[index];
          return TrackListItem(
            id: track['id'],
            title: track['name'] as String? ?? 'Unknown Track',
            artist: track['artist'] as String? ?? 'Unknown Artist',
            coverUrl: track['coverImageUrl'] as String?,
            onTap: () async {
              await context.read<PlaybackCubit>().playTracks(
                provider.tracks,
                track['id'] as int,
              );
              if (context.mounted) {
                context.push('/player/${track['id']}');
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildPopularArtists(BuildContext context) {
    final artists = context
        .watch<MusicDataProvider>()
        .tracks
        .map((track) => track['artist'] as String? ?? '')
        .where((artist) => artist.isNotEmpty)
        .toSet()
        .toList();
    if (artists.isEmpty) {
      return const Text(
        'Добавьте треки в каталог, чтобы увидеть исполнителей.',
        style: TextStyle(color: AppTheme.mutedText),
      );
    }
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppTheme.elevatedSurface,
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: AppTheme.mutedText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  artists[index],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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
