import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local_music_cache.dart';
import '../data/music_repository.dart';
import '../domain/use_cases/load_venues.dart';
import '../providers/music_data_provider.dart';

final GetIt appLocator = GetIt.instance;

void configureDependencies({
  SupabaseClient? client,
  String? supabaseUrl,
  String? publishableKey,
  required bool backendEnabled,
  GetIt? locator,
}) {
  final container = locator ?? appLocator;
  container.registerLazySingleton<http.Client>(http.Client.new);
  container.registerSingleton<MusicRepository>(
    MusicRepository(
      client,
      supabaseUrl: supabaseUrl,
      publishableKey: publishableKey,
      httpClient: container<http.Client>(),
    ),
  );
  container.registerLazySingleton<LocalMusicCache>(LocalMusicCache.new);
  container.registerFactory<LoadVenues>(
    () => LoadVenues(container<MusicRepository>()),
  );
  container.registerFactory<MusicDataProvider>(
    () => MusicDataProvider(
      container<MusicRepository>(),
      container<LocalMusicCache>(),
      backendEnabled: backendEnabled,
    ),
  );
}
