import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/player/playback_cubit.dart';

import '../providers/music_data_provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Future<void>? _refreshing;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() => _refreshing ??= _loadLibrary().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _loadLibrary() async {
    final music = context.read<MusicDataProvider>();
    await Future.wait([
      music.loadUserPlaylists(),
      music.loadFavoriteTracks(),
      music.loadRecentlyPlayed(),
    ]);
  }

  Future<void> _createPlaylist() async {
    final music = context.read<MusicDataProvider>();
    if (!music.isSignedIn) {
      await context.push('/login');
      if (mounted) await _refresh();
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreatePlaylistDialog(),
    );
    if (!mounted || name == null) return;
    final created = await music.createPlaylist(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(created ? 'Плейлист создан' : music.errorMessage)),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Моя музыка'),
      actions: [
        IconButton(
          tooltip: 'Новый плейлист',
          onPressed: context.watch<MusicDataProvider>().isLoading
              ? null
              : _createPlaylist,
          icon: const Icon(Icons.add),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Плейлисты'),
          Tab(text: 'Избранное'),
          Tab(text: 'История'),
        ],
      ),
    ),
    body: Consumer<MusicDataProvider>(
      builder: (context, music, _) => TabBarView(
        controller: _tabs,
        children: [
          _PlaylistsList(
            playlists: music.userPlaylists,
            onCreate: _createPlaylist,
            onRefresh: _refresh,
          ),
          _TracksList(tracks: music.favoriteTracks, onRefresh: _refresh),
          _TracksList(tracks: music.recentlyPlayed, onRefresh: _refresh),
        ],
      ),
    ),
  );
}

class _PlaylistsList extends StatelessWidget {
  const _PlaylistsList({
    required this.playlists,
    required this.onCreate,
    required this.onRefresh,
  });
  final List<Playlist> playlists;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return _RefreshableEmpty(
        onRefresh: onRefresh,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue_music, size: 48),
            const SizedBox(height: 16),
            const Text('Создайте первый плейлист'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Создать плейлист'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return ListTile(
            leading: const Icon(Icons.queue_music),
            title: Text(playlist.name),
            subtitle: Text('${playlist.trackCount} треков'),
            onTap: () async {
              await context.push('/playlist/${playlist.id}');
              if (context.mounted) await onRefresh();
            },
          );
        },
      ),
    );
  }
}

class _TracksList extends StatelessWidget {
  const _TracksList({required this.tracks, required this.onRefresh});
  final List<dynamic> tracks;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty)
      return _RefreshableEmpty(
        onRefresh: onRefresh,
        child: const Text('Пока здесь пусто'),
      );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = Map<String, dynamic>.from(tracks[index] as Map);
          final id = track['id'] as int? ?? 0;
          return ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(track['name'] as String? ?? 'Трек'),
            subtitle: Text(track['artist'] as String? ?? 'Исполнитель'),
            onTap: () async {
              await context.read<PlaybackCubit>().playTracks(
                List<Map<String, dynamic>>.from(tracks),
                id,
              );
              if (context.mounted) {
                await context.push('/player/$id');
                if (context.mounted) await onRefresh();
              }
            },
          );
        },
      ),
    );
  }
}

class _RefreshableEmpty extends StatelessWidget {
  const _RefreshableEmpty({required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
    ),
  );
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate())
      Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Новый плейлист'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _name,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Название'),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Введите название' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Создать')),
    ],
  );
}
