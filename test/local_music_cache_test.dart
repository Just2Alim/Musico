import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musico_app/data/local_music_cache.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musico-hive-');
    Hive.init(directory.path);
    await Hive.openBox<String>('music_cache');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('writes and restores cached track rows', () async {
    final cache = LocalMusicCache();
    await cache.saveTracks([
      {'id': 4, 'name': 'Offline track'},
    ]);

    expect(cache.readTracks(), [
      {'id': 4, 'name': 'Offline track'},
    ]);
  });

  test('returns an empty catalog before first save', () {
    expect(LocalMusicCache().readTracks(), isEmpty);
  });

  test('keeps cached favorites and history separated by account', () async {
    final cache = LocalMusicCache();
    await cache.saveFavorites('user-a', [
      {'id': 5, 'name': 'Saved love'},
    ]);
    await cache.saveHistory('user-a', [
      {'id': 8, 'name': 'Played'},
    ]);

    expect(cache.readFavorites('user-a').single['id'], 5);
    expect(cache.readHistory('user-a').single['id'], 8);
    expect(cache.readFavorites('user-b'), isEmpty);
  });
}
