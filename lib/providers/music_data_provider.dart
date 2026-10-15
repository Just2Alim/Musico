import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import '../data/local_music_cache.dart';
import '../data/music_repository.dart';

part 'music_data_provider.g.dart';

@JsonSerializable()
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.subtitle,
    this.imageUrl,
    required this.trackCount,
    required this.userId,
  });

  @JsonKey(fromJson: _playlistInt, defaultValue: 0)
  final int id;
  @JsonKey(defaultValue: 'Untitled Playlist')
  final String name;
  final String? subtitle;
  @JsonKey(name: 'image_url', readValue: _readPlaylistImage)
  final String? imageUrl;
  @JsonKey(
    name: 'track_count',
    readValue: _readPlaylistTrackCount,
    fromJson: _playlistInt,
    defaultValue: 0,
  )
  final int trackCount;
  @JsonKey(name: 'user_id', readValue: _readPlaylistUserId, defaultValue: '')
  final String userId;

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  Map<String, dynamic> toJson() => _$PlaylistToJson(this);
}

Object? _readPlaylistImage(Map<dynamic, dynamic> json, String key) =>
    json['image_url'] ?? json['imageUrl'];

Object? _readPlaylistTrackCount(Map<dynamic, dynamic> json, String key) =>
    json['track_count'] ?? json['trackCount'];

Object? _readPlaylistUserId(Map<dynamic, dynamic> json, String key) =>
    json['user_id'] ?? json['userId'];

int _playlistInt(Object? value) => value is num ? value.toInt() : 0;

class MusicDataProvider extends ChangeNotifier {
  MusicDataProvider(
    this.repository,
    this.cache, {
    required this.backendEnabled,
  }) {
    _observedUserId = _userId;
    if (backendEnabled) {
      _authSubscription = repository.client.auth.onAuthStateChange.listen(
        (_) => _handleAuthChange(),
        onError: (Object _) {
          _handleAuthChange();
        },
      );
    }
  }

  final MusicRepository repository;
  final LocalMusicCache cache;
  final bool backendEnabled;
  StreamSubscription<AuthState>? _authSubscription;
  String? _observedUserId;
  int _identityVersion = 0;
  bool _disposed = false;

  void _handleAuthChange() {
    final userId = _userId;
    if (_disposed || userId == _observedUserId) return;
    _observedUserId = userId;
    _identityVersion++;
    _userPlaylists = [];
    _featuredPlaylists = [];
    _recentlyPlayed = [];
    _favoriteTracks = [];
    _errorMessage = '';
    notifyListeners();
    unawaited(loadFeaturedPlaylists());
    if (userId != null) {
      unawaited(loadUserPlaylists());
      unawaited(loadFavoriteTracks());
      unawaited(loadRecentlyPlayed());
    }
  }

