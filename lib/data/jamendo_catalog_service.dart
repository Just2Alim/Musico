import 'dart:convert';

import 'package:http/http.dart' as http;

/// Read-only adapter for Jamendo's licensed, artist-published music catalog.
class JamendoCatalogService {
  JamendoCatalogService({
    required this.clientId,
    required http.Client httpClient,
  }) : _httpClient = httpClient;

  static final Uri _endpoint = Uri.https('api.jamendo.com', '/v3.0/tracks/');

  final String clientId;
  final http.Client _httpClient;

  bool get isConfigured => clientId.trim().isNotEmpty;

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final needle = query.trim();
    if (needle.isEmpty || !isConfigured) return const [];
    return _fetch({'search': needle}, limit: limit, offset: offset);
  }

  Future<List<Map<String, dynamic>>> featured({
    int limit = 20,
    int offset = 0,
  }) async {
    if (!isConfigured) return const [];
    return _fetch(
      const {
        'featured': '1',
        'order': 'popularity_total',
        'groupby': 'artist_id',
      },
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> _fetch(
    Map<String, String> filters, {
    required int limit,
    required int offset,
  }) async {
    if (limit < 1 || limit > 50 || offset < 0) {
      throw ArgumentError(
        'Jamendo pagination requires limit 1..50 and offset >= 0.',
      );
    }

    final uri = _endpoint.replace(
      queryParameters: {
        'client_id': clientId.trim(),
        'format': 'json',
        'limit': '$limit',
        'offset': '$offset',
        'include': 'licenses',
        'audioformat': 'mp32',
        'type': 'all',
        ...filters,
      },
    );
    final response = await _httpClient
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Licensed catalog request failed (${response.statusCode}).',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['headers'] is! Map<String, dynamic> ||
        (decoded['headers'] as Map<String, dynamic>)['status'] != 'success') {
      throw const FormatException(
        'Licensed catalog returned an invalid response.',
      );
    }
    final results = decoded['results'];
    if (results is! List) {
      throw const FormatException('Licensed catalog results are missing.');
    }

    return results
        .whereType<Map<String, dynamic>>()
        .map(_mapTrack)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Map<String, dynamic>? _mapTrack(Map<String, dynamic> item) {
    final sourceId = int.tryParse(item['id']?.toString() ?? '');
    final name = _text(item['name']);
    final artist = _text(item['artist_name']);
    final audioUrl = _httpsUrl(item['audio']);
    final licenseUrl = _httpsUrl(
      item['license_ccurl'] ??
          (item['licenses'] is Map<String, dynamic>
              ? (item['licenses'] as Map<String, dynamic>)['url']
              : null),
    );
    if (sourceId == null || sourceId == 0 || name == null || artist == null) {
      return null;
    }
    if (audioUrl == null || licenseUrl == null) return null;

    return {
      'id': -sourceId.abs(),
      'name': name,
      'artist': artist,
      'genre': item['musicinfo'] is Map<String, dynamic>
          ? (item['musicinfo'] as Map<String, dynamic>)['tags']?.toString()
          : 'Jamendo',
      'cover_image_url': _httpsUrl(item['image']),
      'audio_file_url': audioUrl,
      'duration': _intValue(item['duration']),
      'isLiked': false,
      'source': 'jamendo',
      'license_url': licenseUrl,
      'source_url':
          _httpsUrl(item['shareurl']) ??
          'https://www.jamendo.com/track/$sourceId',
    };
  }

  static String? _text(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String? _httpsUrl(Object? value) {
    final text = _text(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri.toString()
        : null;
  }

  static int _intValue(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
}
