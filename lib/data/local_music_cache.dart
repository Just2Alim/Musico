import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class LocalMusicCache {
  static const _boxName = 'music_cache';

  Future<void> initialize() async => Hive.openBox<String>(_boxName);

  Box<String> get _box => Hive.box<String>(_boxName);

  List<Map<String, dynamic>> readTracks() {
    final value = _box.get('tracks');
    if (value == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(value) as List);
  }

  List<Map<String, dynamic>> readFavorites(String userId) =>
      _readRows('favorites:$userId');

  List<Map<String, dynamic>> readHistory(String userId) =>
      _readRows('history:$userId');

  List<Map<String, dynamic>> _readRows(String key) {
    final value = _box.get(key);
    if (value == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(value) as List);
  }

  Future<void> saveTracks(List<Map<String, dynamic>> tracks) =>
      _box.put('tracks', jsonEncode(tracks));

  Future<void> saveFavorites(String userId, List<Map<String, dynamic>> rows) =>
      _box.put('favorites:$userId', jsonEncode(rows));

  Future<void> saveHistory(String userId, List<Map<String, dynamic>> rows) =>
      _box.put('history:$userId', jsonEncode(rows));
}