  bool _isCurrentIdentity(int version, String? userId) =>
      !_disposed && version == _identityVersion && userId == _userId;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _identityVersion++;
    _authSubscription?.cancel();
    super.dispose();
  }

  List<Playlist> _featuredPlaylists = [];
  List<Playlist> _userPlaylists = [];
  List<Map<String, dynamic>> _recentlyPlayed = [];
  List<Map<String, dynamic>> _favoriteTracks = [];
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreTracks = true;
  String _errorMessage = '';

  List<Playlist> get featuredPlaylists => List.unmodifiable(_featuredPlaylists);
  List<Playlist> get userPlaylists => List.unmodifiable(_userPlaylists);
  List<Map<String, dynamic>> get recentlyPlayed =>
      List.unmodifiable(_recentlyPlayed);
  List<Map<String, dynamic>> get favoriteTracks =>
      List.unmodifiable(_favoriteTracks);
  List<Map<String, dynamic>> get tracks => List.unmodifiable(_tracks);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreTracks => _hasMoreTracks;
  String get errorMessage => _errorMessage;
  bool get isSignedIn => _userId != null;
  String? get currentUserId => _userId;

  String? get _userId {
    try {
      return repository.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadFeaturedPlaylists() async {
    final version = _identityVersion;
    final userId = _userId;
    try {
      final rows = await repository.playlists();
      if (!_isCurrentIdentity(version, userId)) return;
      _featuredPlaylists = rows.map(Playlist.fromJson).toList();
    } catch (_) {
      if (!_isCurrentIdentity(version, userId)) return;
      // A private-playlist RLS denial must not discard the public track catalog.
      _featuredPlaylists = [];
    }
    notifyListeners();
  }

  Future<void> loadUserPlaylists() async {
    final version = _identityVersion;
    final userId = _userId;
    if (userId == null) {
      _userPlaylists = [];
      notifyListeners();
      return;
    }
    try {
      final rows = await repository.playlists(ownerId: userId);
      if (!_isCurrentIdentity(version, userId)) return;
      _userPlaylists = rows.map(Playlist.fromJson).toList();
      _errorMessage = '';
    } catch (error) {
      if (!_isCurrentIdentity(version, userId)) return;
      _errorMessage = 'Не удалось загрузить ваши плейлисты: $error';
    }
    notifyListeners();
  }

  Future<void> loadRecentlyPlayed() async {
    final version = _identityVersion;
    final userId = _userId;
    try {
      final rows = await repository.recentlyPlayed();
      if (!_isCurrentIdentity(version, userId)) return;
      _recentlyPlayed = rows;
      if (userId != null) await cache.saveHistory(userId, rows);
    } catch (error) {
      if (!_isCurrentIdentity(version, userId)) return;
      _recentlyPlayed = userId == null ? [] : cache.readHistory(userId);
      _errorMessage = 'Не удалось загрузить историю: $error';
    }
    notifyListeners();
  }

  Future<void> loadFavoriteTracks() async {
    final version = _identityVersion;
    final userId = _userId;
    try {
      final rows = await repository.favoriteTracks();
      if (!_isCurrentIdentity(version, userId)) return;
      _favoriteTracks = rows;
      if (userId != null) await cache.saveFavorites(userId, rows);
    } catch (error) {
      if (!_isCurrentIdentity(version, userId)) return;
      _favoriteTracks = userId == null ? [] : cache.readFavorites(userId);
      _errorMessage = 'Не удалось загрузить избранное: $error';
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(int trackId) async {
    _errorMessage = '';
    try {
      final favorite = await repository.isFavorite(trackId);
      await repository.setFavorite(trackId, !favorite);
      await loadFavoriteTracks();
    } catch (error) {
      _errorMessage = 'Не удалось обновить избранное: $error';
      notifyListeners();
    }
  }

  Future<bool> createPlaylist(
    String name, {
    String? subtitle,
    String? imageUrl,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      await repository.createPlaylist(
        name,
        subtitle: subtitle,
        imageUrl: imageUrl,
      );
      await loadUserPlaylists();
      return true;
    } catch (error) {
      _errorMessage = 'Не удалось создать плейлист: $error';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addTrackToPlaylist(int playlistId, int trackId) async {
    try {
      await repository.addTrack(playlistId, trackId);
      await loadUserPlaylists();
      return true;
    } catch (error) {
      _errorMessage = 'Не удалось добавить трек: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeTrackFromPlaylist(int playlistId, int trackId) async {
    try {
      await repository.removeTrack(playlistId, trackId);
      await loadUserPlaylists();
      return true;
    } catch (error) {
      _errorMessage = 'Не удалось удалить трек: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePlaylist(int playlistId) async {
    try {
      await repository.deletePlaylist(playlistId);
      await loadUserPlaylists();
      return true;
    } catch (error) {
      _errorMessage = 'Не удалось удалить плейлист: $error';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> searchMusic(String query) async {
    final version = _identityVersion;
    final userId = _userId;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return _searchResult([], []);
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      if (!backendEnabled) return _searchCachedTracks(needle);
      final foundTracks = await repository.tracks(query: query.trim());
      if (!_isCurrentIdentity(version, userId)) {
        return _searchResult(foundTracks, []);
      }
      List<Map<String, dynamic>> foundPlaylists;
      try {
        foundPlaylists = await repository.playlists();
      } catch (_) {
        // Private playlists may be unavailable while public tracks still work.
        foundPlaylists = [];
      }
      if (!_isCurrentIdentity(version, userId)) {
        return _searchResult(foundTracks, []);
      }
      return _searchResult(
        foundTracks,
        foundPlaylists
            .where(
              (playlist) => (playlist['name'] as String? ?? '')
                  .toLowerCase()
                  .contains(needle),
            )
            .toList(),
      );
    } catch (_) {
      return _searchCachedTracks(needle);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _searchCachedTracks(String needle) {
    _errorMessage = 'Офлайн: поиск по сохранённым трекам';
    final saved = cache.readTracks();
    return _searchResult(
      saved
          .where(
            (track) => ['name', 'artist', 'genre'].any(
              (key) =>
                  (track[key] as String? ?? '').toLowerCase().contains(needle),
            ),
          )
          .toList(),
      [],
    );
  }

  Map<String, dynamic> _searchResult(
    List<Map<String, dynamic>> tracks,
    List<Map<String, dynamic>> playlists,
  ) => {
    'tracks': tracks,
    'playlists': playlists,
    'artists': tracks
        .map((track) => track['artist'])
        .whereType<String>()
        .where((artist) => artist.trim().isNotEmpty)
        .toSet()
        .toList(),
  };

  Future<Map<String, dynamic>?> getPlaylistDetails(int playlistId) async {
    try {
      final details = await repository.playlist(playlistId);
      if (details == null) return null;
      final user = await repository.client
          .from('profiles')
          .select('display_name')
          .eq('id', details['user_id'])
          .maybeSingle();
      return {
        ...details,
        'tracks': await repository.playlistTracks(playlistId),
        'user': {'name': user?['display_name'] ?? ''},
      };
    } catch (error) {
      _errorMessage = 'Не удалось открыть плейлист: $error';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> createPlaylistWithTrack(
    String name,
    int trackId,
  ) async {
    try {
      final id = await repository.createPlaylist(name);
      await repository.addTrack(id, trackId);
      await loadUserPlaylists();
      return {
        'id': id,
        'name': name,
        'user_id': repository.client.auth.currentUser?.id,
      };
    } catch (error) {
      _errorMessage = 'Не удалось создать плейлист: $error';
      notifyListeners();
      return null;
    }
  }

  Future<void> loadAllData() async {
    _isLoading = true;
    _hasMoreTracks = true;
    if (!backendEnabled) {
      _tracks = cache.readTracks();
      _errorMessage = _tracks.isEmpty
          ? 'Настройте Supabase, чтобы загрузить музыкальный каталог.'
          : 'Офлайн-режим: показан сохранённый каталог.';
      _isLoading = false;
      notifyListeners();
      return;
    }
    notifyListeners();
    try {
      _tracks = await repository.tracks();
      _hasMoreTracks = _tracks.length == 30;
      await cache.saveTracks(_tracks);
      await loadFeaturedPlaylists();
      await Future.wait([
        loadUserPlaylists(),
        loadRecentlyPlayed(),
        loadFavoriteTracks(),
      ]);
      _errorMessage = '';
    } catch (error) {
      _tracks = cache.readTracks();
      _errorMessage = _tracks.isEmpty
          ? 'Нет сети и сохранённого каталога: $error'
          : '';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreTracks() async {
    if (!backendEnabled || _isLoading || _isLoadingMore || !_hasMoreTracks) {
      return;
    }
    _isLoadingMore = true;
    notifyListeners();
    try {
      final nextPage = await repository.tracks(from: _tracks.length);
      _tracks = [..._tracks, ...nextPage];
      _hasMoreTracks = nextPage.length == 30;
      await cache.saveTracks(_tracks);
    } catch (error) {
      _errorMessage = 'Не удалось загрузить следующую страницу: $error';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
