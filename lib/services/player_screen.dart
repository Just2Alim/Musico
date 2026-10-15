import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/audio_player_provider.dart';
import '../features/player/playback_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/music_repository.dart';
import '../widgets/music_credit.dart';
import '../widgets/playback_progress.dart';
import '../widgets/track_artwork.dart';

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const PlayerScreen({Key? key, required this.arguments}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
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
    // Supabase manages the persisted authentication session.
  }

  void _loadTrack() {
    final int trackId = widget.arguments['trackId'];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final playback = context.read<PlaybackCubit>();
      // A selected search result may already be playing from an external
      // catalog. Re-fetching it by ID would incorrectly query Supabase.
      if (playback.state.currentTrack?.id != trackId) {
        playback.loadTrackById(trackId);
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _toggleFavorite(
    Track track,
    AudioPlayerAlternativeProvider provider,
  ) async {
    await provider.toggleFavorite();
    if (!mounted || provider.errorMessage.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(provider.errorMessage)));
  }

  Future<void> _loadUserPlaylists() async {
    setState(() {
      _isLoadingPlaylists = true;
    });

    try {
      // Read playlists for the active Supabase user.
      final playlists = await context.read<MusicRepository>().playlists(
        ownerId: Supabase.instance.client.auth.currentUser?.id,
      );
      if (!mounted) return;
      _userPlaylists = playlists;
    } catch (e) {
      if (!mounted) return;
      print('Exception in _loadUserPlaylists: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load playlists: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoadingPlaylists = false);
      }
    }
  }

  Future<void> _addToPlaylist(int trackId, int playlistId) async {
    try {
      print('Adding track $trackId to playlist $playlistId');

      await context.read<MusicRepository>().addTrack(playlistId, trackId);
      if (!mounted) return;
      {
        print('Track successfully added to playlist');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Трек добавлен в плейлист')));
        Navigator.pop(context); // Закрываем bottom sheet
      }
    } catch (e) {
      if (!mounted) return;
      print('Exception when adding track to playlist: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Произошла ошибка: $e')));
    }
  }

  void _showOptionsBottomSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
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
                  const Divider(color: AppTheme.mutedText),
                  if (MusicCredit.supports(track))
                    ListTile(
                      leading: const Icon(Icons.copyright, color: Colors.white),
                      title: const Text(
                        'Авторство и лицензия',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Kevin MacLeod · CC BY 4.0',
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Авторство и лицензия'),
                          content: SingleChildScrollView(
                            child: MusicCredit(track: track),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Закрыть'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.queue_music, color: Colors.white),
                    title: const Text(
                      'В очередь воспроизведения',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      // Добавляем трек в очередь воспроизведения
                      Provider.of<AudioPlayerAlternativeProvider>(
                        context,
                        listen: false,
                      ).addToQueue(track);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Трек добавлен в очередь воспроизведения',
                          ),
                        ),
                      );
                    },
                  ),
                  if (track.source == 'supabase')
                    Consumer<AudioPlayerAlternativeProvider>(
                      builder: (context, provider, child) {
                        return ListTile(
                          leading: Icon(
                            track.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: track.isLiked
                                ? AppTheme.accent
                                : Colors.white,
                          ),
                          title: Text(
                            track.isLiked
                                ? 'Удалить из избранного'
                                : 'Добавить в избранное',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () async {
                            await _toggleFavorite(track, provider);
                            if (context.mounted) Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.share, color: Colors.white),
                    title: const Text(
                      'Поделиться',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      // Логика для функции "Поделиться"
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Функция "Поделиться" будет доступна в ближайшем обновлении',
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Информация о треке',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      // Логика для функции "Информация о треке"
                      Navigator.pop(context);
                      _showTrackInfoDialog(context, track);
                    },
                  ),
                  if (track.source == 'supabase')
                    ListTile(
                      leading: const Icon(
                        Icons.playlist_add,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Добавить в плейлист',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        // Закрываем текущий bottom sheet
                        Navigator.pop(context);

                        // Открываем новый bottom sheet для выбора плейлиста
                        _showAddToPlaylistBottomSheet(context, track);
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddToPlaylistBottomSheet(
    BuildContext unused,
    Track track,
  ) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Войдите, чтобы добавлять треки в плейлисты.'),
        ),
      );
      return;
    }
    await _loadUserPlaylists();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
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
                const Divider(color: AppTheme.mutedText),

                // Опция создания нового плейлиста
                ListTile(
                  leading: const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.accent,
                  ),
                  title: const Text(
                    'Создать новый плейлист',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePlaylistDialog(context, track);
                  },
                ),

                const Divider(color: AppTheme.mutedText),

                // Список существующих плейлистов
                Expanded(
                  child: _isLoadingPlaylists
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.accent,
                          ),
                        )
                      : _userPlaylists.isEmpty
                      ? const Center(
                          child: Text(
                            'У вас пока нет плейлистов',
                            style: TextStyle(color: AppTheme.mutedText),
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
                                          image: NetworkImage(
                                            playlist['imageUrl'],
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: AppTheme.elevatedSurface,
                                ),
                                child: playlist['imageUrl'] == null
                                    ? const Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                        size: 24,
                                      )
                                    : null,
                              ),
                              title: Text(
                                playlist['name'] ?? 'Без названия',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${playlist['track_count'] ?? playlist['trackCount'] ?? 0} треков',
                                style: TextStyle(color: AppTheme.mutedText),
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

  void _showCreatePlaylistDialog(BuildContext unused, Track track) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'Создать плейлист',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Название плейлиста',
              hintStyle: TextStyle(color: AppTheme.mutedText),
              filled: true,
              fillColor: AppTheme.elevatedSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Отмена',
                style: TextStyle(color: AppTheme.mutedText),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  // Создаем плейлист и добавляем в него трек
                  await _createPlaylistAndAddTrack(
                    nameController.text.trim(),
                    track.id,
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text(
                'Создать',
                style: TextStyle(color: AppTheme.accent),
              ),
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
      final playlistId = await context.read<MusicRepository>().createPlaylist(
        name,
      );
      await context.read<MusicRepository>().addTrack(playlistId, trackId);
      if (!mounted) return;

      // Обновляем список плейлистов
      _loadUserPlaylists();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Плейлист "$name" создан и трек добавлен')),
      );
    } catch (e) {
      if (!mounted) return;
      print('Exception when creating playlist and adding track: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Произошла ошибка: $e')));
    }
  }

  void _showTrackInfoDialog(BuildContext unused, Track track) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
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
              _infoRow(
                'Длительность',
                _formatDuration(Duration(seconds: track.duration)),
              ),
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
              child: const Text(
                'Закрыть',
                style: TextStyle(color: AppTheme.accent),
              ),
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
            color: AppTheme.mutedText,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      builder: (context, playback) {
        final track = playback.currentTrack;
        final isLoading = playback.isLoading;
        final isPlaying = playback.isPlaying;
        final position = playback.position;
        final duration = playback.duration;

        return Scaffold(
          backgroundColor: AppTheme.canvas,
          body: track == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (playback.errorMessage.isEmpty)
                        const CircularProgressIndicator()
                      else ...[
                        Text(playback.errorMessage),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              context.read<PlaybackCubit>().loadTrackById(
                                widget.arguments['trackId'] as int,
                              ),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Background with blur
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff174c43), Color(0xff15131e)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          color: AppTheme.canvas.withValues(alpha: 0.7),
                        ),
                      ),
                    ),

                    // Content
                    SafeArea(
                      child: Column(
                        children: [
                          // App bar
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 30,
                                  ),
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
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                  ),
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
                                      color: AppTheme.canvas.withValues(
                                        alpha: 0.3,
                                      ),
                                      spreadRadius: 1,
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xff287b65),
                                      Color(0xff292040),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: TrackArtwork(
                                  imageUrl: track.coverImageUrl,
                                  title: track.name,
                                  artist: track.artist,
                                  borderRadius: 15,
                                  showLabel: false,
                                ),
                              ),
                            ),
                          ),

                          // Track info
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                color: AppTheme.mutedText,
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
                                          track.isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: track.isLiked
                                              ? AppTheme.accent
                                              : Colors.white,
                                          size: 30,
                                        ),
                                        onPressed: () => _toggleFavorite(
                                          track,
                                          context
                                              .read<
                                                AudioPlayerAlternativeProvider
                                              >(),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Progress slider
                                  const SizedBox(height: 30),
                                  PlaybackProgress(
                                    position: position,
                                    duration: duration,
                                    onSeek: context
                                        .read<PlaybackCubit>()
                                        .seekTo,
                                  ),

                                  // Time indicators
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(position),
                                          style: const TextStyle(
                                            color: AppTheme.mutedText,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: const TextStyle(
                                            color: AppTheme.mutedText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Playback controls
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.shuffle,
                                            color: playback.shuffleEnabled
                                                ? AppTheme.accent
                                                : Colors.white,
                                          ),
                                          onPressed: () {
                                            // Обновляем состояние провайдера вместо локального состояния
                                            context
                                                .read<PlaybackCubit>()
                                                .toggleShuffle();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  !playback.shuffleEnabled
                                                      ? 'Перемешивание включено'
                                                      : 'Перемешивание выключено',
                                                ),
                                                duration: const Duration(
                                                  seconds: 1,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.skip_previous,
                                            color: Colors.white,
                                            size: 36,
                                          ),
                                          onPressed: () {
                                            // Используем метод провайдера вместо сообщения
                                            context
                                                .read<PlaybackCubit>()
                                                .playPrevious();
                                          },
                                        ),
                                        _buildPlayButton(
                                          context,
                                          isLoading,
                                          isPlaying,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.skip_next,
                                            color: Colors.white,
                                            size: 36,
                                          ),
                                          onPressed: () {
                                            // Используем метод провайдера вместо сообщения
                                            context
                                                .read<PlaybackCubit>()
                                                .playNext();
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.repeat,
                                            color: playback.repeatEnabled
                                                ? AppTheme.accent
                                                : Colors.white,
                                          ),
                                          onPressed: () {
                                            // Обновляем состояние провайдера вместо локального состояния
                                            context
                                                .read<PlaybackCubit>()
                                                .toggleRepeat();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  !playback.repeatEnabled
                                                      ? 'Повтор включен'
                                                      : 'Повтор выключен',
                                                ),
                                                duration: const Duration(
                                                  seconds: 1,
                                                ),
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

  Widget _buildPlayButton(
    BuildContext context,
    bool isLoading,
    bool isPlaying,
  ) {
    if (isLoading) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accent.withValues(alpha: 0.7),
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
        color: AppTheme.accent,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.3),
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
        onPressed: () => context.read<PlaybackCubit>().togglePlayPause(),
      ),
    );
  }
}
