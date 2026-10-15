import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/venue.dart';
import '../domain/repositories/venue_repository.dart';

class MusicRepository implements VenueRepository {
  static const _requestTimeout = Duration(seconds: 15);

  MusicRepository(
    this._client, {
    this.supabaseUrl,
    this.publishableKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final SupabaseClient? _client;
  final String? supabaseUrl;
  final String? publishableKey;
  final http.Client _httpClient;

  SupabaseClient get client =>
      _client ??
      (throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      ));

  Map<String, dynamic> _trackRow(Map<String, dynamic> row) => {
    ...row,
    'coverImageUrl': row['cover_image_url'],
    'audioFileUrl': row['audio_file_url'],
  };

  Map<String, dynamic> _playlistRow(Map<String, dynamic> row) {
    final relation = row['playlist_tracks'];
    final aggregate = relation is List && relation.isNotEmpty
        ? relation.first
        : null;
    final count = aggregate is Map ? aggregate['count'] : null;
    return {...row, 'track_count': count is num ? count.toInt() : 0};
  }

  Future<List<Map<String, dynamic>>> tracks({
    String? query,
    int from = 0,
    int limit = 30,
  }) async {
    if (from < 0 || limit < 1 || limit > 100) {
      throw ArgumentError(
        'Track pagination must use from >= 0 and 1..100 items.',
      );
    }
    if (supabaseUrl != null &&
        supabaseUrl!.isNotEmpty &&
        publishableKey != null &&
        publishableKey!.isNotEmpty) {
      return _fetchTracksOverRest(query: query, from: from, limit: limit);
    }
    var request = client.from('tracks').select();
    if (query != null && query.trim().isNotEmpty) {
      final term = query.trim().replaceAll(',', '');
      request = request.or('name.ilike.%$term%,artist.ilike.%$term%');
    }
    final result = await request
        .order('created_at', ascending: false)
        .range(from, from + limit - 1)
        .timeout(_requestTimeout);
    return List<Map<String, dynamic>>.from(result).map(_trackRow).toList();
  }

  /// Fetches one track independently of the paginated catalogue.
  Future<Map<String, dynamic>?> track(int id) async {
    if (id <= 0) return null;
    if (supabaseUrl != null &&
        supabaseUrl!.isNotEmpty &&
        publishableKey != null &&
        publishableKey!.isNotEmpty) {
      final rows = await _fetchTracksOverRest(
        query: null,
        from: 0,
        limit: 1,
        id: id,
      );
      return rows.isEmpty ? null : rows.first;
    }
    final row = await client
        .from('tracks')
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(_requestTimeout);
    return row == null ? null : _trackRow(row);
  }

  Future<List<Map<String, dynamic>>> _fetchTracksOverRest({
    required String? query,
    required int from,
    required int limit,
    int? id,
  }) async {
    final baseUrl = supabaseUrl!.replaceFirst(RegExp(r'/+$'), '');
    final parameters = <String, String>{
      'select': '*',
      'order': 'created_at.desc',
      'offset': '$from',
      'limit': '$limit',
      if (id != null) 'id': 'eq.$id',
    };
    final term = query
        ?.trim()
        .replaceAll(RegExp(r'[,().%*]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (term != null && term.isNotEmpty) {
      parameters['or'] = '(name.ilike.*$term*,artist.ilike.*$term*)';
    }
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tracks',
    ).replace(queryParameters: parameters);
    final token = _client?.auth.currentSession?.accessToken ?? publishableKey!;
    final response = await _httpClient
        .get(
          uri,
          headers: {
            'apikey': publishableKey!,
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Supabase catalog request failed (${response.statusCode}).',
        uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'Supabase catalog response must be a JSON array.',
      );
    }
    return decoded
        .whereType<Map>()
        .map((row) => _trackRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<Venue>> fetchVenues() async {
    final result = await client
        .from('venues')
        .select()
        .order('name', ascending: true)
        .timeout(_requestTimeout);
    return List<Map<String, dynamic>>.from(
      result,
    ).map(Venue.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  RealtimeChannel subscribeToNotifications(void Function() onChange) {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Sign in to subscribe.');
    return client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> markNotificationRead(int notificationId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null)
      throw const AuthException('Sign in to update notifications.');
    await client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> playlists({String? ownerId}) async {
    var request = client.from('playlists').select('*, playlist_tracks(count)');
    if (ownerId != null) request = request.eq('user_id', ownerId);
    final result = await request
        .order('created_at', ascending: false)
        .timeout(_requestTimeout);
    return List<Map<String, dynamic>>.from(result).map(_playlistRow).toList();
  }

  Future<Map<String, dynamic>?> playlist(int id) async {
    final rows = await client
        .from('playlists')
        .select('*, playlist_tracks(count)')
        .eq('id', id)
        .limit(1);
    return rows.isEmpty ? null : _playlistRow(rows.first);
  }

  Future<List<Map<String, dynamic>>> playlistTracks(int playlistId) async {
    final rows = await client
        .from('playlist_tracks')
        .select('position, tracks(*)')
        .eq('playlist_id', playlistId)
        .order('position', ascending: true);
    return rows
        .map(
          (row) => _trackRow(Map<String, dynamic>.from(row['tracks'] as Map)),
        )
        .toList();
  }

  Future<int> createPlaylist(
    String name, {
    String? subtitle,
    String? imageUrl,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to create playlists.');
    final row = await client
        .from('playlists')
        .insert({
          'user_id': user.id,
          'name': name.trim(),
          'subtitle': subtitle,
          'image_url': imageUrl,
        })
        .select('id')
        .single();
    return row['id'] as int;
  }

  Future<void> addTrack(int playlistId, int trackId) async {
    final existing = await client
        .from('playlist_tracks')
        .select('track_id, position')
        .eq('playlist_id', playlistId);
    if (existing.any((row) => row['track_id'] == trackId)) return;
    final lastPosition = existing.fold<int>(-1, (highest, row) {
      final position = (row['position'] as num).toInt();
      return position > highest ? position : highest;
    });
    await client.from('playlist_tracks').upsert({
      'playlist_id': playlistId,
      'track_id': trackId,
      'position': lastPosition + 1,
    });
  }

  Future<void> removeTrack(int playlistId, int trackId) => client
      .from('playlist_tracks')
      .delete()
      .eq('playlist_id', playlistId)
      .eq('track_id', trackId);

  Future<void> deletePlaylist(int playlistId) =>
      client.from('playlists').delete().eq('id', playlistId);

  Future<bool> isFavorite(int trackId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;
    final rows = await client
        .from('favorites')
        .select('track_id')
        .eq('user_id', userId)
        .eq('track_id', trackId)
        .limit(1)
        .timeout(_requestTimeout);
    return rows.isNotEmpty;
  }

  Future<void> setFavorite(int trackId, bool favorite) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'Войдите в аккаунт, чтобы сохранять избранное.',
      );
    }
    if (favorite) {
      await client.from('favorites').upsert({
        'user_id': userId,
        'track_id': trackId,
      });
    } else {
      await client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('track_id', trackId);
    }
  }

  Future<void> recordListening(int trackId, {required bool completed}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('listening_history').insert({
      'user_id': userId,
      'track_id': trackId,
      'completed': completed,
    });
  }

  Future<List<Map<String, dynamic>>> favoriteTracks() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('favorites')
        .select('created_at, tracks(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) =>
              _trackRow(Map<String, dynamic>.from(row['tracks'] as Map))
                ..['isLiked'] = true,
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> recentlyPlayed({int limit = 10}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('listening_history')
        .select('listened_at, tracks(*)')
        .eq('user_id', userId)
        .order('listened_at', ascending: false)
        .limit(limit);
    return rows
        .map(
          (row) => _trackRow(Map<String, dynamic>.from(row['tracks'] as Map)),
        )
        .toList();
  }
}
