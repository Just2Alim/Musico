import 'package:flutter/material.dart';

class PlaylistScreen extends StatelessWidget {
  final Map<String, dynamic> arguments;

  const PlaylistScreen({Key? key, required this.arguments}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final playlistId = arguments['playlistId'];

    return Scaffold(
      appBar: AppBar(title: Text('Playlist $playlistId')),
      body: Center(
        child: Text('Displaying details for Playlist ID: $playlistId'),
      ),
    );
  }
}
