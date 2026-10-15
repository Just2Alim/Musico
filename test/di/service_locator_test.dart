import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:musico_app/data/local_music_cache.dart';
import 'package:musico_app/data/music_repository.dart';
import 'package:musico_app/di/service_locator.dart';
import 'package:musico_app/providers/music_data_provider.dart';

void main() {
  test(
    'registers one repository and injects it into feature providers',
    () async {
      final locator = GetIt.asNewInstance();

      configureDependencies(
        locator: locator,
        client: null,
        backendEnabled: false,
      );

      final repository = locator<MusicRepository>();
      final musicProvider = locator<MusicDataProvider>();

      expect(locator<MusicRepository>(), same(repository));
      expect(musicProvider.repository, same(repository));
      expect(musicProvider.cache, same(locator<LocalMusicCache>()));
      expect(musicProvider.backendEnabled, isFalse);
      expect(() => repository.client, throwsStateError);

      await locator.reset();
    },
  );
}
