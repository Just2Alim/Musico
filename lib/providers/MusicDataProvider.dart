// lib/providers/MusicDataProvider.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../graphql/graphql_config.dart';

class Playlist {
  final int id;
  final String name;
  final String? subtitle;
  final String? imageUrl;
  final int trackCount;
  final int userId;

  Playlist({
    required this.id,
    required this.name,
    this.subtitle,
    this.imageUrl,
    required this.trackCount,
    required this.userId,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'] ?? 'Untitled Playlist',
      subtitle: json['subtitle'],
      imageUrl: json['imageUrl'],
      trackCount: json['trackCount'] ?? 0,
      userId: json['userId'],
    );
  }
}

class MusicDataProvider with ChangeNotifier {
  List<Playlist> _featuredPlaylists = [];
  List<Playlist> _userPlaylists = [];
  List<dynamic> _recentlyPlayed = [];
  List<dynamic> _favoriteTracks = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<Playlist> get featuredPlaylists => _featuredPlaylists;
  List<Playlist> get userPlaylists => _userPlaylists;
  List<dynamic> get recentlyPlayed => _recentlyPlayed;
  List<dynamic> get favoriteTracks => _favoriteTracks;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Load featured playlists
  Future<void> loadFeaturedPlaylists() async {
    if (_featuredPlaylists.isNotEmpty) return;
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      const String query = '''
        query {
          featuredPlaylists {
            id
            name
            subtitle
            imageUrl
            trackCount
            userId
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(options);

      if (result.hasException) {
        _errorMessage = 'Error loading featured playlists: ${result.exception.toString()}';
        print(_errorMessage);
      } else {
        final List<dynamic> data = result.data?['featuredPlaylists'] ?? [];
        _featuredPlaylists = data.map((item) => Playlist.fromJson(item)).toList();
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load user playlists
  Future<void> loadUserPlaylists() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      const String query = '''
        query UserPlaylists(\$userId: Int!) {
          playlists(userId: \$userId) {
            id
            name
            subtitle
            imageUrl
            trackCount
            userId
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(query),
        variables: {'userId': 1}, // Replace with actual user ID
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(options);

      if (result.hasException) {
        _errorMessage = 'Error loading user playlists: ${result.exception.toString()}';
        print(_errorMessage);
      } else {
        final List<dynamic> data = result.data?['playlists'] ?? [];
        _userPlaylists = data.map((item) => Playlist.fromJson(item)).toList();
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load recently played
  Future<void> loadRecentlyPlayed() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      const String query = '''
        query {
          recentlyPlayed(limit: 10) {
            id
            listenedAt
            track {
              id
              name
              artist
              duration
              coverImageUrl
              audioFileUrl
              isLiked
            }
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(options);

      if (result.hasException) {
        _errorMessage = 'Error loading recently played: ${result.exception.toString()}';
        print(_errorMessage);
      } else {
        _recentlyPlayed = result.data?['recentlyPlayed'] ?? [];
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load favorite tracks
  Future<void> loadFavoriteTracks() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      const String query = '''
        query {
          favoriteTracks {
            id
            addedAt
            track {
              id
              name
              artist
              duration
              coverImageUrl
              audioFileUrl
              isLiked
            }
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(options);

      if (result.hasException) {
        _errorMessage = 'Error loading favorite tracks: ${result.exception.toString()}';
        print(_errorMessage);
      } else {
        _favoriteTracks = result.data?['favoriteTracks'] ?? [];
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Create new playlist
  Future<bool> createPlaylist(String name, {String? subtitle, String? imageUrl}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      const String mutation = '''
        mutation CreatePlaylist(\$name: String!, \$subtitle: String, \$imageUrl: String) {
          createPlaylist(name: \$name, subtitle: \$subtitle, imageUrl: \$imageUrl) {
            id
            name
            subtitle
            imageUrl
            trackCount
            userId
          }
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'name': name,
          'subtitle': subtitle,
          'imageUrl': imageUrl,
        },
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.mutate(options);

      if (result.hasException) {
        _errorMessage = 'Error creating playlist: ${result.exception.toString()}';
        print(_errorMessage);
        return false;
      } else {
        final newPlaylist = Playlist.fromJson(result.data?['createPlaylist']);
        _userPlaylists.add(newPlaylist);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add track to playlist
  Future<bool> addTrackToPlaylist(int playlistId, int trackId) async {
    try {
      const String mutation = '''
        mutation AddTrackToPlaylist(\$playlistId: Int!, \$trackId: Int!) {
          addTrackToPlaylist(playlistId: \$playlistId, trackId: \$trackId)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'playlistId': playlistId,
          'trackId': trackId,
        },
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.mutate(options);

      if (result.hasException) {
        _errorMessage = 'Error adding track to playlist: ${result.exception.toString()}';
        print(_errorMessage);
        return false;
      } else {
        // Update local playlist data
        final index = _userPlaylists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          _userPlaylists[index] = Playlist(
            id: _userPlaylists[index].id,
            name: _userPlaylists[index].name,
            subtitle: _userPlaylists[index].subtitle,
            imageUrl: _userPlaylists[index].imageUrl,
            trackCount: _userPlaylists[index].trackCount + 1,
            userId: _userPlaylists[index].userId,
          );
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
      return false;
    }
  }

  // Remove track from playlist
  Future<bool> removeTrackFromPlaylist(int playlistId, int trackId) async {
    try {
      const String mutation = '''
        mutation RemoveTrackFromPlaylist(\$playlistId: Int!, \$trackId: Int!) {
          removeTrackFromPlaylist(playlistId: \$playlistId, trackId: \$trackId)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'playlistId': playlistId,
          'trackId': trackId,
        },
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.mutate(options);

      if (result.hasException) {
        _errorMessage = 'Error removing track from playlist: ${result.exception.toString()}';
        print(_errorMessage);
        return false;
      } else {
        // Update local playlist data
        final index = _userPlaylists.indexWhere((p) => p.id == playlistId);
        if (index != -1 && _userPlaylists[index].trackCount > 0) {
          _userPlaylists[index] = Playlist(
            id: _userPlaylists[index].id,
            name: _userPlaylists[index].name,
            subtitle: _userPlaylists[index].subtitle,
            imageUrl: _userPlaylists[index].imageUrl,
            trackCount: _userPlaylists[index].trackCount - 1,
            userId: _userPlaylists[index].userId,
          );
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
      return false;
    }
  }

  // Delete playlist
  Future<bool> deletePlaylist(int playlistId) async {
    try {
      const String mutation = '''
        mutation DeletePlaylist(\$playlistId: Int!) {
          deletePlaylist(playlistId: \$playlistId)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'playlistId': playlistId,
        },
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.mutate(options);

      if (result.hasException) {
        _errorMessage = 'Error deleting playlist: ${result.exception.toString()}';
        print(_errorMessage);
        return false;
      } else {
        // Remove playlist from local list
        _userPlaylists.removeWhere((p) => p.id == playlistId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
      return false;
    }
  }

  // Search for music
  Future<Map<String, dynamic>> searchMusic(String query) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      const String searchQuery = '''
        query Search(\$query: String!) {
          search(query: \$query) {
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
            playlists {
              id
              name
              subtitle
              imageUrl
              trackCount
              userId
            }
            artists
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(searchQuery),
        variables: {
          'query': query,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(options);

      if (result.hasException) {
        _errorMessage = 'Error searching: ${result.exception.toString()}';
        print(_errorMessage);
        return {};
      } else {
        return result.data?['search'] ?? {};
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get playlist details
  Future<Map<String, dynamic>?> getPlaylistDetails(int playlistId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      const String query = '''
        query GetPlaylistDetails(\$playlistId: Int!) {
          playlist(playlistId: \$playlistId) {
            id
            name
            subtitle
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
        document: gql(query),
        variables: {
          'playlistId': playlistId,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(options);

      if (result.hasException) {
        _errorMessage = 'Error loading playlist details: ${result.exception.toString()}';
        print(_errorMessage);
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _isLoading = false;
      notifyListeners();
      return result.data?['playlist'];
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Create new playlist with track
  Future<Map<String, dynamic>?> createPlaylistWithTrack(String name, int trackId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Сначала создаем плейлист
      const String createMutation = '''
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

      final MutationOptions createOptions = MutationOptions(
        document: gql(createMutation),
        variables: {
          'name': name,
        },
      );

      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult createResult = await client.mutate(createOptions);

      if (createResult.hasException) {
        _errorMessage = 'Error creating playlist: ${createResult.exception.toString()}';
        print(_errorMessage);
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final newPlaylist = createResult.data?['createPlaylist'];
      final int playlistId = newPlaylist['id'];

      // Затем добавляем трек в плейлист
      const String addTrackMutation = '''
        mutation AddTrackToPlaylist(\$playlistId: Int!, \$trackId: Int!) {
          addTrackToPlaylist(playlistId: \$playlistId, trackId: \$trackId)
        }
      ''';

      final MutationOptions addTrackOptions = MutationOptions(
        document: gql(addTrackMutation),
        variables: {
          'playlistId': playlistId,
          'trackId': trackId,
        },
      );

      final QueryResult addTrackResult = await client.mutate(addTrackOptions);

      if (addTrackResult.hasException) {
        _errorMessage = 'Error adding track to playlist: ${addTrackResult.exception.toString()}';
        print(_errorMessage);
        // Всё равно возвращаем плейлист, даже если добавление трека не удалось
      }

      // Обновляем список плейлистов
      loadUserPlaylists();
      
      _isLoading = false;
      notifyListeners();
      return newPlaylist;
    } catch (e) {
      _errorMessage = 'Error: $e';
      print(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Load all data at once
  Future<void> loadAllData() async {
    await Future.wait([
      loadFeaturedPlaylists(),
      loadUserPlaylists(),
      loadRecentlyPlayed(),
      loadFavoriteTracks(),
    ]);
  }
}