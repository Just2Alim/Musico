import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/player/playback_cubit.dart';
import '../providers/music_data_provider.dart';

class DetailedPlaylistScreen extends StatefulWidget {
  const DetailedPlaylistScreen({super.key, required this.arguments});
  final Map<String, dynamic> arguments;

  @override
  State<DetailedPlaylistScreen> createState() => _DetailedPlaylistScreenState();
}

class _DetailedPlaylistScreenState extends State<DetailedPlaylistScreen> {
  bool _loading = true;
  Map<String, dynamic>? _playlist;
  List<dynamic> _tracks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<MusicDataProvider>().getPlaylistDetails(
        widget.arguments['playlistId'] as int,
      );
      if (!mounted) return;
      setState(() {
        _playlist = data;
        _tracks = data?['tracks'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_playlist?['name'] as String? ?? 'Плейлист')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _playlist == null
        ? const Center(child: Text('Плейлист не найден'))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '${_playlist!['subtitle'] ?? 'Ваша музыкальная подборка'}\n${_tracks.length} треков',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: _tracks.isEmpty
                    ? const Center(child: Text('Добавьте треки в плейлист'))
                    : ListView.builder(
                        itemCount: _tracks.length,
                        itemBuilder: (context, index) {
                          final track = Map<String, dynamic>.from(
                            _tracks[index] as Map,
                          );
                          return ListTile(
                            leading: const Icon(Icons.music_note),
                            title: Text(track['name'] as String? ?? 'Трек'),
                            subtitle: Text(
                              track['artist'] as String? ?? 'Исполнитель',
                            ),
                            trailing: Text(
                              _duration(track['duration'] as int? ?? 0),
                            ),
                            onTap: () async {
                              final id = track['id'] as int;
                              await context.read<PlaybackCubit>().playPlaylist(
                                widget.arguments['playlistId'] as int,
                                startTrackId: id,
                              );
                              if (context.mounted) {
                                context.push('/player/$id');
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
  );

  String _duration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
